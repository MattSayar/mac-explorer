import SwiftUI

/// The bottom strip: item and selection counts on the left, the two quick
/// layout toggles on the right.
struct StatusBarView: View {
    @ObservedObject var model: ExplorerViewModel

    var body: some View {
        HStack(spacing: 0) {
            Text(model.statusText)
                .font(Win10.small)
                .foregroundColor(Win10.text)
                .lineLimit(1)
                .padding(.leading, 8)

            if model.isSearching {
                ProgressView()
                    .controlSize(.mini)
                    .padding(.leading, 8)
            }

            Spacer(minLength: 8)

            layoutToggle(mode: .details, systemImage: "list.dash", help: "Details view")
            layoutToggle(mode: .largeIcons, systemImage: "square.grid.2x2", help: "Large icons view")
        }
        .frame(height: Win10.statusBarHeight)
        .background(Win10.statusBar)
        .win10Divider(Win10.ribbonBorder, edge: .top)
    }

    private func layoutToggle(mode: LayoutMode, systemImage: String, help: String) -> some View {
        Button {
            model.layout = mode
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundColor(model.layout == mode ? Win10.accent : Win10.secondaryText)
                .frame(width: 26, height: 20)
                .background(model.layout == mode ? Win10.selectionFill : Color.clear)
        }
        .buttonStyle(Win10ButtonStyle(cornerRadius: 1))
        .help(help)
        .padding(.trailing, 2)
    }
}
