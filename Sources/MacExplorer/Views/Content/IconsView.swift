import SwiftUI

/// Covers the five grid layouts: extra large / large / medium / small icons
/// and tiles. They differ only in cell metrics and how much text each shows.
struct IconsView: View {
    @ObservedObject var model: ExplorerViewModel
    let mode: LayoutMode

    private var cellWidth: CGFloat {
        switch mode {
        case .extraLargeIcons: return 130
        case .largeIcons: return 100
        case .mediumIcons: return 84
        case .smallIcons: return 190
        case .tiles: return 240
        default: return 100
        }
    }

    private var cellHeight: CGFloat {
        switch mode {
        case .extraLargeIcons: return 132
        case .largeIcons: return 100
        case .mediumIcons: return 84
        case .smallIcons: return 22
        case .tiles: return 62
        default: return 100
        }
    }

    private var isHorizontalCell: Bool {
        mode == .smallIcons || mode == .tiles
    }

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
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: cellWidth), spacing: 0, alignment: .topLeading)],
                            alignment: .leading,
                            spacing: 0
                        ) {
                            ForEach(group.items) { item in
                                cell(for: item)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func cell(for item: FileItem) -> some View {
        if isHorizontalCell {
            HorizontalIconCell(model: model, item: item, mode: mode)
                .frame(width: cellWidth, height: cellHeight)
        } else {
            VerticalIconCell(model: model, item: item, mode: mode)
                .frame(width: cellWidth, height: cellHeight)
        }
    }
}

/// Icon above a centred, wrapping caption.
private struct VerticalIconCell: View {
    @ObservedObject var model: ExplorerViewModel
    let item: FileItem
    let mode: LayoutMode

    @State private var hovering = false

    private var isSelected: Bool { model.selection.contains(item.url) }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                FileIcon(url: item.url, size: mode.iconSize)
                if model.showItemCheckBoxes {
                    ItemCheckBox(isOn: isSelected) {
                        model.select(item, extending: false, toggling: true)
                    }
                    .offset(x: -6, y: -2)
                }
            }
            .frame(height: mode.iconSize)

            if model.renamingURL == item.url {
                RenameField(
                    initialText: item.displayName(showExtensions: model.showFileExtensions),
                    onCommit: { model.commitRename(item.url, to: $0) },
                    onCancel: { model.cancelRename() }
                )
                .frame(width: mode.iconSize + 30)
            } else {
                Text(item.displayName(showExtensions: model.showFileExtensions))
                    .font(Win10.body)
                    .foregroundColor(Win10.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(isSelected ? 3 : 2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 6)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(ItemBackground(isSelected: isSelected, isHovering: hovering))
        .opacity(ExplorerClipboard.shared.isCut(item.url) ? 0.5 : 1)
        .onHover { hovering = $0 }
        .itemInteraction(model: model, item: item)
    }
}

/// Icon beside the caption — small icons, and tiles with their extra lines.
private struct HorizontalIconCell: View {
    @ObservedObject var model: ExplorerViewModel
    let item: FileItem
    let mode: LayoutMode

    @State private var hovering = false

    private var isSelected: Bool { model.selection.contains(item.url) }

    var body: some View {
        HStack(spacing: 6) {
            if model.showItemCheckBoxes {
                ItemCheckBox(isOn: isSelected) {
                    model.select(item, extending: false, toggling: true)
                }
            }

            FileIcon(url: item.url, size: mode.iconSize)

            VStack(alignment: .leading, spacing: 1) {
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

                if mode == .tiles {
                    Text(item.typeDescription)
                        .font(Win10.small)
                        .foregroundColor(Win10.secondaryText)
                        .lineLimit(1)
                    if !item.sizeText.isEmpty {
                        Text(item.sizeText)
                            .font(Win10.small)
                            .foregroundColor(Win10.secondaryText)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ItemBackground(isSelected: isSelected, isHovering: hovering))
        .opacity(ExplorerClipboard.shared.isCut(item.url) ? 0.5 : 1)
        .onHover { hovering = $0 }
        .itemInteraction(model: model, item: item)
    }
}
