import AppKit
import SwiftUI

struct ExplorerWindow: View {
    @StateObject private var model: ExplorerViewModel

    @State private var navigationWidth: CGFloat = 200
    @State private var sideWidth: CGFloat = 280
    @State private var hostWindow: NSWindow?

    init(startURL: URL? = nil) {
        _model = StateObject(
            wrappedValue: ExplorerViewModel(startingAt: startURL ?? KnownFolders.startupLocation)
        )
    }

    private var showsSidePane: Bool { model.showPreviewPane || model.showDetailsPane }

    var body: some View {
        VStack(spacing: 0) {
            RibbonView(model: model)
            AddressBar(model: model)

            HStack(spacing: 0) {
                if model.showNavigationPane {
                    NavigationPane(model: model)
                        .frame(width: navigationWidth)
                    Splitter { delta in
                        navigationWidth = min(420, max(140, navigationWidth + delta))
                    }
                }

                ContentPane(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showsSidePane {
                    Splitter { delta in
                        sideWidth = min(520, max(180, sideWidth - delta))
                    }
                    Group {
                        if model.showPreviewPane {
                            PreviewPane(model: model)
                        } else {
                            DetailsPane(model: model)
                        }
                    }
                    .frame(width: sideWidth)
                }
            }
            .frame(maxHeight: .infinity)

            StatusBarView(model: model)
        }
        .background(Win10.windowBackground)
        .preferredColorScheme(.light)
        .navigationTitle(model.title)
        .frame(minWidth: 760, minHeight: 460)
        .focusedSceneValue(\.explorerModel, model)
        .background(WindowAccessor { hostWindow = $0 })
        .modifier(ExplorerKeyboard(model: model, window: hostWindow))
        .alert(
            "File Explorer",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .sheet(
            isPresented: Binding(
                get: { model.propertiesTarget != nil },
                set: { if !$0 { model.propertiesTarget = nil } }
            )
        ) {
            PropertiesSheet(items: model.propertiesTarget ?? []) {
                model.propertiesTarget = nil
            }
        }
    }
}

/// The thin drag rule between panes.
private struct Splitter: View {
    let onDrag: (CGFloat) -> Void

    @State private var hovering = false

    var body: some View {
        Rectangle()
            .fill(Win10.ribbonBorder)
            .frame(width: 1)
            .overlay {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 7)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        hovering = inside
                        if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { onDrag($0.translation.width) }
                    )
            }
    }
}

/// Hands back the NSWindow hosting this view so key handling can be scoped to
/// it. The callback fires only when the window actually changes, otherwise
/// every redraw would write state and invalidate the view again.
struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onWindowChange = onResolve
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onWindowChange = onResolve
    }

    final class TrackingView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?
        private weak var lastWindow: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window !== lastWindow else { return }
            lastWindow = window
            let resolved = window
            DispatchQueue.main.async { [weak self] in
                self?.onWindowChange?(resolved)
            }
        }
    }
}

extension FocusedValues {
    var explorerModel: ExplorerViewModel? {
        get { self[ExplorerModelKey.self] }
        set { self[ExplorerModelKey.self] = newValue }
    }

    private struct ExplorerModelKey: FocusedValueKey {
        typealias Value = ExplorerViewModel
    }
}
