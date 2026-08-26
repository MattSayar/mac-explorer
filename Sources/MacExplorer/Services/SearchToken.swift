import Foundation

/// A cancellation flag shared with the background search, replacing the
/// structured-concurrency cancellation that a detached task would not inherit.
final class SearchToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}
