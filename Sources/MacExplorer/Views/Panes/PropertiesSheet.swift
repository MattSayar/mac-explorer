import AppKit
import SwiftUI

/// A stand-in for the Windows properties dialog, including the running folder
/// size calculation that dialog is known for.
struct PropertiesSheet: View {
    let items: [FileItem]
    let onClose: () -> Void

    @State private var calculatedSize: Int64?
    @State private var fileCount: Int = 0
    @State private var folderCount: Int = 0
    @State private var isCalculating = false
    @State private var token = SearchToken()

    private var single: FileItem? { items.count == 1 ? items.first : nil }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let single {
                        row("Type of file:", single.typeDescription)
                        row("Location:", single.url.deletingLastPathComponent().path)
                        row("Size:", sizeText)
                        if single.isNavigable {
                            row("Contains:", "\(fileCount) Files, \(folderCount) Folders")
                        }
                        divider
                        row("Created:", Format.listDate(single.dateCreated))
                        row("Modified:", Format.listDate(single.dateModified))
                        divider
                        row("Attributes:", attributeText(single))
                        row("Permissions:", permissionText(single))
                    } else {
                        row("Type of file:", "Multiple items")
                        row("Location:", items.first?.url.deletingLastPathComponent().path ?? "")
                        row("Size:", sizeText)
                        row("Contains:", "\(items.filter { !$0.isNavigable }.count) Files, \(items.filter(\.isNavigable).count) Folders")
                    }
                }
                .padding(.vertical, 10)
            }

            Divider()

            HStack {
                Spacer()
                Button("OK") { onClose() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(10)
        }
        .frame(width: 400, height: 420)
        .background(Win10.ribbonBackground)
        .onAppear(perform: calculate)
        .onDisappear { token.cancel() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            FileIcon(url: items.first?.url ?? KnownFolders.home, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Win10.font(13, weight: .semibold))
                    .lineLimit(2)
                Text(items.count == 1 ? (items.first?.typeDescription ?? "") : "\(items.count) items")
                    .font(Win10.small)
                    .foregroundColor(Win10.secondaryText)
            }
            Spacer()
        }
        .padding(14)
    }

    private var title: String {
        if let single { return single.name }
        return "\(items.count) items selected"
    }

    private var sizeText: String {
        guard let bytes = calculatedSize else {
            return isCalculating ? "Calculating…" : "—"
        }
        return "\(Format.explorerSize(bytes)) (\(Format.exactBytes(bytes)))"
    }

    private var divider: some View {
        Divider().padding(.vertical, 6).padding(.horizontal, 14)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(Win10.small)
                .foregroundColor(Win10.secondaryText)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(Win10.small)
                .foregroundColor(Win10.text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
    }

    private func attributeText(_ item: FileItem) -> String {
        var flags: [String] = []
        if item.isHidden { flags.append("Hidden") }
        if item.isSymbolicLink { flags.append("Symbolic link") }
        if item.isPackage { flags.append("Package") }
        if !FileManager.default.isWritableFile(atPath: item.url.path) { flags.append("Read-only") }
        return flags.isEmpty ? "Normal" : flags.joined(separator: ", ")
    }

    private func permissionText(_ item: FileItem) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: item.url.path),
              let permissions = attributes[.posixPermissions] as? NSNumber else {
            return "—"
        }
        return String(format: "%o", permissions.int16Value & 0o777)
    }

    /// Folder sizes are summed off the main thread and reported once, which is
    /// close enough to the dialog's live counter without thrashing the UI.
    private func calculate() {
        let targets = items
        let token = SearchToken()
        self.token = token
        isCalculating = true

        DispatchQueue.global(qos: .userInitiated).async {
            var total: Int64 = 0
            var files = 0
            var folders = 0

            for item in targets {
                if token.isCancelled { return }
                if item.isNavigable {
                    let enumerator = FileManager.default.enumerator(
                        at: item.url,
                        includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                        options: []
                    )
                    while let next = enumerator?.nextObject() as? URL {
                        if token.isCancelled { return }
                        let values = try? next.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                        if values?.isDirectory == true {
                            folders += 1
                        } else {
                            files += 1
                            total += Int64(values?.fileSize ?? 0)
                        }
                    }
                } else {
                    files += 1
                    total += item.size
                }
            }

            let result = (total, files, folders)
            DispatchQueue.main.async {
                guard !token.isCancelled else { return }
                calculatedSize = result.0
                fileCount = result.1
                folderCount = result.2
                isCalculating = false
            }
        }
    }
}
