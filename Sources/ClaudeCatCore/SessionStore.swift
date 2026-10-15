import Foundation

/// One JSON file per session in a directory shared by the hook (writer) and the app (reader).
public struct SessionStore: Sendable {
    public static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude-cat/sessions", isDirectory: true)

    public let directory: URL
    public var staleAfter: Double = 12 * 3600

    public init(directory: URL = SessionStore.defaultDirectory) {
        self.directory = directory
    }

    public func read(_ id: String) -> SessionRecord? {
        guard let data = try? Data(contentsOf: file(id)),
              var record = try? JSONDecoder().decode(SessionRecord.self, from: data) else { return nil }
        record.id = id
        return record
    }

    public func write(_ record: SessionRecord) {
        createDirectory()
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: file(record.id), options: .atomic)
    }

    public func remove(_ id: String) {
        try? FileManager.default.removeItem(at: file(id))
    }

    /// Live sessions, newest first. Files untouched for `staleAfter` seconds are deleted.
    public func loadAll(now: Double) -> [SessionRecord] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        var records: [SessionRecord] = []
        for url in files where url.pathExtension == "json" {
            guard let record = read(url.deletingPathExtension().lastPathComponent) else { continue }
            if now - record.updated > staleAfter {
                try? fm.removeItem(at: url)
            } else {
                records.append(record)
            }
        }
        return records.sorted { $0.updated > $1.updated }
    }

    public func clear() {
        let fm = FileManager.default
        for url in (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: url)
        }
    }

    public func createDirectory() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func file(_ id: String) -> URL {
        directory.appendingPathComponent("\(id).json")
    }
}
