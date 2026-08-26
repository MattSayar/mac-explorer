import AppKit
import SwiftUI

@main
struct MacExplorerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "explorer", for: URL.self) { $url in
            ExplorerWindow(startURL: url)
        }
        .defaultSize(width: 1040, height: 640)
        .commands { ExplorerCommands() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Running from a bare binary rather than a bundle still gets a real UI.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Menu-bar equivalents of the ribbon commands, carrying the shortcuts that
/// macOS users expect for the Windows chords Explorer uses.
struct ExplorerCommands: Commands {
    @FocusedValue(\.explorerModel) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: "explorer", value: model?.currentURL ?? KnownFolders.startupLocation)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Folder") { model?.newFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(model == nil)

            Divider()

            Button("Open") { model?.openSelection() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(model?.selection.isEmpty ?? true)
        }

        CommandGroup(after: .newItem) {
            Divider()
            Button("Get Info") { model?.showProperties() }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(model == nil)
            Button("Reveal in Finder") { model?.revealInFinder() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(model == nil)
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Cut") { model?.cutSelection() }
                .keyboardShortcut("x", modifiers: .command)
                .disabled(model?.selection.isEmpty ?? true)
            Button("Copy") { model?.copySelection() }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(model?.selection.isEmpty ?? true)
            Button("Paste") { model?.paste() }
                .keyboardShortcut("v", modifiers: .command)
                .disabled(model == nil)
            Button("Copy Path") { model?.copyPath() }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(model == nil)

            Divider()

            Button("Rename") { model?.beginRename() }
                .disabled(model?.selection.count != 1)
            Button("Move to Trash") { model?.deleteSelection() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(model?.selection.isEmpty ?? true)

            Divider()

            Button("Select All") { model?.selectAll() }
                .keyboardShortcut("a", modifiers: .command)
                .disabled(model == nil)
            Button("Select None") { model?.selectNone() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(model == nil)
            Button("Invert Selection") { model?.invertSelection() }
                .disabled(model == nil)
        }

        CommandMenu("Go") {
            Button("Back") { model?.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!(model?.canGoBack ?? false))
            Button("Forward") { model?.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!(model?.canGoForward ?? false))
            Button("Up One Level") { model?.goUp() }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(!(model?.canGoUp ?? false))

            Divider()

            Button("Home") { model?.navigate(to: KnownFolders.home) }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            Button("Desktop") {
                if let desktop = KnownFolders.desktop { model?.navigate(to: desktop) }
            }
            Button("Documents") {
                if let documents = KnownFolders.documents { model?.navigate(to: documents) }
            }
            Button("Downloads") {
                if let downloads = KnownFolders.downloads { model?.navigate(to: downloads) }
            }
            Button("Applications") { model?.navigate(to: KnownFolders.applications) }

            Divider()

            Button("Refresh") { model?.reload() }
                .keyboardShortcut("r", modifiers: .command)
        }

        CommandMenu("View") {
            ForEach(Array(LayoutMode.allCases.enumerated()), id: \.element) { index, mode in
                Button(mode.title) { model?.layout = mode }
                    .keyboardShortcut(
                        KeyEquivalent(Character("\(index + 1)")),
                        modifiers: .command
                    )
            }

            Divider()

            Button("Navigation Pane") { model?.showNavigationPane.toggle() }
            Button("Preview Pane") { model?.showPreviewPane.toggle() }
                .keyboardShortcut("p", modifiers: [.command, .option])
            Button("Details Pane") { model?.showDetailsPane.toggle() }
                .keyboardShortcut("d", modifiers: [.command, .option])
            Button("Minimize Ribbon") { model?.ribbonExpanded.toggle() }

            Divider()

            Button("Show Hidden Items") { model?.showHiddenItems.toggle() }
                .keyboardShortcut(".", modifiers: [.command, .shift])
            Button("Show File Name Extensions") { model?.showFileExtensions.toggle() }
            Button("Show Item Check Boxes") { model?.showItemCheckBoxes.toggle() }
        }
    }
}
