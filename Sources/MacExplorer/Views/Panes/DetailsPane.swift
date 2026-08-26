import SwiftUI

/// The Details pane: a large icon over the same attributes Explorer lists.
struct DetailsPane: View {
    @ObservedObject var model: ExplorerViewModel

    private var selected: [FileItem] { model.selectedItems }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if selected.count == 1, let item = selected.first {
                    single(item)
                } else if selected.isEmpty {
                    folderSummary
                } else {
                    multiple
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .win10Divider(Win10.ribbonBorder, edge: .leading)
    }

    private func single(_ item: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                FileIcon(url: item.url, size: 64)
                Spacer()
            }

            Text(item.displayName(showExtensions: model.showFileExtensions))
                .font(Win10.font(13, weight: .semibold))
                .foregroundColor(Win10.text)
                .lineLimit(3)

            Text(item.typeDescription)
                .font(Win10.small)
                .foregroundColor(Win10.secondaryText)

            Divider()

            attribute("Date modified", Format.listDate(item.dateModified))
            attribute("Date created", Format.listDate(item.dateCreated))
            if !item.isNavigable {
                attribute("Size", Format.explorerSize(item.size))
            }
            attribute("Where", item.url.deletingLastPathComponent().path)
            if item.isSymbolicLink {
                attribute("Target", (try? FileManager.default.destinationOfSymbolicLink(atPath: item.url.path)) ?? "—")
            }
        }
    }

    private var multiple: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 42, weight: .thin))
                    .foregroundColor(Win10.accent)
                Spacer()
            }
            Text("\(selected.count) items selected")
                .font(Win10.font(13, weight: .semibold))
            Divider()
            attribute("Files", "\(selected.filter { !$0.isNavigable }.count)")
            attribute("Folders", "\(selected.filter(\.isNavigable).count)")
            attribute(
                "Size",
                Format.explorerSize(selected.reduce(Int64(0)) { $0 + ($1.isNavigable ? 0 : $1.size) })
            )
        }
    }

    private var folderSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                FileIcon(url: model.currentURL, size: 64)
                Spacer()
            }
            Text(KnownFolders.displayName(for: model.currentURL))
                .font(Win10.font(13, weight: .semibold))
            Text("File folder")
                .font(Win10.small)
                .foregroundColor(Win10.secondaryText)
            Divider()
            attribute("Items", "\(model.flatItems.count)")
            attribute("Where", model.currentURL.deletingLastPathComponent().path)
        }
    }

    private func attribute(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(Win10.caption)
                .foregroundColor(Win10.secondaryText)
            Text(value)
                .font(Win10.small)
                .foregroundColor(Win10.text)
                .textSelection(.enabled)
                .lineLimit(3)
                .truncationMode(.middle)
        }
    }
}
