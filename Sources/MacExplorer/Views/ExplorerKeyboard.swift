import AppKit
import SwiftUI

/// Explorer's non-menu keys — arrows, Enter, F2, Delete, Escape and
/// type-ahead selection — routed through a local event monitor scoped to
/// this window.
struct ExplorerKeyboard: ViewModifier {
    @ObservedObject var model: ExplorerViewModel
    let window: NSWindow?

    @State private var monitor: Any?
    @State private var typeAhead = TypeAheadBuffer()

    func body(content: Content) -> some View {
        content
            .onAppear { install() }
            .onDisappear { remove() }
            .onChange(of: window) { _ in
                remove()
                install()
            }
    }

    private func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event) ? nil : event
        }
    }

    private func remove() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    /// Returns true when the key was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        // Only the window this view lives in, and never while typing in a field.
        guard let window, event.window === window else { return false }
        if window.firstResponder is NSTextView { return false }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shift = flags.contains(.shift)
        let command = flags.contains(.command)

        switch event.keyCode {
        case 36, 76: // Return, Enter
            model.openSelection()
            return true
        case 51: // Delete
            model.deleteSelection(permanently: shift)
            return true
        case 53: // Escape
            if model.renamingURL != nil {
                model.cancelRename()
            } else if model.isSearchActive {
                model.clearSearch()
            } else {
                model.selectNone()
            }
            return true
        case 120: // F2
            model.beginRename()
            return true
        case 116: // Page Up
            model.moveSelection(by: -12, extending: shift)
            return true
        case 121: // Page Down
            model.moveSelection(by: 12, extending: shift)
            return true
        case 115: // Home
            model.moveSelection(by: -model.flatItems.count, extending: shift)
            return true
        case 119: // End
            model.moveSelection(by: model.flatItems.count, extending: shift)
            return true
        case 126: // Up arrow
            if command {
                model.goUp()
            } else {
                model.moveSelection(by: -1, extending: shift)
            }
            return true
        case 125: // Down arrow
            if command {
                model.openSelection()
            } else {
                model.moveSelection(by: 1, extending: shift)
            }
            return true
        case 123: // Left arrow
            if command {
                model.goBack()
            } else {
                model.moveSelection(by: -1, extending: shift)
            }
            return true
        case 124: // Right arrow
            if command {
                model.goForward()
            } else {
                model.moveSelection(by: 1, extending: shift)
            }
            return true
        default:
            break
        }

        // Type-ahead: plain letters jump to the next matching name.
        guard !command, !flags.contains(.control), !flags.contains(.option),
              let characters = event.charactersIgnoringModifiers,
              let first = characters.first,
              first.isLetter || first.isNumber || first == "." || first == "_"
        else { return false }

        let prefix = typeAhead.append(characters)
        if let match = model.flatItems.first(where: {
            $0.name.lowercased().hasPrefix(prefix.lowercased())
        }) {
            model.select(match, extending: false, toggling: false)
        }
        return true
    }
}

/// Accumulates keystrokes for a second, the way Explorer's type-ahead does.
final class TypeAheadBuffer {
    private var buffer = ""
    private var lastKeystroke = Date.distantPast

    func append(_ characters: String) -> String {
        let now = Date()
        if now.timeIntervalSince(lastKeystroke) > 1.0 {
            buffer = ""
        }
        lastKeystroke = now
        buffer += characters
        return buffer
    }
}
