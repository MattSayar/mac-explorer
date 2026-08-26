import Foundation

/// Watches one directory for changes so the list refreshes itself the way
/// Explorer's does when something writes into the current folder.
final class FolderWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private let queue = DispatchQueue(label: "com.mattsayar.macexplorer.folderwatcher")
    private var pendingWork: DispatchWorkItem?

    var onChange: (() -> Void)?

    func watch(_ url: URL) {
        stop()

        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .extend],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.scheduleChange()
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.descriptor >= 0 else { return }
            close(self.descriptor)
            self.descriptor = -1
        }

        source.resume()
        self.source = source
    }

    /// Bursts of writes (a copy of many files) collapse into one refresh.
    private func scheduleChange() {
        pendingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async { self.onChange?() }
        }
        pendingWork = work
        queue.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func stop() {
        pendingWork?.cancel()
        pendingWork = nil
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
