import Foundation

/// A running local session as `claude agents --json` reports it.
public struct LiveSession: Equatable, Sendable {
    public enum Status: String, Sendable { case busy, idle, waiting }
    public let id: String
    public let name: String
    public let cwd: String?
    public let status: Status
    public let waitingFor: String?
    /// Seconds since 1970.
    public let startedAt: Double

    public init(id: String, name: String, cwd: String?, status: Status, waitingFor: String?, startedAt: Double) {
        self.id = id
        self.name = name
        self.cwd = cwd
        self.status = status
        self.waitingFor = waitingFor
        self.startedAt = startedAt
    }
}

/// The live session list from the Claude Code CLI, reconciled with the hook records.
///
/// Hooks know what a session is doing; the CLI knows which sessions are alive and whether they wait.
/// The CLI covers sessions the hooks have not heard from (for example ones that stopped at a permission
/// prompt before ClaudeCat was installed) and corrects records a missed event left stale (a turn
/// interrupted with Esc never sends Stop).
public enum LiveSessions {
    public static func parse(_ data: Data) -> [LiveSession]? {
        guard let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        return rows.compactMap { row in
            guard let id = row["sessionId"] as? String,
                  let status = (row["status"] as? String).flatMap(LiveSession.Status.init) else { return nil }
            let started = (row["startedAt"] as? Double).map { $0 / 1000 } ?? 0
            return LiveSession(id: id, name: row["name"] as? String ?? "Claude", cwd: row["cwd"] as? String,
                               status: status, waitingFor: row["waitingFor"] as? String, startedAt: started)
        }
    }

    /// `live` was taken at `takenAt`. Records written after that are newer than the list and win;
    /// without a list the records are returned unchanged.
    public static func merge(_ records: [SessionRecord], live: [LiveSession]?, takenAt: Double) -> [SessionRecord] {
        guard let live else { return records }
        let byId = Dictionary(live.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var merged: [SessionRecord] = records.map { record in
            guard record.updated < takenAt else { return record }
            var r = record
            switch byId[r.id]?.status {
            case .waiting?:
                if r.state != .waiting {
                    r.state = .waiting
                    r.waitReason = waitReason(byId[r.id]?.waitingFor)
                }
            case .idle?:
                if r.state == .working || r.state == .waiting { r.state = .idle }
            case .busy?:
                if r.state == .idle { r.state = .working }
            case nil:
                // The process is gone, so nothing is running or waiting any more.
                if r.state == .working || r.state == .waiting { r.state = .idle }
            }
            return r
        }
        let known = Set(records.map(\.id))
        for session in live where !known.contains(session.id) {
            merged.append(record(for: session, takenAt: takenAt))
        }
        return merged.sorted { $0.updated > $1.updated }
    }

    /// A record for a session the hooks have not seen. Its `updated` stays fixed while it waits,
    /// so dismissing its card holds until it changes.
    static func record(for session: LiveSession, takenAt: Double) -> SessionRecord {
        switch session.status {
        case .busy:
            return SessionRecord(id: session.id, state: .working, title: session.name, cwd: session.cwd, updated: takenAt)
        case .waiting:
            return SessionRecord(id: session.id, state: .waiting, title: session.name,
                                 waitReason: waitReason(session.waitingFor), cwd: session.cwd, updated: session.startedAt)
        case .idle:
            return SessionRecord(id: session.id, state: .idle, title: session.name, cwd: session.cwd, updated: session.startedAt)
        }
    }

    static func waitReason(_ waitingFor: String?) -> WaitReason {
        guard let waitingFor, !waitingFor.isEmpty else { return .notice("") }
        return waitingFor.localizedCaseInsensitiveContains("permission") ? .permission(tool: "") : .notice(waitingFor)
    }
}
