import AppKit
import SwiftUI

/// Explorer's Details layout: a pinned column header over fixed-height rows.
struct DetailsView: View {
    @ObservedObject var model: ExplorerViewModel

    private var columns: [SortColumn] { SortColumn.allCases }

    private var totalColumnWidth: CGFloat {
        columns.reduce(0) { $0 + model.width(for: $1) }
    }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(totalColumnWidth, geometry.size.width)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    DetailsHeader(model: model, columns: columns)
                        .frame(width: contentWidth)

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
                                    .frame(width: contentWidth, alignment: .leading)
                                }

                                if !model.collapsedGroups.contains(group.id) {
                                    ForEach(group.items) { item in
                                        DetailsRow(model: model, item: item, columns: columns)
                                            .frame(width: contentWidth)
                                    }
                                }
                            }
                        }
                        .frame(width: contentWidth, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct DetailsHeader: View {
    @ObservedObject var model: ExplorerViewModel
    let columns: [SortColumn]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                DetailsHeaderCell(model: model, column: column)
            }
            Spacer(minLength: 0)
        }
        .frame(height: Win10.columnHeaderHeight)
        .background(Color.white)
        .win10Divider(Win10.separator)
    }
}

private struct DetailsHeaderCell: View {
    @ObservedObject var model: ExplorerViewModel
    let column: SortColumn

    @State private var hovering = false
    @State private var dragStartWidth: CGFloat?

    var body: some View {
        HStack(spacing: 2) {
            Text(column.title)
                .font(Win10.body)
                .foregroundColor(Win10.headerText)
                .lineLimit(1)

            if model.sortColumn == column {
                Image(systemName: model.sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(Win10.accent)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(width: model.width(for: column), height: Win10.columnHeaderHeight, alignment: .leading)
        .background(hovering ? Win10.columnHeaderHover : Color.clear)
        .overlay(alignment: .trailing) {
            Win10.separator.frame(width: 1).padding(.vertical, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.applySort(column) }
        .onHover { hovering = $0 }
        .overlay(alignment: .trailing) {
            // Drag the rule between headers to resize, as in Explorer.
            Rectangle()
                .fill(Color.clear)
                .frame(width: 6)
                .contentShape(Rectangle())
                .onHover { inside in
                    if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                }
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            let start = dragStartWidth ?? model.width(for: column)
                            if dragStartWidth == nil { dragStartWidth = start }
                            model.setWidth(start + value.translation.width, for: column)
                        }
                        .onEnded { _ in dragStartWidth = nil }
                )
        }
        .contextMenu {
            ForEach(SortColumn.allCases) { option in
                MenuCheckItem(title: option.title, isOn: model.sortColumn == option) {
                    model.applySort(option)
                }
            }
            Divider()
            Button("Size all columns to fit") { model.sizeColumnsToFit() }
            Button("Reset columns") { model.resetColumns() }
        }
    }
}

private struct DetailsRow: View {
    @ObservedObject var model: ExplorerViewModel
    let item: FileItem
    let columns: [SortColumn]

    @State private var hovering = false

    private var isSelected: Bool { model.selection.contains(item.url) }
    private var isRenaming: Bool { model.renamingURL == item.url }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                cell(for: column)
                    .frame(width: model.width(for: column), alignment: column.isTrailingAligned ? .trailing : .leading)
            }
            Spacer(minLength: 0)
        }
        .frame(height: Win10.detailsRowHeight)
        .background(ItemBackground(isSelected: isSelected, isHovering: hovering))
        .opacity(ExplorerClipboard.shared.isCut(item.url) ? 0.5 : 1)
        .onHover { hovering = $0 }
        .itemInteraction(model: model, item: item)
    }

    @ViewBuilder
    private func cell(for column: SortColumn) -> some View {
        switch column {
        case .name:
            HStack(spacing: 4) {
                if model.showItemCheckBoxes {
                    ItemCheckBox(isOn: isSelected) {
                        model.select(item, extending: false, toggling: true)
                    }
                    .padding(.leading, 4)
                }

                FileIcon(url: item.url, size: 16)
                    .padding(.leading, model.showItemCheckBoxes ? 0 : 6)

                if isRenaming {
                    RenameField(
                        initialText: item.displayName(showExtensions: model.showFileExtensions),
                        onCommit: { model.commitRename(item.url, to: $0) },
                        onCancel: { model.cancelRename() }
                    )
                    .padding(.trailing, 4)
                } else {
                    Text(item.displayName(showExtensions: model.showFileExtensions))
                        .font(Win10.body)
                        .foregroundColor(Win10.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
            }
        case .dateModified:
            text(Format.listDate(item.dateModified))
        case .type:
            text(item.typeDescription)
        case .size:
            text(item.sizeText)
                .padding(.trailing, 10)
        }
    }

    private func text(_ value: String) -> some View {
        Text(value)
            .font(Win10.body)
            .foregroundColor(Win10.text)
            .lineLimit(1)
            .padding(.horizontal, 6)
    }
}

/// The blue caption above each run of grouped items.
struct GroupHeader: View {
    let group: ItemGroup
    let isCollapsed: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Win10.groupHeaderText)
                    .opacity(hovering ? 1 : 0.6)

                Text(group.title)
                    .font(Win10.body)
                    .foregroundColor(Win10.groupHeaderText)

                Text("(\(group.items.count))")
                    .font(Win10.small)
                    .foregroundColor(Win10.secondaryText)

                Rectangle()
                    .fill(Win10.separator)
                    .frame(height: 1)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
