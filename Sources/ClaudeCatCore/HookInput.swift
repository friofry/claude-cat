import Foundation

/// The JSON Claude Code passes to a hook on stdin, reduced to the fields ClaudeCat uses.
public struct HookInput {
    public let sessionId: String
    public let event: String
    public let toolName: String
    public let toolInput: [String: Any]
    public let message: String?
    public let notificationType: String?
    public let lastAssistantMessage: String?
    public let cwd: String?
    public let transcriptPath: String?

    public init?(json: Data) {
        guard let payload = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return nil }
        self.init(payload: payload)
    }

    /// Nil unless the payload names an event and a session id that is safe to use as a file name.
    public init?(payload: [String: Any]) {
        guard let sessionId = payload["session_id"] as? String,
              let event = payload["hook_event_name"] as? String,
              sessionId.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil else { return nil }
        self.sessionId = sessionId
        self.event = event
        toolName = payload["tool_name"] as? String ?? ""
        toolInput = payload["tool_input"] as? [String: Any] ?? [:]
        message = payload["message"] as? String
        notificationType = payload["notification_type"] as? String
        lastAssistantMessage = payload["last_assistant_message"] as? String
        cwd = payload["cwd"] as? String
        transcriptPath = payload["transcript_path"] as? String
    }

    /// The first question of an AskUserQuestion call.
    var firstQuestion: String? {
        (toolInput["questions"] as? [[String: Any]])?.first?["question"] as? String
    }
}
