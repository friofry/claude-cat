import Foundation

public enum SessionState: String, Codable, Sendable {
    case idle, working, waiting, done
}

/// What a working session is doing, recorded as facts; the app turns it into words.
public enum Activity: Codable, Equatable, Sendable {
    case thinking
    case command(String?)
    case reading(String)
    case editing(String)
    case searchingCode
    case searchingWeb
    case agent(String?)
    case planning
    case skill(String)
    case tool(String)
}

/// Why a session is waiting for the user.
public enum WaitReason: Codable, Equatable, Sendable {
    case question(String)
    case permission(tool: String)
    case planApproval
    case notice(String)
}

/// The state of one Claude Code session, as the hook last saw it.
public struct SessionRecord: Codable, Equatable, Sendable {
    /// The Claude Code session id; it names the file and is not stored inside it.
    public var id: String = ""
    public var state: SessionState
    public var title: String?
    public var activity: Activity?
    public var waitReason: WaitReason?
    public var reply: String?
    /// The session's working directory, used as the folder for a new chat.
    public var cwd: String?
    public var updated: Double

    public init(id: String, state: SessionState, title: String? = nil, activity: Activity? = nil,
                waitReason: WaitReason? = nil, reply: String? = nil, cwd: String? = nil, updated: Double) {
        self.id = id
        self.state = state
        self.title = title
        self.activity = activity
        self.waitReason = waitReason
        self.reply = reply
        self.cwd = cwd
        self.updated = updated
    }

    enum CodingKeys: String, CodingKey {
        case state, title, activity, waitReason, reply, cwd, updated
    }

    /// Changes when the session enters a new state or event, but not on every tool call while working.
    public var stateKey: String {
        state == .working ? SessionState.working.rawValue : "\(state.rawValue)|\(updated)"
    }
}
