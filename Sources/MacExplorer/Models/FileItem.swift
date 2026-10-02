import Foundation
import UniformTypeIdentifiers

/// One row in the file list. Built once per directory read from a single
/// batch of resource values so scrolling never touches the disk.
struct FileItem: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let isPackage: Bool
    let isHidden: Bool
    let isSymbolicLink: Bool
    let size: Int64
    let dateModified: Date
    let dateCreated: Date
    let typeDescription: String
    let contentType: UTType?

    var id: URL { url }

    static let resourceKeys: [URLResourceKey] = [
        .localizedNameKey,
        .nameKey,
        .isDirectoryKey,
        .isPackageKey,
        .isHiddenKey,
        .isSymbolicLinkKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .creationDateKey,
        .localizedTypeDescriptionKey,
        .contentTypeKey
    ]

    init(url: URL, values: URLResourceValues) {
        self.url = url
        self.name = values.localizedName ?? values.name ?? url.lastPathComponent
        self.isDirectory = values.isDirectory ?? false
        self.isPackage = values.isPackage ?? false
        self.isHidden = values.isHidden ?? url.lastPathComponent.hasPrefix(".")
        self.isSymbolicLink = values.isSymbolicLink ?? false
        self.size = Int64(values.fileSize ?? 0)
        self.dateModified = values.contentModificationDate ?? .distantPast
        self.dateCreated = values.creationDate ?? values.contentModificationDate ?? .distantPast
        self.contentType = values.contentType

        if let described = values.localizedTypeDescription {
            self.typeDescription = described
        } else if self.isDirectory {
            self.typeDescription = "File folder"
        } else {
            let ext = url.pathExtension
            self.typeDescription = ext.isEmpty ? "File" : "\(ext.uppercased()) File"
        }
    }

    /// Bundles (.app, .rtfd) are directories on disk but behave like documents.
    var isNavigable: Bool { isDirectory && !isPackage }

    /// Explorer leaves the size column blank for folders.
    var sizeText: String { isDirectory && !isPackage ? "" : Format.explorerSize(size) }

    var fileExtension: String { url.pathExtension }

    /// Name with the extension stripped, for the "hide file name extensions" option.
    var stem: String {
        let ext = url.pathExtension
        guard !ext.isEmpty, name.hasSuffix("." + ext) else { return name }
        return String(name.dropLast(ext.count + 1))
    }

    func displayName(showExtensions: Bool) -> String {
        (showExtensions || isDirectory) ? name : stem
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}
