import AppKit
import Combine
import SwiftUI

@MainActor
final class ExplorerViewModel: ObservableObject {

    // MARK: - Location

    @Published private(set) var currentURL: URL
    @Published private(set) var items: [FileItem] = []
    @Published private(set) var groups: [ItemGroup] = []
    @Published private(set) var loadError: String?

    private var backStack: [URL] = []
    private var forwardStack: [URL] = []
    private let watcher = FolderWatcher()

    // MARK: - Selection

    @Published var selection: Set<URL> = []
    @Published var collapsedGroups: Set<String> = []
    @Published var renamingURL: URL?
    private var selectionAnchor: URL?

    // MARK: - View options

    // Restoring saved options writes these in bulk, so each observer checks
    // isRestoring rather than reloading the folder once per setting.
    @Published var layout: LayoutMode = .details { didSet { persist() } }
    @Published var sortColumn: SortColumn = .name { didSet { guard !isRestoring else { return }; rebuild(); persist() } }
    @Published var sortAscending: Bool = true { didSet { guard !isRestoring else { return }; rebuild(); persist() } }
    @Published var groupBy: GroupKind = .none { didSet { guard !isRestoring else { return }; rebuild(); persist() } }
    @Published var showHiddenItems: Bool = false {
        didSet {
            guard !isRestoring else { return }
            DirectoryFacts.invalidate()
            reload()
            persist()
        }
    }
    @Published var showFileExtensions: Bool = true { didSet { persist() } }
    @Published var showItemCheckBoxes: Bool = false { didSet { persist() } }

    @Published var showNavigationPane: Bool = true { didSet { persist() } }
    @Published var showPreviewPane: Bool = false {
        didSet {
            if showPreviewPane, !isRestoring { showDetailsPane = false }
            persist()
        }
    }
    @Published var showDetailsPane: Bool = false {
        didSet {
            if showDetailsPane, !isRestoring { showPreviewPane = false }
            persist()
        }
    }
    @Published var ribbonExpanded: Bool = true { didSet { persist() } }
    @Published var ribbonTab: RibbonTab = .home

    @Published var columnWidths: [SortColumn: CGFloat] = [
        .name: SortColumn.name.defaultWidth,
        .dateModified: SortColumn.dateModified.defaultWidth,
        .type: SortColumn.type.defaultWidth,
        .size: SortColumn.size.defaultWidth
    ]

    // MARK: - Search

    @Published var searchText: String = ""
    @Published private(set) var isSearching = false
    private var searchToken: SearchToken?
    private var searchConsumer: Task<Void, Never>?
    private var searchDebounce: Task<Void, Never>?
    private var searchWasActive = false

    // MARK: - Navigation pane

    @Published var quickAccess: [SidebarEntry] = []
    @Published var expandedFolders: Set<URL> = []
    @Published var collapsedSections: Set<String> = []
    private var childrenCache: [URL: [FileItem]] = [:]

    // MARK: - Alerts

    @Published var errorMessage: String?
    @Published var propertiesTarget: [FileItem]?

    private let defaults = UserDefaults.standard
    private var isRestoring = false

    // MARK: - Init

    init(startingAt url: URL = KnownFolders.startupLocation) {
        self.currentURL = url
        restore()
        self.quickAccess = loadQuickAccess()
        reload()
        startWatching()
    }

    // MARK: - Derived state

    /// Rows in visual order, flattened across group headers — the order that
    /// shift-click ranges and arrow keys walk.
    var flatItems: [FileItem] {
        groups.flatMap(\.items)
    }

    var isGrouped: Bool { groupBy != .none }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }
    var canGoUp: Bool { currentURL.path != "/" }

    var parentURL: URL? {
        guard canGoUp else { return nil }
        return currentURL.deletingLastPathComponent()
    }

    var recentLocations: [URL] {
        Array(backStack.reversed().prefix(10))
    }

    var selectedItems: [FileItem] {
        flatItems.filter { selection.contains($0.url) }
    }

    var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var title: String {
        isSearchActive
            ? "Search Results in \(KnownFolders.displayName(for: currentURL))"
            : KnownFolders.displayName(for: currentURL)
    }

    /// The left half of the status bar: "24 items" / "2 items selected  1.4 MB".
    var statusText: String {
        if selection.isEmpty {
            return Format.itemCount(flatItems.count)
        }
        let selected = selectedItems
        let bytes = selected.reduce(Int64(0)) { $0 + ($1.isNavigable ? 0 : $1.size) }
        let countText = selected.count == 1 ? "1 item selected" : "\(selected.count) items selected"
        guard bytes > 0 else { return "\(Format.itemCount(flatItems.count))    \(countText)" }
        return "\(Format.itemCount(flatItems.count))    \(countText)    \(Format.explorerSize(bytes))"
    }

    // MARK: - Loading

    func reload() {
        guard !isSearchActive else {
            runSearch()
            return
        }

        do {
            items = try FileSystemService.contents(of: currentURL, includeHidden: showHiddenItems)
            loadError = nil
        } catch {
            items = []
            loadError = friendlyLoadError(error)
        }

        // Drop selection for anything that no longer exists.
        let present = Set(items.map(\.url))
        selection = selection.intersection(present)
        rebuild()
    }

    private func friendlyLoadError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.code == NSFileReadNoPermissionError {
            return "You don't currently have permission to access this folder."
        }
        if nsError.code == NSFileReadNoSuchFileError {
            return "This folder no longer exists."
        }
        return nsError.localizedDescription
    }

    private func rebuild() {
        let sorted = FileSystemService.sorted(items, by: sortColumn, ascending: sortAscending)
        var built = FileSystemService.grouped(sorted, by: groupBy, ascending: sortAscending)
        if groupBy == .dateModified {
            built = FileSystemService.sortedDateGroups(built)
        }
        groups = built
    }

    private func startWatching() {
        watcher.onChange = { [weak self] in
            guard let self, !self.isSearchActive else { return }
            self.reload()
        }
        watcher.watch(currentURL)
    }

    // MARK: - Navigation

    func navigate(to url: URL, recordHistory: Bool = true) {
        let resolved = url.resolvingSymlinksInPath()
        guard FileSystemService.isDirectory(resolved) || url.path == "/" else {
            FileOperations.open(url)
            return
        }
        guard resolved != currentURL else {
            reload()
            return
        }

        if recordHistory {
            backStack.append(currentURL)
            forwardStack.removeAll()
        }

        currentURL = resolved
        cancelSearch()
        searchText = ""
        selection = []
        selectionAnchor = nil
        renamingURL = nil
        reload()
        watcher.watch(resolved)
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentURL)
        navigate(to: previous, recordHistory: false)
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentURL)
        navigate(to: next, recordHistory: false)
    }

    func goUp() {
        guard let parent = parentURL else { return }
        let child = currentURL
        navigate(to: parent)
        // Explorer highlights the folder you just came out of.
        selection = [child]
        selectionAnchor = child
    }

    func open(_ item: FileItem) {
        if item.isNavigable {
            navigate(to: item.url)
        } else {
            FileOperations.open(item.url)
        }
    }

    func openSelection() {
        let selected = selectedItems
        guard !selected.isEmpty else { return }
        if selected.count == 1, let first = selected.first {
            open(first)
        } else {
            FileOperations.open(selected.filter { !$0.isNavigable }.map(\.url))
        }
    }

    // MARK: - Selection

    func select(_ item: FileItem, extending: Bool, toggling: Bool) {
        if toggling {
            if selection.contains(item.url) {
                selection.remove(item.url)
            } else {
                selection.insert(item.url)
            }
            selectionAnchor = item.url
        } else if extending, let anchor = selectionAnchor {
            let ordered = flatItems
            guard let start = ordered.firstIndex(where: { $0.url == anchor }),
                  let end = ordered.firstIndex(where: { $0.url == item.url }) else {
                selection = [item.url]
                selectionAnchor = item.url
                return
            }
            let range = start <= end ? start...end : end...start
            selection = Set(ordered[range].map(\.url))
        } else {
            selection = [item.url]
            selectionAnchor = item.url
        }
    }

    func toggleGroup(_ id: String) {
        if collapsedGroups.contains(id) {
            collapsedGroups.remove(id)
        } else {
            collapsedGroups.insert(id)
        }
    }

    func selectAll() {
        selection = Set(flatItems.map(\.url))
    }

    func selectNone() {
        selection = []
        selectionAnchor = nil
    }

    func invertSelection() {
        let all = Set(flatItems.map(\.url))
        selection = all.subtracting(selection)
    }

    /// Arrow-key movement through the flattened row order.
    func moveSelection(by offset: Int, extending: Bool) {
        let ordered = flatItems
        guard !ordered.isEmpty else { return }

        let currentIndex = selectionAnchor.flatMap { anchor in
            ordered.firstIndex(where: { $0.url == anchor })
        } ?? (offset > 0 ? -1 : ordered.count)

        let target = max(0, min(ordered.count - 1, currentIndex + offset))
        let item = ordered[target]

        if extending {
            select(item, extending: true, toggling: false)
            selectionAnchor = selectionAnchor ?? item.url
        } else {
            selection = [item.url]
            selectionAnchor = item.url
        }
    }

    // MARK: - Commands

    func newFolder() {
        do {
            let url = try FileOperations.createFolder(in: currentURL)
            reload()
            selection = [url]
            selectionAnchor = url
            renamingURL = url
        } catch {
            present(error)
        }
    }

    func newFile(baseName: String, extension ext: String) {
        do {
            let url = try FileOperations.createFile(in: currentURL, baseName: baseName, extension: ext)
            reload()
            selection = [url]
            renamingURL = url
        } catch {
            present(error)
        }
    }

    func beginRename() {
        guard selection.count == 1, let url = selection.first else { return }
        renamingURL = url
    }

    func commitRename(_ url: URL, to newName: String) {
        renamingURL = nil
        let currentName = url.lastPathComponent
        // The user may have edited a stem while extensions were hidden.
        let finalName: String = {
            guard !showFileExtensions, !url.pathExtension.isEmpty,
                  !newName.contains("."), !FileSystemService.isDirectory(url) else {
                return newName
            }
            return "\(newName).\(url.pathExtension)"
        }()
        guard finalName != currentName else { return }

        do {
            let renamed = try FileOperations.rename(url, to: finalName)
            reload()
            selection = [renamed]
            selectionAnchor = renamed
        } catch {
            present(error)
        }
    }

    func cancelRename() {
        renamingURL = nil
    }

    func deleteSelection(permanently: Bool = false) {
        let urls = Array(selection)
        guard !urls.isEmpty else { return }
        do {
            if permanently {
                try FileOperations.deletePermanently(urls)
            } else {
                try FileOperations.moveToTrash(urls)
            }
            selection = []
            selectionAnchor = nil
            reload()
        } catch {
            present(error)
        }
    }

    func copySelection() {
        guard !selection.isEmpty else { return }
        ExplorerClipboard.shared.copy(Array(selection))
    }

    func cutSelection() {
        guard !selection.isEmpty else { return }
        ExplorerClipboard.shared.cut(Array(selection))
    }

    func copyPath() {
        let urls = selection.isEmpty ? [currentURL] : Array(selection)
        let text = urls.map(\.path).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func paste(into directory: URL? = nil) {
        do {
            let created = try ExplorerClipboard.shared.paste(into: directory ?? currentURL)
            reload()
            if !created.isEmpty, directory == nil || directory == currentURL {
                selection = Set(created)
            }
        } catch {
            present(error)
        }
    }

    func moveSelection(to directory: URL) {
        guard !selection.isEmpty else { return }
        do {
            try FileOperations.move(Array(selection), to: directory)
            selection = []
            reload()
        } catch {
            present(error)
        }
    }

    func copySelection(to directory: URL) {
        guard !selection.isEmpty else { return }
        do {
            try FileOperations.copy(Array(selection), to: directory)
            reload()
        } catch {
            present(error)
        }
    }

    /// Explorer's "Paste shortcut"; the macOS equivalent is a symbolic link.
    func pasteShortcut() {
        let urls = ExplorerClipboard.shared.pasteboardURLs
        guard !urls.isEmpty else { return }
        do {
            var created: [URL] = []
            for source in urls {
                let ext = source.pathExtension
                let stem = ext.isEmpty
                    ? source.lastPathComponent
                    : String(source.lastPathComponent.dropLast(ext.count + 1))
                let destination = FileOperations.uniqueURL(
                    in: currentURL,
                    baseName: "\(stem) - Shortcut",
                    extension: ext
                )
                try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: source)
                created.append(destination)
            }
            reload()
            selection = Set(created)
        } catch {
            present(error)
        }
    }

    /// "Choose location…" at the bottom of the Move to / Copy to menus.
    func chooseDestination(_ action: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select Folder"
        panel.directoryURL = currentURL
        if panel.runModal() == .OK, let url = panel.url {
            action(url)
        }
    }

    func moveDropped(_ urls: [URL], to directory: URL) {
        do {
            let moved = try FileOperations.move(urls, to: directory)
            reload()
            if directory == currentURL { selection = Set(moved) }
        } catch {
            present(error)
        }
    }

    func copyDropped(_ urls: [URL], to directory: URL) {
        do {
            let copied = try FileOperations.copy(urls, to: directory)
            reload()
            if directory == currentURL { selection = Set(copied) }
        } catch {
            present(error)
        }
    }

    func showProperties() {
        let targets = selectedItems
        propertiesTarget = targets.isEmpty
            ? [FileSystemService.item(at: currentURL)].compactMap { $0 }
            : targets
    }

    /// The Zip command, using ditto so resource forks survive the archive.
    func compressSelection() {
        let urls = selection.isEmpty ? [currentURL] : Array(selection)
        guard !urls.isEmpty else { return }

        let baseName = urls.count == 1
            ? urls[0].deletingPathExtension().lastPathComponent
            : "Archive"
        let archive = FileOperations.uniqueURL(in: currentURL, baseName: baseName, extension: "zip")

        do {
            try FileOperations.compress(urls, to: archive)
            reload()
            selection = [archive]
        } catch {
            present(error)
        }
    }

    func duplicateSelection() {
        guard !selection.isEmpty else { return }
        do {
            let created = try FileOperations.copy(Array(selection), to: currentURL)
            reload()
            selection = Set(created)
        } catch {
            present(error)
        }
    }

    /// Widens each column to its longest visible value, capped the way
    /// "Size all columns to fit" does.
    func sizeColumnsToFit() {
        let rows = flatItems
        guard !rows.isEmpty else { return }

        func width(of strings: [String], padding: CGFloat) -> CGFloat {
            let font = NSFont.systemFont(ofSize: 12)
            let widest = strings.reduce(CGFloat(0)) { longest, text in
                max(longest, (text as NSString).size(withAttributes: [.font: font]).width)
            }
            return min(500, max(60, widest + padding))
        }

        columnWidths[.name] = width(
            of: rows.map { $0.displayName(showExtensions: showFileExtensions) },
            padding: 46
        )
        columnWidths[.dateModified] = width(of: rows.map { Format.listDate($0.dateModified) }, padding: 24)
        columnWidths[.type] = width(of: rows.map(\.typeDescription), padding: 24)
        columnWidths[.size] = width(of: rows.map(\.sizeText), padding: 24)
    }

    func resetColumns() {
        columnWidths = [
            .name: SortColumn.name.defaultWidth,
            .dateModified: SortColumn.dateModified.defaultWidth,
            .type: SortColumn.type.defaultWidth,
            .size: SortColumn.size.defaultWidth
        ]
    }

    func revealInFinder() {
        let urls = selection.isEmpty ? [currentURL] : Array(selection)
        FileOperations.revealInFinder(urls)
    }

    // MARK: - Sorting from the column headers

    func applySort(_ column: SortColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            // Dates and sizes open descending in Explorer; names open ascending.
            sortAscending = !(column == .dateModified || column == .size)
        }
    }

    func width(for column: SortColumn) -> CGFloat {
        columnWidths[column] ?? column.defaultWidth
    }

    func setWidth(_ width: CGFloat, for column: SortColumn) {
        columnWidths[column] = max(48, min(900, width))
    }

    // MARK: - Search

    /// Explorer searches as you type; a short debounce keeps each keystroke
    /// from starting a new directory walk.
    func scheduleSearch() {
        searchDebounce?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty else {
            cancelSearch()
            isSearching = false
            if searchWasActive {
                searchWasActive = false
                reload()
            }
            return
        }

        searchWasActive = true
        searchDebounce = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self.runSearch()
        }
    }

    func runSearch() {
        cancelSearch()
        let query = searchText.trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty else {
            isSearching = false
            reload()
            return
        }

        items = []
        groups = []
        selection = []
        isSearching = true

        let token = SearchToken()
        searchToken = token
        let directory = currentURL
        let includeHidden = showHiddenItems

        // The scan runs off the main thread and hands results back through a
        // stream, so nothing but Sendable values crosses the boundary.
        let batches = AsyncStream<[FileItem]> { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                FileSystemService.search(
                    in: directory,
                    query: query,
                    includeHidden: includeHidden,
                    onBatch: { continuation.yield($0) },
                    isCancelled: { token.isCancelled }
                )
                continuation.finish()
            }
        }

        searchConsumer = Task { @MainActor in
            for await batch in batches {
                guard self.searchToken === token else { return }
                self.items.append(contentsOf: batch)
                self.rebuild()
            }
            if self.searchToken === token {
                self.isSearching = false
            }
        }
    }

    private func cancelSearch() {
        searchDebounce?.cancel()
        searchDebounce = nil
        searchToken?.cancel()
        searchToken = nil
        searchConsumer?.cancel()
        searchConsumer = nil
    }

    func clearSearch() {
        cancelSearch()
        searchText = ""
        isSearching = false
        searchWasActive = false
        reload()
    }

    // MARK: - Navigation pane

    func children(of url: URL) -> [FileItem] {
        if let cached = childrenCache[url] { return cached }
        let children = FileSystemService.subdirectories(of: url, includeHidden: showHiddenItems)
        childrenCache[url] = children
        return children
    }

    func toggleExpansion(_ url: URL) {
        if expandedFolders.contains(url) {
            expandedFolders.remove(url)
        } else {
            childrenCache[url] = nil
            expandedFolders.insert(url)
            _ = children(of: url)
        }
    }

    func toggleSection(_ id: String) {
        if collapsedSections.contains(id) {
            collapsedSections.remove(id)
        } else {
            collapsedSections.insert(id)
        }
    }

    func isPinned(_ url: URL) -> Bool {
        quickAccess.contains { $0.url == url }
    }

    func pinToQuickAccess(_ urls: [URL]) {
        for url in urls where !isPinned(url) && FileSystemService.isDirectory(url) {
            quickAccess.append(SidebarEntry(url: url, title: KnownFolders.displayName(for: url)))
        }
        saveQuickAccess()
    }

    func unpinFromQuickAccess(_ url: URL) {
        quickAccess.removeAll { $0.url == url }
        saveQuickAccess()
    }

    // MARK: - Errors

    func present(_ error: Error) {
        errorMessage = (error as? FileOperationError)?.errorDescription ?? error.localizedDescription
    }

    // MARK: - Persistence

    private enum Key {
        static let layout = "layout"
        static let sortColumn = "sortColumn"
        static let sortAscending = "sortAscending"
        static let groupBy = "groupBy"
        static let showHidden = "showHiddenItems"
        static let showExtensions = "showFileExtensions"
        static let showCheckBoxes = "showItemCheckBoxes"
        static let navigationPane = "showNavigationPane"
        static let previewPane = "showPreviewPane"
        static let detailsPane = "showDetailsPane"
        static let ribbonExpanded = "ribbonExpanded"
        static let quickAccess = "quickAccessPins"
    }

    private func persist() {
        guard !isRestoring else { return }
        defaults.set(layout.rawValue, forKey: Key.layout)
        defaults.set(sortColumn.rawValue, forKey: Key.sortColumn)
        defaults.set(sortAscending, forKey: Key.sortAscending)
        defaults.set(groupBy.rawValue, forKey: Key.groupBy)
        defaults.set(showHiddenItems, forKey: Key.showHidden)
        defaults.set(showFileExtensions, forKey: Key.showExtensions)
        defaults.set(showItemCheckBoxes, forKey: Key.showCheckBoxes)
        defaults.set(showNavigationPane, forKey: Key.navigationPane)
        defaults.set(showPreviewPane, forKey: Key.previewPane)
        defaults.set(showDetailsPane, forKey: Key.detailsPane)
        defaults.set(ribbonExpanded, forKey: Key.ribbonExpanded)
    }

    private func restore() {
        isRestoring = true
        defer { isRestoring = false }

        if let raw = defaults.string(forKey: Key.layout), let value = LayoutMode(rawValue: raw) {
            layout = value
        }
        if let raw = defaults.string(forKey: Key.sortColumn), let value = SortColumn(rawValue: raw) {
            sortColumn = value
        }
        if defaults.object(forKey: Key.sortAscending) != nil {
            sortAscending = defaults.bool(forKey: Key.sortAscending)
        }
        if let raw = defaults.string(forKey: Key.groupBy), let value = GroupKind(rawValue: raw) {
            groupBy = value
        }
        showHiddenItems = defaults.bool(forKey: Key.showHidden)
        showFileExtensions = defaults.object(forKey: Key.showExtensions) as? Bool ?? true
        showItemCheckBoxes = defaults.bool(forKey: Key.showCheckBoxes)
        showNavigationPane = defaults.object(forKey: Key.navigationPane) as? Bool ?? true
        showPreviewPane = defaults.bool(forKey: Key.previewPane)
        showDetailsPane = defaults.bool(forKey: Key.detailsPane)
        ribbonExpanded = defaults.object(forKey: Key.ribbonExpanded) as? Bool ?? true
    }

    private func loadQuickAccess() -> [SidebarEntry] {
        guard let paths = defaults.stringArray(forKey: Key.quickAccess) else {
            return KnownFolders.defaultQuickAccess()
        }
        let entries = paths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { SidebarEntry(url: $0, title: KnownFolders.displayName(for: $0)) }
        return entries.isEmpty ? KnownFolders.defaultQuickAccess() : entries
    }

    private func saveQuickAccess() {
        defaults.set(quickAccess.map(\.url.path), forKey: Key.quickAccess)
    }
}
