import AppKit
import SwiftUI

struct AddressBar: View {
    @ObservedObject var model: ExplorerViewModel

    @State private var isEditingPath = false
    @State private var pathText = ""
    @FocusState private var pathFieldFocused: Bool
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 2) {
            navigationButtons

            addressField
                .frame(maxWidth: .infinity)

            searchField
                .frame(width: 190)
        }
        .padding(.horizontal, 4)
        .frame(height: Win10.addressBarHeight)
        .background(Win10.commandBar)
        .win10Divider(Win10.ribbonBorder)
    }

    // MARK: - Back / forward / up

    private var navigationButtons: some View {
        HStack(spacing: 0) {
            navButton("chevron.left", enabled: model.canGoBack, help: "Back") { model.goBack() }
            navButton("chevron.right", enabled: model.canGoForward, help: "Forward") { model.goForward() }

            Menu {
                ForEach(model.recentLocations, id: \.self) { url in
                    Button(KnownFolders.displayName(for: url)) { model.navigate(to: url) }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(model.canGoBack ? Win10.text : Win10.disabledText)
                    .frame(width: 16, height: 26)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(!model.canGoBack)
            .help("Recent locations")

            navButton("arrow.up", enabled: model.canGoUp, help: "Up to \(parentName)") { model.goUp() }
        }
    }

    private var parentName: String {
        model.parentURL.map { KnownFolders.displayName(for: $0) } ?? ""
    }

    private func navButton(
        _ symbol: String,
        enabled: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(enabled ? Win10.text : Win10.disabledText)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(Win10ButtonStyle(cornerRadius: 2, enabled: enabled))
        .disabled(!enabled)
        .help(help)
    }

    // MARK: - Address field

    private var addressField: some View {
        HStack(spacing: 0) {
            if isEditingPath {
                TextField("", text: $pathText)
                    .textFieldStyle(.plain)
                    .font(Win10.body)
                    .focused($pathFieldFocused)
                    .padding(.horizontal, 6)
                    .onSubmit(commitPath)
                    .onExitCommand { endEditing() }
            } else {
                breadcrumbs
            }

            Button {
                if isEditingPath { commitPath() } else { model.reload() }
            } label: {
                Image(systemName: isEditingPath ? "arrow.right" : "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Win10.secondaryText)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(Win10ButtonStyle(cornerRadius: 2))
            .help(isEditingPath ? "Go to location" : "Refresh")
        }
        .frame(height: 24)
        .background(Color.white)
        .overlay(
            Rectangle().stroke(
                pathFieldFocused ? Win10.fieldBorderFocused : Win10.fieldBorder,
                lineWidth: 1
            )
        )
    }

    private var breadcrumbs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    FileIcon(url: model.currentURL, size: 16)
                        .padding(.horizontal, 4)

                    ForEach(Array(crumbs.enumerated()), id: \.element) { index, url in
                        BreadcrumbSegment(
                            title: KnownFolders.displayName(for: url),
                            url: url,
                            isLast: index == crumbs.count - 1,
                            model: model
                        )
                        .id(url)
                    }

                    // Clicking the empty run of the bar switches to path editing,
                    // exactly like Explorer.
                    Color.clear
                        .frame(minWidth: 40)
                        .contentShape(Rectangle())
                        .onTapGesture { beginEditing() }
                }
                .frame(maxHeight: .infinity)
            }
            .onChange(of: model.currentURL) { _ in
                withAnimation(.none) { proxy.scrollTo(model.currentURL, anchor: .trailing) }
            }
        }
        .frame(height: 22)
    }

    private var crumbs: [URL] {
        var result: [URL] = []
        var url = model.currentURL
        while true {
            result.append(url)
            let parent = url.deletingLastPathComponent()
            if parent == url || url.path == "/" { break }
            url = parent
        }
        return result.reversed()
    }

    private func beginEditing() {
        pathText = model.currentURL.path
        isEditingPath = true
        pathFieldFocused = true
    }

    private func endEditing() {
        isEditingPath = false
        pathFieldFocused = false
    }

    private func commitPath() {
        let trimmed = pathText.trimmingCharacters(in: .whitespaces)
        endEditing()
        guard !trimmed.isEmpty else { return }

        let expanded = (trimmed as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        guard FileManager.default.fileExists(atPath: url.path) else {
            model.errorMessage = "File Explorer can't find '\(trimmed)'. Check the spelling and try again."
            return
        }
        model.navigate(to: url)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(Win10.secondaryText)
                .padding(.leading, 5)

            TextField("Search \(KnownFolders.displayName(for: model.currentURL))", text: $model.searchText)
                .textFieldStyle(.plain)
                .font(Win10.body)
                .focused($searchFocused)
                .onSubmit { model.runSearch() }
                .onExitCommand { model.clearSearch() }
                .onChange(of: model.searchText) { _ in model.scheduleSearch() }

            if model.isSearching {
                ProgressView()
                    .controlSize(.mini)
                    .padding(.trailing, 4)
            } else if !model.searchText.isEmpty {
                Button {
                    model.clearSearch()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Win10.secondaryText)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 3)
            }
        }
        .frame(height: 24)
        .background(Color.white)
        .overlay(
            Rectangle().stroke(
                searchFocused ? Win10.fieldBorderFocused : Win10.fieldBorder,
                lineWidth: 1
            )
        )
    }
}

/// One crumb plus the chevron that lists that folder's siblings.
private struct BreadcrumbSegment: View {
    let title: String
    let url: URL
    let isLast: Bool
    @ObservedObject var model: ExplorerViewModel

    var body: some View {
        HStack(spacing: 0) {
            Button {
                model.navigate(to: url)
            } label: {
                Text(title)
                    .font(Win10.body)
                    .foregroundColor(Win10.text)
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .frame(height: 20)
            }
            .buttonStyle(Win10ButtonStyle(cornerRadius: 1))

            Menu {
                let children = FileSystemService.subdirectories(of: url, includeHidden: model.showHiddenItems)
                if children.isEmpty {
                    Text("No subfolders")
                } else {
                    ForEach(children.prefix(50)) { child in
                        Button(child.name) { model.navigate(to: child.url) }
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Win10.secondaryText)
                    .frame(width: 14, height: 20)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
