import SwiftUI

struct ViewTabView: View {
    @ObservedObject var model: ExplorerViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 0) {

            RibbonGroup(title: "Panes") {
                RibbonBigMenu(title: "Navigation\npane", systemImage: "sidebar.left", width: 70) {
                    Toggle("Navigation pane", isOn: $model.showNavigationPane)
                    Divider()
                    Toggle("Show all folders", isOn: $model.showHiddenItems)
                }
                RibbonBigButton(title: "Preview\npane", systemImage: "doc.text.image", width: 62) {
                    model.showPreviewPane.toggle()
                }
                RibbonBigButton(title: "Details\npane", systemImage: "sidebar.right", width: 62) {
                    model.showDetailsPane.toggle()
                }
            }

            RibbonGroup(title: "Layout") {
                // Explorer shows the eight layouts as a scrolling gallery.
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        layoutColumn([.extraLargeIcons, .largeIcons, .mediumIcons])
                        layoutColumn([.smallIcons, .list, .details])
                        layoutColumn([.tiles, .content])
                    }
                }
                .padding(.top, 2)
            }

            RibbonGroup(title: "Current view") {
                RibbonBigMenu(title: "Sort\nby", systemImage: "arrow.up.arrow.down", width: 58) {
                    ForEach(SortColumn.allCases) { column in
                        MenuCheckItem(title: column.title, isOn: model.sortColumn == column) {
                            model.sortColumn = column
                        }
                    }
                    Divider()
                    MenuCheckItem(title: "Ascending", isOn: model.sortAscending) {
                        model.sortAscending = true
                    }
                    MenuCheckItem(title: "Descending", isOn: !model.sortAscending) {
                        model.sortAscending = false
                    }
                }

                RibbonBigMenu(title: "Group\nby", systemImage: "rectangle.3.group", width: 58) {
                    ForEach(GroupKind.allCases) { kind in
                        MenuCheckItem(title: kind.title, isOn: model.groupBy == kind) {
                            model.groupBy = kind
                        }
                    }
                }

                VStack(spacing: 0) {
                    RibbonSmallButton(title: "Size all columns to fit", systemImage: "arrow.left.and.right") {
                        model.sizeColumnsToFit()
                    }
                    RibbonSmallButton(title: "Reset columns", systemImage: "arrow.counterclockwise") {
                        model.resetColumns()
                    }
                    RibbonSmallButton(title: "Refresh", systemImage: "arrow.clockwise") {
                        model.reload()
                    }
                }
                .frame(width: 156)
            }

            RibbonGroup(title: "Show/hide") {
                VStack(spacing: 0) {
                    RibbonCheckBox(title: "Item check boxes", isOn: $model.showItemCheckBoxes)
                    RibbonCheckBox(title: "File name extensions", isOn: $model.showFileExtensions)
                    RibbonCheckBox(title: "Hidden items", isOn: $model.showHiddenItems)
                }
                .frame(width: 150)
            }
        }
    }

    private func layoutColumn(_ modes: [LayoutMode]) -> some View {
        VStack(spacing: 0) {
            ForEach(modes) { mode in
                RibbonLayoutItem(mode: mode, isSelected: model.layout == mode) {
                    model.layout = mode
                }
            }
            Spacer(minLength: 0)
        }
    }
}
