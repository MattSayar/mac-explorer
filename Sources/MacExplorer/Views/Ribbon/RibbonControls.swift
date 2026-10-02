import SwiftUI

/// One labelled cluster of ribbon commands, closed by a vertical rule and its
/// caption — the fundamental unit of the Windows ribbon.
struct RibbonGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 2) {
                content()
            }
            .padding(.horizontal, 6)
            .frame(maxHeight: .infinity)

            Text(title)
                .font(Win10.caption)
                .foregroundColor(Win10.secondaryText)
                .padding(.bottom, 3)
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .trailing) {
            Win10.groupSeparator
                .frame(width: 1)
                .padding(.vertical, 3)
        }
    }
}

/// The tall command: 32pt glyph stacked over a two-line label.
struct RibbonBigButton: View {
    let title: String
    let systemImage: String
    var enabled: Bool = true
    var width: CGFloat = 62
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .light))
                    .frame(height: 30)
                Text(title)
                    .font(Win10.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundColor(enabled ? Win10.text : Win10.disabledText)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .padding(.top, 4)
        }
        .buttonStyle(Win10ButtonStyle(enabled: enabled))
        .disabled(!enabled)
    }
}

/// A tall command that drops a menu instead of firing immediately.
struct RibbonBigMenu<Content: View>: View {
    let title: String
    let systemImage: String
    var enabled: Bool = true
    var width: CGFloat = 62
    @ViewBuilder var menu: () -> Content

    var body: some View {
        Menu {
            menu()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .light))
                    .frame(height: 30)
                Text(title)
                    .font(Win10.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                Spacer(minLength: 0)
            }
            .foregroundColor(enabled ? Win10.text : Win10.disabledText)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .padding(.top, 4)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(!enabled)
    }
}

/// The short command used in stacked columns beside the tall ones.
struct RibbonSmallButton: View {
    let title: String
    let systemImage: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .light))
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(Win10.small)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundColor(enabled ? Win10.text : Win10.disabledText)
            .padding(.horizontal, 4)
            .frame(height: 22)
        }
        .buttonStyle(Win10ButtonStyle(enabled: enabled))
        .disabled(!enabled)
    }
}

struct RibbonSmallMenu<Content: View>: View {
    let title: String
    let systemImage: String
    var enabled: Bool = true
    @ViewBuilder var menu: () -> Content

    var body: some View {
        Menu {
            menu()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .light))
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(Win10.small)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                Spacer(minLength: 0)
            }
            .foregroundColor(enabled ? Win10.text : Win10.disabledText)
            .padding(.horizontal, 4)
            .frame(height: 22)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(!enabled)
    }
}

/// Win10's square checkbox, used by the View tab's Show/hide group.
struct RibbonCheckBox: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white)
                        .frame(width: 13, height: 13)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(isOn ? Win10.accent : Win10.fieldBorder, lineWidth: 1)
                        )
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Win10.accent)
                    }
                }
                Text(title)
                    .font(Win10.small)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundColor(Win10.text)
            .padding(.horizontal, 4)
            .frame(height: 22)
        }
        .buttonStyle(Win10ButtonStyle())
    }
}

/// A layout entry in the View tab's gallery; the active one stays highlighted.
struct RibbonLayoutItem: View {
    let mode: LayoutMode
    let isSelected: Bool
    let action: () -> Void

    private var glyph: String {
        switch mode {
        case .extraLargeIcons, .largeIcons: return "square.grid.2x2"
        case .mediumIcons: return "square.grid.3x2"
        case .smallIcons: return "square.grid.4x3.fill"
        case .list: return "list.bullet"
        case .details: return "list.dash"
        case .tiles: return "rectangle.grid.1x2"
        case .content: return "rectangle.grid.1x2.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: glyph)
                    .font(.system(size: 11))
                    .frame(width: 16)
                Text(mode.title)
                    .font(Win10.small)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundColor(Win10.text)
            .padding(.horizontal, 5)
            .frame(width: 118, height: 21)
            .background(isSelected ? Win10.selectionFill : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? Win10.selectionBorder : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(Win10ButtonStyle())
    }
}

/// A menu row that carries a checkmark when active, the way the Sort by and
/// Group by menus mark the current choice.
struct MenuCheckItem: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isOn {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}
