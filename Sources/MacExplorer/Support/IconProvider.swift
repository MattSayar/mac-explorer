import AppKit
import SwiftUI

/// System icons are expensive to fetch per row, so they are cached by
/// path + rendered size and reused across every view mode.
final class IconProvider {
    static let shared = IconProvider()

    private let cache = NSCache<NSString, NSImage>()
    private let workspace = NSWorkspace.shared

    private init() {
        cache.countLimit = 2048
    }

    func icon(for url: URL, size: CGFloat) -> NSImage {
        let key = "\(url.path)|\(Int(size))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let icon = workspace.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        cache.setObject(icon, forKey: key)
        return icon
    }

    /// Drops cached icons for a path whose contents may have changed.
    func invalidate(_ url: URL) {
        for size in [16, 24, 32, 48, 64, 96, 256] {
            cache.removeObject(forKey: "\(url.path)|\(size)" as NSString)
        }
    }

    func invalidateAll() {
        cache.removeAllObjects()
    }
}

struct FileIcon: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        Image(nsImage: IconProvider.shared.icon(for: url, size: size))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}
