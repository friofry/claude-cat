import Foundation

public enum HookOutcome: Equatable {
    case ignore
    case remove
    case write(SessionRecord)
}

/// How one hook event changes a session's record.
public enum Transition {
    /// `transcriptTitle` is called only when the title may have changed, since it reads the transcript.
    public static func apply(_ input: HookInput, to previous: SessionRecord?, now: Double,
                             transcriptTitle: () -> String?) -> HookOutcome {
        var record = previous ?? SessionRecord(id: input.sessionId, state: .idle, updated: now)
        record.id = input.sessionId
        var refreshTitle = true

        switch input.event {
        case "SessionStart":
            record.state = .idle
        case "UserPromptSubmit":
            record.state = .working
            record.activity = .thinking
            record.waitReason = nil
            record.reply = nil
            refreshTitle = false
        case "PreToolUse":
            switch input.toolName {
            case "AskUserQuestion":
                record.state = .waiting
                record.waitReason = .question(Text.oneLine(input.firstQuestion ?? ""))
            case "ExitPlanMode":
                record.state = .waiting
                record.waitReason = .planApproval
            default:
                record.state = .working
                record.waitReason = nil
                record.activity = Activity(tool: input.toolName, input: input.toolInput)
                refreshTitle = false
            }
        case "PostToolUse", "PostToolUseFailure":
            record.state = .working
            record.waitReason = nil
            refreshTitle = false
        case "PermissionRequest":
            record.state = .waiting
            record.waitReason = .permission(tool: input.toolName)
        case "Notification":
            // Idle reminders are not requests, and a permission prompt is already recorded by PermissionRequest.
            if input.notificationType == "idle_prompt" || previous?.state == .waiting { return .ignore }
            record.state = .waiting
            record.waitReason = .notice(Text.oneLine(input.message ?? ""))
        case "Stop":
            record.state = .done
            record.activity = nil
            record.waitReason = nil
            record.reply = Text.oneLine(input.lastAssistantMessage ?? "")
        case "SessionEnd":
            return .remove
        default:
            return .ignore
        }

        if refreshTitle || record.title == nil {
            let folder = input.cwd.map { URL(fileURLWithPath: $0).lastPathComponent }
            record.title = transcriptTitle() ?? record.title ?? folder
        }
        record.updated = now
        return .write(record)
    }
}

extension Activity {
    public init(tool: String, input: [String: Any]) {
        func fileName(_ key: String) -> String {
            (input[key] as? String).map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
        }
        func text(_ key: String) -> String? {
            guard let raw = input[key] as? String else { return nil }
            let line = Text.oneLine(raw, limit: 90)
            return line.isEmpty ? nil : line
        }
        switch tool {
        case "Bash": self = .command(text("description"))
        case "Read": self = .reading(fileName("file_path"))
        case "Edit", "MultiEdit", "Write": self = .editing(fileName("file_path"))
        case "NotebookEdit": self = .editing(fileName("notebook_path"))
        case "Grep", "Glob", "LSP": self = .searchingCode
        case "WebFetch", "WebSearch": self = .searchingWeb
        case "Agent", "Task": self = .agent(text("description"))
        case "TodoWrite": self = .planning
        case "Skill": self = .skill(text("skill") ?? "")
        default: self = .tool(tool.hasPrefix("mcp__") ? (tool.components(separatedBy: "__").last ?? tool) : tool)
        }
    }
}
