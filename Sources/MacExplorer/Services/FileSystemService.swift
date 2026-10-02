import Foundation

enum FileSystemService {

    // MARK: - Reading

    static func contents(of directory: URL, includeHidden: Bool) throws -> [FileItem] {
        var options: FileManager.DirectoryEnumerationOptions = []
        if !includeHidden { options.insert(.skipsHiddenFiles) }

        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: FileItem.resourceKeys,
            options: options
        )

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(FileItem.resourceKeys)) else {
                return nil
            }
            return FileItem(url: url, values: values)
        }
    }

    static func item(at url: URL) -> FileItem? {
        guard let values = try? url.resourceValues(forKeys: Set(FileItem.resourceKeys)) else {
            return nil
        }
        return FileItem(url: url, values: values)
    }

    static func isDirectory(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return (values?.isDirectory ?? false) && !(values?.isPackage ?? false)
    }

    /// True when the folder has at least one child worth a disclosure triangle.
    static func hasSubdirectories(_ url: URL, includeHidden: Bool) -> Bool {
        var options: FileManager.DirectoryEnumerationOptions = []
        if !includeHidden { options.insert(.skipsHiddenFiles) }
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: options
        ) else { return false }
        return entries.contains { isDirectory($0) }
    }

    static func subdirectories(of url: URL, includeHidden: Bool) -> [FileItem] {
        let items = (try? contents(of: url, includeHidden: includeHidden)) ?? []
        return items
            .filter(\.isNavigable)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - Sorting

    static func sorted(
        _ items: [FileItem],
        by column: SortColumn,
        ascending: Bool,
        foldersFirst: Bool = true
    ) -> [FileItem] {
        items.sorted { lhs, rhs in
            // Explorer always floats folders above files, in either direction.
            if foldersFirst, lhs.isNavigable != rhs.isNavigable {
                return lhs.isNavigable
            }
            let result = compare(lhs, rhs, by: column)
            if result == .orderedSame {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    private static func compare(_ lhs: FileItem, _ rhs: FileItem, by column: SortColumn) -> ComparisonResult {
        switch column {
        case .name:
            // localizedStandardCompare gives Windows-style natural ordering:
            // "file2" sorts before "file10".
            return lhs.name.localizedStandardCompare(rhs.name)
        case .dateModified:
            return compareValues(lhs.dateModified, rhs.dateModified)
        case .type:
            let result = lhs.typeDescription.localizedStandardCompare(rhs.typeDescription)
            return result
        case .size:
            return compareValues(lhs.size, rhs.size)
        }
    }

    private static func compareValues<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    // MARK: - Grouping

    static func grouped(_ items: [FileItem], by kind: GroupKind, ascending: Bool) -> [ItemGroup] {
        guard kind != .none else {
            return [ItemGroup(id: "all", title: "", items: items)]
        }

        var order: [String] = []
        var buckets: [String: [FileItem]] = [:]

        for item in items {
            let key = groupTitle(for: item, kind: kind)
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(item)
        }

        // Date buckets carry their own chronological order; the rest sort by title.
        if kind != .dateModified {
            order.sort { $0.localizedStandardCompare($1) == .orderedAscending }
            if !ascending { order.reverse() }
        }

        return order.map { ItemGroup(id: $0, title: $0, items: buckets[$0] ?? []) }
    }

    static func groupTitle(for item: FileItem, kind: GroupKind) -> String {
        switch kind {
        case .none:
            return ""
        case .name:
            guard let first = item.name.first else { return "Other" }
            if first.isNumber { return "0 - 9" }
            guard first.isLetter else { return "Other" }
            return String(first).uppercased()
        case .type:
            return item.typeDescription
        case .size:
            if item.isNavigable { return "Unspecified" }
            let kb = Double(item.size) / 1024.0
            switch kb {
            case ..<1: return "Empty (0 KB)"
            case ..<10: return "Tiny (0 - 10 KB)"
            case ..<100: return "Small (10 - 100 KB)"
            case ..<1024: return "Medium (100 KB - 1 MB)"
            case ..<16384: return "Large (1 - 16 MB)"
            case ..<131072: return "Huge (16 - 128 MB)"
            default: return "Gigantic (>128 MB)"
            }
        case .dateModified:
            return dateBucket(item.dateModified)
        }
    }

    /// Explorer's relative date buckets, newest first.
    private static let dateBucketOrder = [
        "Today", "Yesterday", "Earlier this week", "Last week",
        "Earlier this month", "Earlier this year", "A long time ago"
    ]

    static func dateBucket(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        if let week = calendar.dateInterval(of: .weekOfYear, for: now), week.contains(date) {
            return "Earlier this week"
        }
        if let week = calendar.dateInterval(of: .weekOfYear, for: now),
           let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: week.start),
           let lastWeekInterval = calendar.dateInterval(of: .weekOfYear, for: lastWeek),
           lastWeekInterval.contains(date) {
            return "Last week"
        }
        if let month = calendar.dateInterval(of: .month, for: now), month.contains(date) {
            return "Earlier this month"
        }
        if let year = calendar.dateInterval(of: .year, for: now), year.contains(date) {
            return "Earlier this year"
        }
        return "A long time ago"
    }

    static func sortedDateGroups(_ groups: [ItemGroup]) -> [ItemGroup] {
        groups.sorted { lhs, rhs in
            let l = dateBucketOrder.firstIndex(of: lhs.title) ?? dateBucketOrder.count
            let r = dateBucketOrder.firstIndex(of: rhs.title) ?? dateBucketOrder.count
            return l < r
        }
    }

    // MARK: - Search

    /// Recursive name search, mirroring the search box in the address bar.
    /// Yields in batches so results stream in the way Explorer's do.
    static func search(
        in directory: URL,
        query: String,
        includeHidden: Bool,
        limit: Int = 2000,
        onBatch: @escaping ([FileItem]) -> Void,
        isCancelled: @escaping () -> Bool
    ) {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !includeHidden { options.insert(.skipsHiddenFiles) }

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: FileItem.resourceKeys,
            options: options
        ) else { return }

        var batch: [FileItem] = []
        var total = 0

        for case let url as URL in enumerator {
            if isCancelled() { return }
            guard url.lastPathComponent.localizedCaseInsensitiveContains(query) else { continue }
            guard let values = try? url.resourceValues(forKeys: Set(FileItem.resourceKeys)) else { continue }

            batch.append(FileItem(url: url, values: values))
            total += 1

            if batch.count >= 50 {
                let flushed = batch
                batch = []
                onBatch(flushed)
            }
            if total >= limit { break }
        }

        if !batch.isEmpty && !isCancelled() {
            onBatch(batch)
        }
    }
}

/// Answers "does this folder need a disclosure triangle?" without hitting the
/// disk on every row redraw.
enum DirectoryFacts {
    private static var cache: [URL: Bool] = [:]
    private static let lock = NSLock()

    static func hasSubdirectories(_ url: URL, includeHidden: Bool) -> Bool {
        lock.lock()
        if let cached = cache[url] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let result = FileSystemService.hasSubdirectories(url, includeHidden: includeHidden)

        lock.lock()
        cache[url] = result
        lock.unlock()
        return result
    }

    static func invalidate() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}
