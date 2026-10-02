import AppKit
import Foundation

/// Explorer's navigation pane is a fixed set of sections, each holding roots
/// that expand into the real directory tree.
struct SidebarSection: Identifiable {
    let id: String
    let title: String
    var entries: [SidebarEntry]
    /// "Quick access" and friends can be collapsed as a whole.
    var isCollapsible: Bool = true
}

struct SidebarEntry: Identifiable, Hashable {
    let url: URL
    let title: String
    /// Roots such as "This Mac" are headers that expand but are not navigable.
    let isContainerOnly: Bool

    var id: URL { url }

    init(url: URL, title: String? = nil, isContainerOnly: Bool = false) {
        self.url = url
        self.title = title ?? url.lastPathComponent
        self.isContainerOnly = isContainerOnly
    }
}

enum KnownFolders {
    static let home = FileManager.default.homeDirectoryForCurrentUser

    static func url(for directory: FileManager.SearchPathDirectory) -> URL? {
        FileManager.default.urls(for: directory, in: .userDomainMask).first
    }

    static var desktop: URL? { url(for: .desktopDirectory) }
    static var documents: URL? { url(for: .documentDirectory) }
    static var downloads: URL? { url(for: .downloadsDirectory) }
    static var movies: URL? { url(for: .moviesDirectory) }
    static var music: URL? { url(for: .musicDirectory) }
    static var pictures: URL? { url(for: .picturesDirectory) }
    static var applications: URL { URL(fileURLWithPath: "/Applications") }

    /// Windows opens on "Quick access"; the closest honest equivalent is home.
    static var startupLocation: URL { home }

    /// Mounted volumes, minus the ones Explorer would never surface.
    static func volumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeIsBrowsableKey, .volumeLocalizedNameKey]
        let mounted = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []
        return mounted.filter { url in
            let values = try? url.resourceValues(forKeys: [.volumeIsBrowsableKey])
            return values?.volumeIsBrowsable ?? true
        }
    }

    static func volumeName(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.volumeLocalizedNameKey])
        return values?.volumeLocalizedName ?? url.lastPathComponent
    }

    /// The default "Quick access" pins, mapped onto the macOS home folder.
    static func defaultQuickAccess() -> [SidebarEntry] {
        var entries: [SidebarEntry] = []
        if let desktop { entries.append(SidebarEntry(url: desktop, title: "Desktop")) }
        if let downloads { entries.append(SidebarEntry(url: downloads, title: "Downloads")) }
        if let documents { entries.append(SidebarEntry(url: documents, title: "Documents")) }
        if let pictures { entries.append(SidebarEntry(url: pictures, title: "Pictures")) }
        return entries
    }

    /// "This PC" becomes "This Mac": the standard user folders, then volumes.
    static func thisMac() -> [SidebarEntry] {
        var entries: [SidebarEntry] = [SidebarEntry(url: home, title: "Home")]
        entries.append(SidebarEntry(url: applications, title: "Applications"))
        if let desktop { entries.append(SidebarEntry(url: desktop, title: "Desktop")) }
        if let documents { entries.append(SidebarEntry(url: documents, title: "Documents")) }
        if let downloads { entries.append(SidebarEntry(url: downloads, title: "Downloads")) }
        if let movies { entries.append(SidebarEntry(url: movies, title: "Movies")) }
        if let music { entries.append(SidebarEntry(url: music, title: "Music")) }
        if let pictures { entries.append(SidebarEntry(url: pictures, title: "Pictures")) }
        for volume in volumes() {
            entries.append(SidebarEntry(url: volume, title: volumeName(volume)))
        }
        return entries
    }

    static func network() -> [SidebarEntry] {
        let net = URL(fileURLWithPath: "/Volumes")
        return [SidebarEntry(url: net, title: "Volumes")]
    }

    /// Breadcrumb label for a path segment — known folders get friendly names.
    static func displayName(for url: URL) -> String {
        if url.path == "/" { return "Macintosh HD" }
        if url == home { return "Home" }
        let values = try? url.resourceValues(forKeys: [.localizedNameKey])
        return values?.localizedName ?? url.lastPathComponent
    }
}
