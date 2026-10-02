import Foundation

enum Format {

    /// Explorer reports sizes in whole KB for anything under a megabyte,
    /// with a thousands separator — "12 KB", "1,004 KB", "3.4 MB".
    static func explorerSize(_ bytes: Int64) -> String {
        if bytes <= 0 { return "0 KB" }
        let kb = Double(bytes) / 1024.0
        if kb < 1024 {
            let rounded = max(1, Int(kb.rounded(.up)))
            return "\(grouped(Int64(rounded))) KB"
        }
        let mb = kb / 1024.0
        if mb < 1024 {
            return String(format: "%.1f MB", mb)
        }
        let gb = mb / 1024.0
        if gb < 1024 {
            return String(format: "%.1f GB", gb)
        }
        return String(format: "%.1f TB", gb / 1024.0)
    }

    /// Precise byte count used in the details pane and properties sheet.
    static func exactBytes(_ bytes: Int64) -> String {
        "\(grouped(bytes)) bytes"
    }

    static func grouped(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    /// "8/26/2026 5:12 PM" — Explorer's date column.
    static func listDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func itemCount(_ count: Int) -> String {
        count == 1 ? "1 item" : "\(grouped(Int64(count))) items"
    }
}
