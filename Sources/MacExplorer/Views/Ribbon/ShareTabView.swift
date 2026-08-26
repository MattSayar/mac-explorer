import AppKit
import SwiftUI

struct ShareTabView: View {
    @ObservedObject var model: ExplorerViewModel

    private var hasSelection: Bool { !model.selection.isEmpty }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {

            RibbonGroup(title: "Send") {
                RibbonBigButton(title: "Share", systemImage: "square.and.arrow.up", enabled: hasSelection) {
                    ShareSheet.present(urls: Array(model.selection))
                }
                RibbonBigButton(title: "Email", systemImage: "envelope", enabled: hasSelection) {
                    ShareSheet.email(urls: Array(model.selection))
                }
                RibbonBigButton(title: "Zip", systemImage: "doc.zipper", enabled: hasSelection) {
                    model.compressSelection()
                }
                RibbonBigButton(title: "Duplicate", systemImage: "plus.square.on.square", enabled: hasSelection) {
                    model.duplicateSelection()
                }
            }

            RibbonGroup(title: "Share with") {
                VStack(spacing: 0) {
                    RibbonSmallButton(title: "Reveal in Finder", systemImage: "magnifyingglass") {
                        model.revealInFinder()
                    }
                    RibbonSmallButton(title: "Open Terminal here", systemImage: "terminal") {
                        FileOperations.openInTerminal(model.currentURL)
                    }
                    RibbonSmallButton(title: "Copy path", systemImage: "link") {
                        model.copyPath()
                    }
                }
                .frame(width: 150)
            }

            RibbonGroup(title: "Advanced security") {
                VStack(spacing: 0) {
                    RibbonSmallButton(title: "Permissions", systemImage: "lock", enabled: hasSelection) {
                        model.showProperties()
                    }
                    RibbonSmallButton(
                        title: "Make alias",
                        systemImage: "arrow.turn.down.right",
                        enabled: hasSelection
                    ) {
                        model.copySelection()
                        model.pasteShortcut()
                    }
                }
                .frame(width: 130)
            }
        }
    }
}

/// Wraps NSSharingServicePicker, which needs a view to anchor its popover.
enum ShareSheet {
    static func present(urls: [URL]) {
        guard !urls.isEmpty, let window = NSApp.keyWindow, let anchor = window.contentView else { return }
        let picker = NSSharingServicePicker(items: urls)
        picker.show(
            relativeTo: NSRect(x: anchor.bounds.midX, y: anchor.bounds.maxY - 120, width: 1, height: 1),
            of: anchor,
            preferredEdge: .minY
        )
    }

    static func email(urls: [URL]) {
        guard !urls.isEmpty, let service = NSSharingService(named: .composeEmail) else { return }
        service.perform(withItems: urls)
    }
}
