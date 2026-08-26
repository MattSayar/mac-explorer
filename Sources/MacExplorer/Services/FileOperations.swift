import AppKit
import Foundation

enum FileOperationError: LocalizedError {
    case nameEmpty
    case nameContainsSeparator
    case alreadyExists(String)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .nameEmpty:
            return "You must type a file name."
        case .nameContainsSeparator:
            return "A file name can't contain any of the following characters: /  :"
        case .alreadyExists(let name):
            return "The destination already has a file named \"\(name)\"."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

enum FileOperations {

    // MARK: - Creating

    /// "New folder", then "New folder (2)", "New folder (3)"… exactly as Explorer names them.
    static func uniqueURL(in directory: URL, baseName: String, extension ext: String = "") -> URL {
        let suffix = ext.isEmpty ? "" : ".\(ext)"
        var candidate = directory.appendingPathComponent(baseName + suffix)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName) (\(counter))\(suffix)")
            counter += 1
        }
        return candidate
    }

    @discardableResult
    static func createFolder(in directory: URL, named name: String = "New folder") throws -> URL {
        let url = uniqueURL(in: directory, baseName: name)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            return url
        } catch {
            throw FileOperationError.underlying(error)
        }
    }

    @discardableResult
    static func createFile(in directory: URL, baseName: String, extension ext: String) throws -> URL {
        let url = uniqueURL(in: directory, baseName: baseName, extension: ext)
        guard FileManager.default.createFile(atPath: url.path, contents: Data()) else {
            throw FileOperationError.underlying(
                NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
            )
        }
        return url
    }

    // MARK: - Renaming

    @discardableResult
    static func rename(_ url: URL, to newName: String) throws -> URL {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FileOperationError.nameEmpty }
        guard !trimmed.contains("/"), !trimmed.contains(":") else {
            throw FileOperationError.nameContainsSeparator
        }

        let destination = url.deletingLastPathComponent().appendingPathComponent(trimmed)
        guard destination != url else { return url }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw FileOperationError.alreadyExists(trimmed)
        }

        do {
            try FileManager.default.moveItem(at: url, to: destination)
            IconProvider.shared.invalidate(url)
            return destination
        } catch {
            throw FileOperationError.underlying(error)
        }
    }

    // MARK: - Deleting

    /// Delete routes through the Trash, the analogue of Explorer's Recycle Bin.
    static func moveToTrash(_ urls: [URL]) throws {
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                IconProvider.shared.invalidate(url)
            } catch {
                throw FileOperationError.underlying(error)
            }
        }
    }

    /// Shift+Delete in Explorer: permanent, no Recycle Bin.
    static func deletePermanently(_ urls: [URL]) throws {
        for url in urls {
            do {
                try FileManager.default.removeItem(at: url)
                IconProvider.shared.invalidate(url)
            } catch {
                throw FileOperationError.underlying(error)
            }
        }
    }

    // MARK: - Copy / move

    /// Windows appends " - Copy" on a same-folder paste, then " - Copy (2)".
    static func copyDestination(for source: URL, in directory: URL) -> URL {
        let plain = directory.appendingPathComponent(source.lastPathComponent)
        guard FileManager.default.fileExists(atPath: plain.path) else { return plain }

        let ext = source.pathExtension
        let stem = ext.isEmpty
            ? source.lastPathComponent
            : String(source.lastPathComponent.dropLast(ext.count + 1))
        let suffix = ext.isEmpty ? "" : ".\(ext)"

        var candidate = directory.appendingPathComponent("\(stem) - Copy\(suffix)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(stem) - Copy (\(counter))\(suffix)")
            counter += 1
        }
        return candidate
    }

    @discardableResult
    static func copy(_ urls: [URL], to directory: URL) throws -> [URL] {
        var created: [URL] = []
        for url in urls {
            let destination = copyDestination(for: url, in: directory)
            do {
                try FileManager.default.copyItem(at: url, to: destination)
                created.append(destination)
            } catch {
                throw FileOperationError.underlying(error)
            }
        }
        return created
    }

    @discardableResult
    static func move(_ urls: [URL], to directory: URL) throws -> [URL] {
        var moved: [URL] = []
        for url in urls {
            // Moving onto itself is a no-op, not an error.
            guard url.deletingLastPathComponent() != directory else {
                moved.append(url)
                continue
            }
            let destination = copyDestination(for: url, in: directory)
            do {
                try FileManager.default.moveItem(at: url, to: destination)
                IconProvider.shared.invalidate(url)
                moved.append(destination)
            } catch {
                throw FileOperationError.underlying(error)
            }
        }
        return moved
    }

    // MARK: - Opening

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func open(_ urls: [URL]) {
        urls.forEach(open)
    }

    static func revealInFinder(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    static func openInTerminal(_ url: URL) {
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: terminal,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    static func applications(openingURL url: URL) -> [URL] {
        NSWorkspace.shared.urlsForApplications(toOpen: url)
    }

    static func open(_ urls: [URL], withApplicationAt app: URL) {
        NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
}

/// Explorer's clipboard: the system pasteboard carries the URLs so copy/paste
/// interoperates with Finder, while the cut flag stays local to this app.
final class ExplorerClipboard: ObservableObject {
    static let shared = ExplorerClipboard()

    @Published private(set) var cutURLs: Set<URL> = []
    private var changeCountAtCut: Int = -1

    private init() {}

    var pasteboardURLs: [URL] {
        let pasteboard = NSPasteboard.general
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        return objects ?? []
    }

    var canPaste: Bool { !pasteboardURLs.isEmpty }

    func copy(_ urls: [URL]) {
        write(urls)
        cutURLs = []
        changeCountAtCut = -1
    }

    func cut(_ urls: [URL]) {
        write(urls)
        cutURLs = Set(urls)
        changeCountAtCut = NSPasteboard.general.changeCount
    }

    private func write(_ urls: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }

    /// A cut is only pending while our own write is still on the pasteboard.
    var isCutPending: Bool {
        !cutURLs.isEmpty && NSPasteboard.general.changeCount == changeCountAtCut
    }

    func isCut(_ url: URL) -> Bool {
        isCutPending && cutURLs.contains(url)
    }

    func clearCut() {
        cutURLs = []
        changeCountAtCut = -1
    }

    /// Performs the paste and reports which URLs landed, so the caller can select them.
    @discardableResult
    func paste(into directory: URL) throws -> [URL] {
        let urls = pasteboardURLs
        guard !urls.isEmpty else { return [] }

        if isCutPending {
            let moved = try FileOperations.move(urls, to: directory)
            clearCut()
            NSPasteboard.general.clearContents()
            return moved
        }
        return try FileOperations.copy(urls, to: directory)
    }
}

extension FileOperations {
    /// ditto is what Finder's own "Compress" uses; it preserves metadata that
    /// a naive zip would drop.
    static func compress(_ urls: [URL], to archive: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")

        var arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent"]
        if urls.count == 1 {
            arguments.append(urls[0].path)
        } else {
            // ditto archives a single source, so multiple items go through a
            // staging folder that becomes the archive root.
            let staging = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("MacExplorer-\(UUID().uuidString)")
                .appendingPathComponent(archive.deletingPathExtension().lastPathComponent)
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: staging.deletingLastPathComponent()) }

            for url in urls {
                try FileManager.default.copyItem(
                    at: url,
                    to: staging.appendingPathComponent(url.lastPathComponent)
                )
            }
            arguments.append(staging.path)
            arguments.append(archive.path)
            try run(process, arguments: arguments)
            return
        }
        arguments.append(archive.path)
        try run(process, arguments: arguments)
    }

    private static func run(_ process: Process, arguments: [String]) throws {
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw FileOperationError.underlying(error)
        }
        guard process.terminationStatus == 0 else {
            throw FileOperationError.underlying(
                NSError(
                    domain: "MacExplorer",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "The items could not be compressed."]
                )
            )
        }
    }
}
