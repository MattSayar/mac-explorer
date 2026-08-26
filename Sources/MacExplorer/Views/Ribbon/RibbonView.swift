import AppKit
import SwiftUI

enum RibbonTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case share = "Share"
    case view = "View"

    var id: String { rawValue }
}

struct RibbonView: View {
    @ObservedObject var model: ExplorerViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            if model.ribbonExpanded {
                ribbonBody
            }
        }
        .background(Win10.ribbonBackground)
        .win10Divider(Win10.ribbonBorder)
    }

    // MARK: - Tab strip

    private var tabStrip: some View {
        HStack(spacing: 0) {
            fileTab

            ForEach(RibbonTab.allCases) { tab in
                RibbonTabButton(
                    title: tab.rawValue,
                    isSelected: model.ribbonTab == tab && model.ribbonExpanded
                ) {
                    if model.ribbonTab == tab && model.ribbonExpanded {
                        model.ribbonExpanded = false
                    } else {
                        model.ribbonTab = tab
                        model.ribbonExpanded = true
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                model.ribbonExpanded.toggle()
            } label: {
                Image(systemName: model.ribbonExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Win10.secondaryText)
                    .frame(width: 26, height: Win10.ribbonTabHeight)
            }
            .buttonStyle(Win10ButtonStyle())
            .help(model.ribbonExpanded ? "Minimize the Ribbon" : "Expand the Ribbon")
        }
        .frame(height: Win10.ribbonTabHeight)
        .background(Win10.ribbonTabStrip)
    }

    private var fileTab: some View {
        Menu {
            Button("Open new window") { openWindow(id: "explorer", value: model.currentURL) }
            Button("Open Terminal") { FileOperations.openInTerminal(model.currentURL) }
            Divider()
            Button("Reveal in Finder") { model.revealInFinder() }
            Button("Copy path") { model.copyPath() }
            Divider()
            Button("Close") { NSApp.keyWindow?.performClose(nil) }
        } label: {
            Text("File")
                .font(Win10.body)
                .foregroundColor(.white)
                .frame(width: 52, height: Win10.ribbonTabHeight)
                .background(Win10.fileTabBlue)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: - Body

    private var ribbonBody: some View {
        HStack(alignment: .top, spacing: 0) {
            switch model.ribbonTab {
            case .home: HomeTabView(model: model)
            case .share: ShareTabView(model: model)
            case .view: ViewTabView(model: model)
            }
            Spacer(minLength: 0)
        }
        .frame(height: Win10.ribbonBodyHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Win10.ribbonBackground)
    }
}

private struct RibbonTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Win10.body)
                .foregroundColor(Win10.text)
                .padding(.horizontal, 14)
                .frame(height: Win10.ribbonTabHeight)
                .background(background)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            // The active tab merges into the ribbon body below it.
            Win10.ribbonBackground
                .overlay(alignment: .top) { Win10.ribbonBorder.frame(height: 1) }
                .overlay(alignment: .leading) { Win10.ribbonBorder.frame(width: 1) }
                .overlay(alignment: .trailing) { Win10.ribbonBorder.frame(width: 1) }
        } else if hovering {
            Win10.controlHover
        } else {
            Color.clear
        }
    }
}
