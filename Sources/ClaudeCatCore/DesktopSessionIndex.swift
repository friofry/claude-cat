import Foundation

/// Maps a Claude Code session id to the Claude Desktop session that hosts it.
///
/// Claude Desktop keeps one `local_<uuid>.json` per Code session, holding the CLI id as `cliSessionId`,
/// and opens a session from `claude://code/continue?session=local_<uuid>`.
public final class DesktopSessionIndex: @unchecked Sendable {
    public static let defaultRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Claude/claude-code-sessions", isDirectory: true)

    private let root: URL
    private let lock = NSLock()
    private var cache: [String: String] = [:]

    public init(root: URL = DesktopSessionIndex.defaultRoot) {
        self.root = root
    }

    /// Nil for sessions that do not belong to Claude Desktop, such as ones started with the `claude` CLI.
    public func deepLink(forCliSession cliId: String) -> URL? {
        localId(forCliSession: cliId).flatMap { URL(string: "claude://code/continue?session=\($0)&source=claude_cat") }
    }

    public func localId(forCliSession cliId: String) -> String? {
        if let hit = lock.withLock({ cache[cliId] }) { return hit }
        let needle = Data("\"cliSessionId\":\"\(cliId)\"".utf8)
        // Live sessions are the most recently written files.
        for url in sessionFiles() {
            let localId = url.deletingPathExtension().lastPathComponent
            guard localId.range(of: "^local_[A-Za-z0-9-]{1,64}$", options: .regularExpression) != nil,
                  let data = try? Data(contentsOf: url), data.range(of: needle) != nil else { continue }
            lock.withLock { cache[cliId] = localId }
            return localId
        }
        return nil
    }

    private func sessionFiles() -> [URL] {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: Array(keys)) else { return [] }
        var files: [(url: URL, date: Date)] = []
        for case let url as URL in walker where url.lastPathComponent.hasPrefix("local_") && url.pathExtension == "json" {
            files.append((url, (try? url.resourceValues(forKeys: keys))?.contentModificationDate ?? .distantPast))
        }
        return files.sorted { $0.date > $1.date }.map(\.url)
    }
}
