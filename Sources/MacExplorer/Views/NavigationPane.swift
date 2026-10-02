import AppKit
import Combine
import SwiftUI

struct NavigationPane: View {
    @ObservedObject var model: ExplorerViewModel

    // Enumerating mounted volumes touches the disk, so the roots are built
    // once and refreshed when something mounts or unmounts.
    @State private var macRoots: [SidebarEntry] = []

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                section(
                    id: "quick",
                    title: "Quick access",
                    systemImage: "pin.fill",
                    entries: model.quickAccess,
                    expandable: false
                )

                section(
                    id: "thismac",
                    title: "This Mac",
                    systemImage: "desktopcomputer",
                    entries: macRoots,
                    expandable: true
                )

                section(
                    id: "network",
                    title: "Network",
                    systemImage: "network",
                    entries: KnownFolders.network(),
                    expandable: true
                )
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Win10.navigationPane)
        .onAppear {
            if macRoots.isEmpty { macRoots = KnownFolders.thisMac() }
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)
        ) { _ in
            macRoots = KnownFolders.thisMac()
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didUnmountNotification)
        ) { _ in
            macRoots = KnownFolders.thisMac()
        }
    }

    @ViewBuilder
    private func section(
        id: String,
        title: String,
        systemImage: String,
        entries: [SidebarEntry],
        expandable: Bool
    ) -> some View {
        let collapsed = model.collapsedSections.contains(id)

        SidebarSectionHeader(
            title: title,
            systemImage: systemImage,
            isCollapsed: collapsed
        ) {
            model.toggleSection(id)
        }

        if !collapsed {
            ForEach(entries) { entry in
                SidebarRow(
                    url: entry.url,
                    title: entry.title,
                    depth: 1,
                    expandable: expandable,
                    model: model
                )
            }
        }
    }
}

private struct SidebarSectionHeader: View {
    let title: String
    let systemImage: String
    let isCollapsed: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Win10.secondaryText)
                    .frame(width: 14)
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .foregroundColor(Win10.accent)
                    .frame(width: 18)
                Text(title)
                    .font(Win10.body)
                    .foregroundColor(Win10.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .frame(height: Win10.sidebarRowHeight)
            .background(hovering ? Win10.hoverFill : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// One folder in the tree. Recurses into its children while expanded.
private struct SidebarRow: View {
    let url: URL
    let title: String
    let depth: Int
    let expandable: Bool
    @ObservedObject var model: ExplorerViewModel

    @Environment(\.openWindow) private var openWindow
    @State private var hovering = false

    private var isExpanded: Bool { model.expandedFolders.contains(url) }
    private var isCurrent: Bool { model.currentURL == url }

    private var hasChildren: Bool {
        expandable && DirectoryFacts.hasSubdirectories(url, includeHidden: model.showHiddenItems)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row

            if isExpanded {
                ForEach(model.children(of: url)) { child in
                    SidebarRow(
                        url: child.url,
                        title: child.name,
                        depth: depth + 1,
                        expandable: true,
                        model: model
                    )
                }
            }
        }
    }

    private var row: some View {
        HStack(spacing: 3) {
            Group {
                if hasChildren {
                    Button {
                        model.toggleExpansion(url)
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            // Explorer only paints the triangles once the pane is hovered.
                            .foregroundColor(hovering || isExpanded ? Win10.secondaryText : Win10.disabledText)
                            .frame(width: 14, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 14, height: 18)
                }
            }
            .padding(.leading, CGFloat(depth - 1) * Win10.sidebarIndent)

            FileIcon(url: url, size: 16)

            Text(title)
                .font(Win10.body)
                .foregroundColor(Win10.text)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(height: Win10.sidebarRowHeight)
        .background(background)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { model.toggleExpansion(url) }
        .onTapGesture { model.navigate(to: url) }
        .contextMenu {
            Button("Open") { model.navigate(to: url) }
            Button("Open in new window") { openWindow(id: "explorer", value: url) }
            Divider()
            if model.isPinned(url) {
                Button("Unpin from Quick access") { model.unpinFromQuickAccess(url) }
            } else {
                Button("Pin to Quick access") { model.pinToQuickAccess([url]) }
            }
            Divider()
            Button("Reveal in Finder") { FileOperations.revealInFinder([url]) }
            Button("Copy path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
            }
            Divider()
            Button("Properties") {
                if let item = FileSystemService.item(at: url) {
                    model.propertiesTarget = [item]
                }
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if isCurrent {
            Win10.selectionFill.overlay(Rectangle().stroke(Win10.selectionBorder, lineWidth: 1))
        } else if hovering {
            Win10.hoverFill.overlay(Rectangle().stroke(Win10.hoverBorder, lineWidth: 1))
        } else {
            Color.clear
        }
    }
}
