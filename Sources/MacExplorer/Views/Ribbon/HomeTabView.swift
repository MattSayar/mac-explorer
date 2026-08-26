import SwiftUI

struct HomeTabView: View {
    @ObservedObject var model: ExplorerViewModel
    @ObservedObject private var clipboard = ExplorerClipboard.shared

    private var hasSelection: Bool { !model.selection.isEmpty }
    private var singleSelection: Bool { model.selection.count == 1 }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {

            RibbonGroup(title: "Clipboard") {
                RibbonBigButton(
                    title: "Pin to Quick\naccess",
                    systemImage: "pin",
                    enabled: hasSelection,
                    width: 64
                ) {
                    model.pinToQuickAccess(Array(model.selection))
                }

                RibbonBigButton(title: "Copy", systemImage: "doc.on.doc", enabled: hasSelection) {
                    model.copySelection()
                }

                RibbonBigButton(title: "Paste", systemImage: "clipboard", enabled: clipboard.canPaste) {
                    model.paste()
                }

                VStack(spacing: 0) {
                    RibbonSmallButton(title: "Cut", systemImage: "scissors", enabled: hasSelection) {
                        model.cutSelection()
                    }
                    RibbonSmallButton(title: "Copy path", systemImage: "link") {
                        model.copyPath()
                    }
                    RibbonSmallButton(
                        title: "Paste shortcut",
                        systemImage: "arrow.turn.down.right",
                        enabled: clipboard.canPaste
                    ) {
                        model.pasteShortcut()
                    }
                }
                .frame(width: 108)
            }

            RibbonGroup(title: "Organize") {
                RibbonBigMenu(title: "Move\nto", systemImage: "arrow.right.doc.on.clipboard", enabled: hasSelection) {
                    destinationMenu { model.moveSelection(to: $0) }
                }
                RibbonBigMenu(title: "Copy\nto", systemImage: "doc.on.doc.fill", enabled: hasSelection) {
                    destinationMenu { model.copySelection(to: $0) }
                }
                RibbonBigButton(title: "Delete", systemImage: "trash", enabled: hasSelection) {
                    model.deleteSelection()
                }
                RibbonBigButton(title: "Rename", systemImage: "character.cursor.ibeam", enabled: singleSelection) {
                    model.beginRename()
                }
            }

            RibbonGroup(title: "New") {
                RibbonBigButton(title: "New\nfolder", systemImage: "folder.badge.plus") {
                    model.newFolder()
                }
                VStack(spacing: 0) {
                    RibbonSmallMenu(title: "New item", systemImage: "doc.badge.plus") {
                        Button("Text Document") { model.newFile(baseName: "New Text Document", extension: "txt") }
                        Button("Rich Text Document") { model.newFile(baseName: "New Rich Text Document", extension: "rtf") }
                        Button("Markdown Document") { model.newFile(baseName: "New Markdown Document", extension: "md") }
                        Divider()
                        Button("Folder") { model.newFolder() }
                    }
                    RibbonSmallMenu(title: "Easy access", systemImage: "star") {
                        Button("Pin to Quick access") {
                            model.pinToQuickAccess(model.selection.isEmpty ? [model.currentURL] : Array(model.selection))
                        }
                        Button("Reveal in Finder") { model.revealInFinder() }
                        Button("Open Terminal here") { FileOperations.openInTerminal(model.currentURL) }
                    }
                }
                .frame(width: 104)
            }

            RibbonGroup(title: "Open") {
                RibbonBigButton(title: "Properties", systemImage: "info.circle", width: 66) {
                    model.showProperties()
                }
                VStack(spacing: 0) {
                    RibbonSmallButton(title: "Open", systemImage: "arrow.up.forward.app", enabled: hasSelection) {
                        model.openSelection()
                    }
                    RibbonSmallMenu(title: "Open with", systemImage: "app.badge", enabled: singleSelection) {
                        openWithMenu
                    }
                    RibbonSmallMenu(title: "History", systemImage: "clock.arrow.circlepath", enabled: model.canGoBack) {
                        ForEach(model.recentLocations, id: \.self) { url in
                            Button(KnownFolders.displayName(for: url)) { model.navigate(to: url) }
                        }
                    }
                }
                .frame(width: 104)
            }

            RibbonGroup(title: "Select") {
                VStack(spacing: 0) {
                    RibbonSmallButton(title: "Select all", systemImage: "checkmark.square") {
                        model.selectAll()
                    }
                    RibbonSmallButton(title: "Select none", systemImage: "square") {
                        model.selectNone()
                    }
                    RibbonSmallButton(title: "Invert selection", systemImage: "arrow.triangle.2.circlepath") {
                        model.invertSelection()
                    }
                }
                .frame(width: 120)
            }
        }
    }

    /// Explorer offers recent folders plus Quick access pins as move/copy targets.
    @ViewBuilder
    private func destinationMenu(_ action: @escaping (URL) -> Void) -> some View {
        ForEach(model.quickAccess) { entry in
            Button(entry.title) { action(entry.url) }
        }
        if !model.recentLocations.isEmpty {
            Divider()
            ForEach(model.recentLocations, id: \.self) { url in
                Button(KnownFolders.displayName(for: url)) { action(url) }
            }
        }
        Divider()
        Button("Choose location…") { model.chooseDestination(action) }
    }

    @ViewBuilder
    private var openWithMenu: some View {
        if let url = model.selection.first {
            let apps = FileOperations.applications(openingURL: url)
            ForEach(apps.prefix(12), id: \.self) { app in
                Button(app.deletingPathExtension().lastPathComponent) {
                    FileOperations.open(Array(model.selection), withApplicationAt: app)
                }
            }
            if apps.isEmpty {
                Text("No applications available")
            }
        }
    }
}
