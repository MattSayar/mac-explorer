import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Hosts whichever layout is active, plus the empty/permission states and the
/// background click, context menu and drop behaviour that belong to the folder
/// rather than to any one item.
struct ContentPane: View {
    @ObservedObject var model: ExplorerViewModel

    @State private var isDropTargeted = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white
                .contentShape(Rectangle())
                .onTapGesture { model.selectNone() }
                .contextMenu { FolderContextMenu(model: model) }

            content
        }
        .overlay {
            if isDropTargeted {
                Rectangle()
                    .stroke(Win10.accent, lineWidth: 2)
                    .padding(1)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error = model.loadError {
            message(title: error, systemImage: "exclamationmark.triangle")
        } else if model.flatItems.isEmpty {
            if model.isSearching {
                message(title: "Searching…", systemImage: "magnifyingglass")
            } else if model.isSearchActive {
                message(
                    title: "No items match your search.",
                    systemImage: "magnifyingglass"
                )
            } else {
                message(title: "This folder is empty.", systemImage: "folder")
            }
        } else {
            switch model.layout {
            case .details:
                DetailsView(model: model)
            case .list:
                ListLayoutView(model: model)
            case .content:
                ContentLayoutView(model: model)
            default:
                IconsView(model: model, mode: model.layout)
            }
        }
    }

    private func message(title: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .thin))
                .foregroundColor(Win10.disabledText)
            Text(title)
                .font(Win10.body)
                .foregroundColor(Win10.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    /// Explorer moves within a drive and copies across drives; volume identity
    /// is the macOS equivalent of that rule.
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let destination = model.currentURL
        let collected = URLCollector()
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { collected.append(url) }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let sources = collected.urls.filter { $0.deletingLastPathComponent() != destination }
            guard !sources.isEmpty else { return }
            let sameVolume = sources.allSatisfy { volumeIdentifier(for: $0) == volumeIdentifier(for: destination) }
            if sameVolume {
                model.moveDropped(sources, to: destination)
            } else {
                model.copyDropped(sources, to: destination)
            }
        }
        return true
    }

    private func volumeIdentifier(for url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.volumeIdentifierKey])
        guard let identifier = values?.volumeIdentifier as? NSObject else { return url.path }
        return identifier.description
    }
}

/// Drop callbacks arrive on arbitrary threads, so the collected URLs need a lock.
private final class URLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    func append(_ url: URL) {
        lock.lock()
        storage.append(url)
        lock.unlock()
    }

    var urls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

struct FolderContextMenu: View {
    @ObservedObject var model: ExplorerViewModel
    @ObservedObject private var clipboard = ExplorerClipboard.shared

    var body: some View {
        Group {
            Menu("View") {
                ForEach(LayoutMode.allCases) { mode in
                    MenuCheckItem(title: mode.title, isOn: model.layout == mode) {
                        model.layout = mode
                    }
                }
            }
            Menu("Sort by") {
                ForEach(SortColumn.allCases) { column in
                    MenuCheckItem(title: column.title, isOn: model.sortColumn == column) {
                        model.sortColumn = column
                    }
                }
                Divider()
                MenuCheckItem(title: "Ascending", isOn: model.sortAscending) { model.sortAscending = true }
                MenuCheckItem(title: "Descending", isOn: !model.sortAscending) { model.sortAscending = false }
            }
            Menu("Group by") {
                ForEach(GroupKind.allCases) { kind in
                    MenuCheckItem(title: kind.title, isOn: model.groupBy == kind) {
                        model.groupBy = kind
                    }
                }
            }
            Button("Refresh") { model.reload() }

            Divider()

            Button("Paste") { model.paste() }
                .disabled(!clipboard.canPaste)
            Button("Paste shortcut") { model.pasteShortcut() }
                .disabled(!clipboard.canPaste)

            Divider()

            Menu("New") {
                Button("Folder") { model.newFolder() }
                Divider()
                Button("Text Document") { model.newFile(baseName: "New Text Document", extension: "txt") }
                Button("Rich Text Document") { model.newFile(baseName: "New Rich Text Document", extension: "rtf") }
                Button("Markdown Document") { model.newFile(baseName: "New Markdown Document", extension: "md") }
            }

            Divider()

            Button("Open Terminal here") { FileOperations.openInTerminal(model.currentURL) }
            Button("Reveal in Finder") { FileOperations.revealInFinder([model.currentURL]) }
            Button("Properties") {
                if let item = FileSystemService.item(at: model.currentURL) {
                    model.propertiesTarget = [item]
                }
            }
        }
    }
}
