import Foundation

/// Calls back on the main queue whenever a file in the directory is added, replaced or removed.
/// The hook writes atomically (write + rename), which always touches the directory itself.
final class DirectoryWatcher {
    private let source: DispatchSourceFileSystemObject

    init?(_ directory: URL, onChange: @escaping () -> Void) {
        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return nil }
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler(handler: onChange)
        source.setCancelHandler { close(fd) }
        source.resume()
    }

    deinit {
        source.cancel()
    }
}
