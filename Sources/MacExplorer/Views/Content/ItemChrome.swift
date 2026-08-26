import AppKit
import SwiftUI

/// The selection/hover fill Explorer paints behind every item, in all layouts.
struct ItemBackground: View {
    let isSelected: Bool
    let isHovering: Bool

    var body: some View {
        let fill: Color
        let border: Color

        switch (isSelected, isHovering) {
        case (true, true):
            fill = Win10.selectedHoverFill
            border = Win10.selectedHoverBorder
        case (true, false):
            fill = Win10.selectionFill
            border = Win10.selectionBorder
        case (false, true):
            fill = Win10.hoverFill
            border = Win10.hoverBorder
        default:
            fill = .clear
            border = .clear
        }

        return Rectangle()
            .fill(fill)
            .overlay(Rectangle().stroke(border, lineWidth: 1))
    }
}

/// Applies the click semantics shared by every layout: single click selects
/// (with Shift/Command), double click opens, right click selects then menus.
struct ItemInteraction: ViewModifier {
    @ObservedObject var model: ExplorerViewModel
    let item: FileItem

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                model.open(item)
            }
            .onTapGesture {
                let flags = NSEvent.modifierFlags
                model.select(
                    item,
                    extending: flags.contains(.shift),
                    toggling: flags.contains(.command)
                )
            }
            .contextMenu {
                ItemContextMenu(model: model, item: item)
            }
            .onDrag {
                // Dragging out to Finder or another app carries the file URL.
                if !model.selection.contains(item.url) {
                    model.select(item, extending: false, toggling: false)
                }
                return NSItemProvider(object: item.url as NSURL)
            }
    }
}

extension View {
    func itemInteraction(model: ExplorerViewModel, item: FileItem) -> some View {
        modifier(ItemInteraction(model: model, item: item))
    }
}

struct ItemContextMenu: View {
    @ObservedObject var model: ExplorerViewModel
    let item: FileItem

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Button("Open") { model.open(item) }
            if item.isNavigable {
                Button("Open in new window") { openWindow(id: "explorer", value: item.url) }
            }
            Menu("Open with") {
                let apps = FileOperations.applications(openingURL: item.url)
                if apps.isEmpty {
                    Text("No applications available")
                } else {
                    ForEach(apps.prefix(12), id: \.self) { app in
                        Button(app.deletingPathExtension().lastPathComponent) {
                            FileOperations.open([item.url], withApplicationAt: app)
                        }
                    }
                }
            }

            Divider()

            if item.isNavigable {
                Button("Pin to Quick access") { model.pinToQuickAccess([item.url]) }
            }
            Button("Compress") { model.compressSelection() }
            Button("Share…") { ShareSheet.present(urls: Array(model.selection)) }

            Divider()

            Button("Cut") { model.cutSelection() }
            Button("Copy") { model.copySelection() }
            if item.isNavigable {
                Button("Paste into folder") { model.paste(into: item.url) }
            }
            Button("Copy path") { model.copyPath() }

            Divider()

            Button("Duplicate") { model.duplicateSelection() }
            Button("Rename") { model.beginRename() }
            Button("Delete") { model.deleteSelection() }

            Divider()

            Button("Reveal in Finder") { FileOperations.revealInFinder(Array(model.selection)) }
            Button("Properties") { model.showProperties() }
        }
    }
}

/// The in-place editor Explorer swaps in when a name is being renamed.
struct RenameField: View {
    let initialText: String
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(Win10.body)
            .padding(.horizontal, 2)
            .background(Color.white)
            .overlay(Rectangle().stroke(Win10.fieldBorderFocused, lineWidth: 1))
            .focused($focused)
            .onSubmit { onCommit(text) }
            .onExitCommand { onCancel() }
            .onAppear {
                text = initialText
                focused = true
            }
    }
}

/// The optional square check box from the View tab's Show/hide group.
struct ItemCheckBox: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 13, height: 13)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(isOn ? Win10.accent : Win10.fieldBorder, lineWidth: 1)
                    )
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Win10.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
