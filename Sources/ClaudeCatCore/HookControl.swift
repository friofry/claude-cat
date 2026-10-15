import Foundation

/// How a hook delivers what the user sent from ClaudeCat.
public enum HookControl {
    public struct Response: Equatable {
        /// JSON for the hook's stdout, if any.
        public let output: Data?
        /// Whether the inbox item is used up.
        public let consume: Bool

        public init(output: Data?, consume: Bool) {
            self.output = output
            self.consume = consume
        }
    }

    /// A stop request ends the turn at the next tool call; a message reaches Claude after the current tool.
    /// Stop requests left over when a turn ends are dropped so they cannot stop the next one.
    public static func respond(to event: String, with item: InboxItem) -> Response {
        switch (event, item) {
        case ("PreToolUse", .stop):
            return Response(output: json(["continue": false, "stopReason": "Stopped from ClaudeCat"]), consume: true)
        case ("PostToolUse", .message(let text)):
            let context = ["hookEventName": event, "additionalContext": userMessage(text)]
            return Response(output: json(["hookSpecificOutput": context]), consume: true)
        case ("Stop", .stop), ("UserPromptSubmit", .stop), ("SessionEnd", _):
            return Response(output: nil, consume: true)
        default:
            return Response(output: nil, consume: false)
        }
    }

    public static func userMessage(_ text: String) -> String {
        "The user sent this message from the ClaudeCat desktop pet:\n\n\(text)"
    }

    private static func json(_ object: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

/// The reply listener a finished session runs in the background (an `asyncRewake` Stop hook).
/// It wakes the session with the user's reply, or quits once the session moves on.
public enum Listener {
    public enum Step: Equatable {
        case wait
        case deliver(String)
        case quit
    }

    public struct State: Equatable {
        /// The `updated` time of the finished record this listener belongs to.
        public var doneAt: Double?
        public init() {}
    }

    /// The Stop hook that records the finished state runs alongside the listener, so give it a moment.
    public static let settleTime: Double = 5

    public static func step(_ state: inout State, record: SessionRecord?, inbox: InboxItem?,
                            orphaned: Bool, elapsed: Double, limit: Double) -> Step {
        if case .message(let text)? = inbox { return .deliver(text) }
        if orphaned || elapsed >= limit { return .quit }
        if let doneAt = state.doneAt {
            return record?.state == .done && record?.updated == doneAt ? .wait : .quit
        }
        if let record, record.state == .done {
            state.doneAt = record.updated
            return .wait
        }
        return elapsed < settleTime ? .wait : .quit
    }
}
