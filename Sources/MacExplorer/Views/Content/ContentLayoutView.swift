import SwiftUI

/// The Content layout: one wide band per item with the name, type and the
/// date/size stacked at the trailing edge.
struct ContentLayoutView: View {
    @ObservedObject var model: ExplorerViewModel

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(model.groups) { group in
                    if model.isGrouped {
                        GroupHeader(
                            group: group,
                            isCollapsed: model.collapsedGroups.contains(group.id)
                        ) {
                            model.toggleGroup(group.id)
                        }
                    }
                    if !model.collapsedGroups.contains(group.id) {
                        ForEach(group.items) { item in
                            ContentLayoutRow(model: model, item: item)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }
}

private struct ContentLayoutRow: View {
    @ObservedObject var model: ExplorerViewModel
    let item: FileItem

    @State private var hovering = false

    private var isSelected: Bool { model.selection.contains(item.url) }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if model.showItemCheckBoxes {
                ItemCheckBox(isOn: isSelected) {
                    model.select(item, extending: false, toggling: true)
                }
            }

            FileIcon(url: item.url, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                if model.renamingURL == item.url {
                    RenameField(
                        initialText: item.displayName(showExtensions: model.showFileExtensions),
                        onCommit: { model.commitRename(item.url, to: $0) },
                        onCancel: { model.cancelRename() }
                    )
                    .frame(maxWidth: 320)
                } else {
                    Text(item.displayName(showExtensions: model.showFileExtensions))
                        .font(Win10.body)
                        .foregroundColor(Win10.text)
                        .lineLimit(1)
                }
                Text(item.typeDescription)
                    .font(Win10.small)
                    .foregroundColor(Win10.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Format.listDate(item.dateModified))
                    .font(Win10.small)
                    .foregroundColor(Win10.secondaryText)
                if !item.sizeText.isEmpty {
                    Text(item.sizeText)
                        .font(Win10.small)
                        .foregroundColor(Win10.secondaryText)
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 52)
        .background(ItemBackground(isSelected: isSelected, isHovering: hovering))
        .opacity(ExplorerClipboard.shared.isCut(item.url) ? 0.5 : 1)
        .onHover { hovering = $0 }
        .itemInteraction(model: model, item: item)
        .win10Divider(Win10.separator)
    }
}
