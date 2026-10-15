import Foundation

/// Something the user sent to a session from ClaudeCat.
public enum InboxItem: Codable, Equatable, Sendable {
    case message(String)
    case stop
}

/// One pending item per session, left by the app and picked up by that session's hooks.
public struct Inbox: Sendable {
    public static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude-cat/inbox", isDirectory: true)

    public let directory: URL

    public init(directory: URL = Inbox.defaultDirectory) {
        self.directory = directory
    }

    public func post(_ item: InboxItem, to id: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(item) else { return }
        try? data.write(to: file(id), options: .atomic)
    }

    public func peek(_ id: String) -> InboxItem? {
        (try? Data(contentsOf: file(id))).flatMap { try? JSONDecoder().decode(InboxItem.self, from: $0) }
    }

    public func remove(_ id: String) {
        try? FileManager.default.removeItem(at: file(id))
    }

    private func file(_ id: String) -> URL {
        directory.appendingPathComponent("\(id).json")
    }
}

/// Which finished sessions have a live reply listener, recorded as pid files.
public struct ListenerRegistry: Sendable {
    public static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude-cat/listeners", isDirectory: true)

    public let directory: URL

    public init(directory: URL = ListenerRegistry.defaultDirectory) {
        self.directory = directory
    }

    public func register(_ id: String, pid: Int32) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? Data(String(pid).utf8).write(to: file(id), options: .atomic)
    }

    /// Removes the entry only if it still belongs to `pid`, so a newer listener keeps its own.
    public func unregister(_ id: String, pid: Int32) {
        if registeredPid(id) == pid { try? FileManager.default.removeItem(at: file(id)) }
    }

    public func isListening(_ id: String) -> Bool {
        guard let pid = registeredPid(id) else { return false }
        return kill(pid, 0) == 0
    }

    private func registeredPid(_ id: String) -> Int32? {
        (try? String(contentsOf: file(id), encoding: .utf8)).flatMap { Int32($0) }
    }

    private func file(_ id: String) -> URL {
        directory.appendingPathComponent(id)
    }
}
