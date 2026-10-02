import SwiftUI

/// Explorer's List layout flows names down a column, then wraps into the next
/// column and scrolls sideways.
struct ListLayoutView: View {
    @ObservedObject var model: ExplorerViewModel

    private let rowHeight: CGFloat = 18
    private let columnWidth: CGFloat = 210

    var body: some View {
        GeometryReader { geometry in
            let rowCount = max(1, Int((geometry.size.height - 8) / rowHeight))
            let rows = Array(
                repeating: GridItem(.fixed(rowHeight), spacing: 0, alignment: .leading),
                count: rowCount
            )

            ScrollView(.horizontal) {
                LazyHGrid(rows: rows, alignment: .top, spacing: 0) {
                    ForEach(model.flatItems) { item in
                        ListLayoutRow(model: model, item: item)
                            .frame(width: columnWidth, height: rowHeight)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
            }
        }
    }
}

private struct ListLayoutRow: View {
    @ObservedObject var model: ExplorerViewModel
    let item: FileItem

    @State private var hovering = false

    private var isSelected: Bool { model.selection.contains(item.url) }

    var body: some View {
        HStack(spacing: 5) {
            if model.showItemCheckBoxes {
                ItemCheckBox(isOn: isSelected) {
                    model.select(item, extending: false, toggling: true)
                }
            }

            FileIcon(url: item.url, size: 16)

            if model.renamingURL == item.url {
                RenameField(
                    initialText: item.displayName(showExtensions: model.showFileExtensions),
                    onCommit: { model.commitRename(item.url, to: $0) },
                    onCancel: { model.cancelRename() }
                )
            } else {
                Text(item.displayName(showExtensions: model.showFileExtensions))
                    .font(Win10.body)
                    .foregroundColor(Win10.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 3)
        .background(ItemBackground(isSelected: isSelected, isHovering: hovering))
        .opacity(ExplorerClipboard.shared.isCut(item.url) ? 0.5 : 1)
        .onHover { hovering = $0 }
        .itemInteraction(model: model, item: item)
    }
}
