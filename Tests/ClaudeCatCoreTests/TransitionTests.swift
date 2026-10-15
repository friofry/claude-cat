import ClaudeCatCore
import XCTest

final class TransitionTests: XCTestCase {
    private func input(_ event: String, _ extra: [String: Any] = [:]) -> HookInput {
        HookInput(payload: ["session_id": "s1", "hook_event_name": event, "cwd": "/work/project"]
            .merging(extra) { _, new in new })!
    }

    private func record(_ outcome: HookOutcome) -> SessionRecord? {
        if case .write(let record) = outcome { return record }
        return nil
    }

    private func apply(_ input: HookInput, to previous: SessionRecord? = nil, title: String? = nil) -> HookOutcome {
        Transition.apply(input, to: previous, now: 100) { title }
    }

    func testPromptStartsWorkingAndClearsTheLastReply() {
        let previous = SessionRecord(id: "s1", state: .done, title: "T", reply: "old", updated: 1)
        let r = record(apply(input("UserPromptSubmit"), to: previous))
        XCTAssertEqual(r?.state, .working)
        XCTAssertEqual(r?.activity, .thinking)
        XCTAssertNil(r?.reply)
        XCTAssertEqual(r?.updated, 100)
    }

    func testToolUseRecordsWhatTheSessionDoes() {
        let bash = record(apply(input("PreToolUse", ["tool_name": "Bash", "tool_input": ["command": "make", "description": "Run tests"]])))
        XCTAssertEqual(bash?.activity, .command("Run tests"))
        let edit = record(apply(input("PreToolUse", ["tool_name": "Edit", "tool_input": ["file_path": "/a/b/Cards.swift"]])))
        XCTAssertEqual(edit?.activity, .editing("Cards.swift"))
        let mcp = record(apply(input("PreToolUse", ["tool_name": "mcp__server__mark_chapter"])))
        XCTAssertEqual(mcp?.activity, .tool("mark_chapter"))
    }

    func testQuestionsPlansAndPermissionsWaitForTheUser() {
        let question = record(apply(input("PreToolUse", ["tool_name": "AskUserQuestion",
                                                         "tool_input": ["questions": [["question": "LRU or TTL?"]]]])))
        XCTAssertEqual(question?.state, .waiting)
        XCTAssertEqual(question?.waitReason, .question("LRU or TTL?"))
        XCTAssertEqual(record(apply(input("PreToolUse", ["tool_name": "ExitPlanMode"])))?.waitReason, .planApproval)
        XCTAssertEqual(record(apply(input("PermissionRequest", ["tool_name": "Bash"])))?.waitReason, .permission(tool: "Bash"))
    }

    func testToolResultResumesWorkAfterWaiting() {
        let waiting = SessionRecord(id: "s1", state: .waiting, title: "T", waitReason: .permission(tool: "Bash"), updated: 1)
        let r = record(apply(input("PostToolUse"), to: waiting))
        XCTAssertEqual(r?.state, .working)
        XCTAssertNil(r?.waitReason)
    }

    func testIdleRemindersAndRepeatedPromptsAreIgnored() {
        XCTAssertEqual(apply(input("Notification", ["notification_type": "idle_prompt"])), .ignore)
        let waiting = SessionRecord(id: "s1", state: .waiting, waitReason: .permission(tool: "Bash"), updated: 1)
        XCTAssertEqual(apply(input("Notification", ["notification_type": "permission_prompt"]), to: waiting), .ignore)
    }

    func testStopKeepsTheReplyAsOnePlainLine() {
        let r = record(apply(input("Stop", ["last_assistant_message": "## Done\n\n**Table** is `ready`."])))
        XCTAssertEqual(r?.state, .done)
        XCTAssertEqual(r?.reply, "Done Table is ready.")
    }

    func testSessionEndRemovesAndUnknownEventsAreIgnored() {
        XCTAssertEqual(apply(input("SessionEnd")), .remove)
        XCTAssertEqual(apply(input("SubagentStop")), .ignore)
    }

    func testTitleComesFromTheTranscriptElseKeepsTheOldOneElseTheFolder() {
        XCTAssertEqual(record(apply(input("Stop"), title: "From transcript"))?.title, "From transcript")
        let titled = SessionRecord(id: "s1", state: .working, title: "Kept", updated: 1)
        XCTAssertEqual(record(apply(input("Stop"), to: titled))?.title, "Kept")
        XCTAssertEqual(record(apply(input("Stop")))?.title, "project")
    }

    func testUnsafeSessionIdsAreRejected() {
        XCTAssertNil(HookInput(payload: ["session_id": "../../etc", "hook_event_name": "Stop"]))
        XCTAssertNil(HookInput(payload: ["hook_event_name": "Stop"]))
    }
}
