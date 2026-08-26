import AppKit
import Quartz
import SwiftUI

/// The Preview pane, backed by Quick Look so it renders whatever macOS can.
struct PreviewPane: View {
    @ObservedObject var model: ExplorerViewModel

    private var target: FileItem? {
        let selected = model.selectedItems
        return selected.count == 1 ? selected.first : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if let target {
                QuickLookPreview(url: target.url)
                    .id(target.url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                Text(target.displayName(showExtensions: model.showFileExtensions))
                    .font(Win10.small)
                    .foregroundColor(Win10.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(6)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundColor(Win10.disabledText)
                    Text(model.selection.count > 1
                         ? "Select a single file to preview."
                         : "Select a file to preview.")
                        .font(Win10.small)
                        .foregroundColor(Win10.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.white)
        .win10Divider(Win10.ribbonBorder, edge: .leading)
    }
}

private struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .compact) ?? QLPreviewView()
        view.autostarts = true
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        if nsView.previewItem?.previewItemURL != url {
            nsView.previewItem = url as NSURL
        }
    }

    static func dismantleNSView(_ nsView: QLPreviewView, coordinator: ()) {
        nsView.close()
    }
}
