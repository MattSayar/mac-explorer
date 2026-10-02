import Foundation

/// The eight layouts on Explorer's View tab.
enum LayoutMode: String, CaseIterable, Identifiable {
    case extraLargeIcons
    case largeIcons
    case mediumIcons
    case smallIcons
    case list
    case details
    case tiles
    case content

    var id: String { rawValue }

    var title: String {
        switch self {
        case .extraLargeIcons: return "Extra large icons"
        case .largeIcons: return "Large icons"
        case .mediumIcons: return "Medium icons"
        case .smallIcons: return "Small icons"
        case .list: return "List"
        case .details: return "Details"
        case .tiles: return "Tiles"
        case .content: return "Content"
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .extraLargeIcons: return 96
        case .largeIcons: return 64
        case .mediumIcons: return 48
        case .smallIcons: return 16
        case .list: return 16
        case .details: return 16
        case .tiles: return 48
        case .content: return 32
        }
    }

    var isGrid: Bool {
        switch self {
        case .extraLargeIcons, .largeIcons, .mediumIcons, .smallIcons, .tiles:
            return true
        default:
            return false
        }
    }
}

enum SortColumn: String, CaseIterable, Identifiable {
    case name
    case dateModified
    case type
    case size

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return "Name"
        case .dateModified: return "Date modified"
        case .type: return "Type"
        case .size: return "Size"
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .name: return 280
        case .dateModified: return 140
        case .type: return 120
        case .size: return 80
        }
    }

    var isTrailingAligned: Bool { self == .size }
}

enum GroupKind: String, CaseIterable, Identifiable {
    case none
    case name
    case dateModified
    case type
    case size

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "(None)"
        case .name: return "Name"
        case .dateModified: return "Date modified"
        case .type: return "Type"
        case .size: return "Size"
        }
    }
}

/// A materialized group of rows plus the header Explorer draws above them.
struct ItemGroup: Identifiable {
    let id: String
    let title: String
    let items: [FileItem]
}
