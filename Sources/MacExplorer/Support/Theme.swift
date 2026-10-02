import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

/// Colors, fonts and metrics lifted from the Windows 10 (1909) File Explorer chrome.
enum Win10 {

    // MARK: Chrome

    static let windowBackground = Color(hex: 0xFFFFFF)
    static let ribbonBackground = Color(hex: 0xF2F2F2)
    static let ribbonTabStrip = Color(hex: 0xE6E6E6)
    static let ribbonBorder = Color(hex: 0xD4D4D4)
    static let separator = Color(hex: 0xE5E5E5)
    static let groupSeparator = Color(hex: 0xDCDCDC)
    static let commandBar = Color(hex: 0xF9F9F9)
    static let statusBar = Color(hex: 0xF0F0F0)
    static let navigationPane = Color(hex: 0xFFFFFF)

    // MARK: Accents

    static let accent = Color(hex: 0x0078D7)
    static let fileTabBlue = Color(hex: 0x0072C6)
    static let fileTabBlueHover = Color(hex: 0x1A82CE)

    // MARK: Item states

    /// Selected row fill in an unfocused-agnostic Explorer list.
    static let selectionFill = Color(hex: 0xCCE8FF)
    static let selectionBorder = Color(hex: 0x99D1FF)
    static let hoverFill = Color(hex: 0xE5F3FF)
    static let hoverBorder = Color(hex: 0xCCE8FF)
    static let selectedHoverFill = Color(hex: 0xBEE0FA)
    static let selectedHoverBorder = Color(hex: 0x8DC8F0)

    // MARK: Text

    static let text = Color(hex: 0x000000)
    static let secondaryText = Color(hex: 0x646464)
    static let headerText = Color(hex: 0x1F1F1F)
    static let groupHeaderText = Color(hex: 0x0072C6)
    static let disabledText = Color(hex: 0xA0A0A0)

    // MARK: Controls

    static let controlHover = Color(hex: 0xE5F1FB)
    static let controlHoverBorder = Color(hex: 0xCCE4F7)
    static let controlPressed = Color(hex: 0xCCE4F7)
    static let controlPressedBorder = Color(hex: 0xACD3F0)
    static let fieldBorder = Color(hex: 0xABABAB)
    static let fieldBorderHover = Color(hex: 0x7EB4EA)
    static let fieldBorderFocused = Color(hex: 0x0078D7)
    static let columnHeaderHover = Color(hex: 0xF0F0F0)
    static let columnHeaderPressed = Color(hex: 0xE0E0E0)

    // MARK: Typography

    /// Windows uses Segoe UI 9pt. Fall back to the system face when Segoe is absent,
    /// which it is on a stock macOS install.
    static let uiFontName: String? = {
        let candidates = ["Segoe UI", "Selawik"]
        let available = Set(NSFontManager.shared.availableFontFamilies)
        return candidates.first(where: { available.contains($0) })
    }()

    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = uiFontName {
            return .custom(name, fixedSize: size).weight(weight)
        }
        return .system(size: size, weight: weight)
    }

    static let body = font(12)
    static let small = font(11)
    static let caption = font(10.5)

    // MARK: Metrics

    static let ribbonTabHeight: CGFloat = 25
    static let ribbonBodyHeight: CGFloat = 94
    static let addressBarHeight: CGFloat = 32
    static let columnHeaderHeight: CGFloat = 24
    static let detailsRowHeight: CGFloat = 22
    static let statusBarHeight: CGFloat = 24
    static let sidebarRowHeight: CGFloat = 22
    static let sidebarIndent: CGFloat = 16
}

/// A borderless rectangle that lights up on hover/press the way Win10 command
/// buttons do, without any of AppKit's own button chrome.
struct Win10ButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 0
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        Surface(configuration: configuration, cornerRadius: cornerRadius, enabled: enabled)
    }

    // A nested view gives the hover state somewhere to live; @State is not
    // usable directly inside a ButtonStyle.
    private struct Surface: View {
        let configuration: Configuration
        let cornerRadius: CGFloat
        let enabled: Bool
        @State private var hovering = false

        var body: some View {
            let pressed = configuration.isPressed && enabled
            let hot = hovering && enabled

            let fill: Color = pressed
                ? Win10.controlPressed
                : (hot ? Win10.controlHover : .clear)
            let border: Color = pressed
                ? Win10.controlPressedBorder
                : (hot ? Win10.controlHoverBorder : .clear)

            configuration.label
                .opacity(enabled ? 1 : 0.4)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(fill)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(border, lineWidth: 1)
                        )
                )
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}

extension View {
    /// Hairline that stays one physical pixel regardless of backing scale.
    func win10Divider(_ color: Color = Win10.separator, edge: Edge = .bottom) -> some View {
        overlay(alignment: edge == .bottom ? .bottom : (edge == .top ? .top : (edge == .leading ? .leading : .trailing))) {
            Group {
                if edge == .leading || edge == .trailing {
                    color.frame(width: 1)
                } else {
                    color.frame(height: 1)
                }
            }
        }
    }
}
