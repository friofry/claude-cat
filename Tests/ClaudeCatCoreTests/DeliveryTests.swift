import ClaudeCatCore
import XCTest

final class DeliveryTests: XCTestCase {
    private func json(_ data: Data?) -> [String: Any]? {
        data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    func testStopRequestEndsTheTurnAtTheNextToolCall() {
        let response = HookControl.respond(to: "PreToolUse", with: .stop)
        XCTAssertTrue(response.consume)
        XCTAssertEqual(json(response.output)?["continue"] as? Bool, false)
        XCTAssertEqual(HookControl.respond(to: "PostToolUse", with: .stop), .init(output: nil, consume: false))
    }

    func testMessageReachesClaudeAfterTheCurrentTool() {
        let response = HookControl.respond(to: "PostToolUse", with: .message("use TTL"))
        let specific = json(response.output)?["hookSpecificOutput"] as? [String: String]
        XCTAssertTrue(response.consume)
        XCTAssertEqual(specific?["hookEventName"], "PostToolUse")
        XCTAssertTrue(specific?["additionalContext"]?.hasSuffix("use TTL") == true)
        XCTAssertEqual(HookControl.respond(to: "PreToolUse", with: .message("x")), .init(output: nil, consume: false))
    }

    func testLeftoverStopIsDroppedWhenTheTurnEndsButAMessageWaitsForTheListener() {
        XCTAssertEqual(HookControl.respond(to: "Stop", with: .stop), .init(output: nil, consume: true))
        XCTAssertEqual(HookControl.respond(to: "UserPromptSubmit", with: .stop), .init(output: nil, consume: true))
        XCTAssertEqual(HookControl.respond(to: "Stop", with: .message("x")), .init(output: nil, consume: false))
        XCTAssertEqual(HookControl.respond(to: "SessionEnd", with: .message("x")), .init(output: nil, consume: true))
    }

    func testListenerWaitsForTheFinishedRecordThenDeliversAReply() {
        var state = Listener.State()
        let working = SessionRecord(id: "s", state: .working, updated: 10)
        let done = SessionRecord(id: "s", state: .done, updated: 11)
        XCTAssertEqual(Listener.step(&state, record: working, inbox: nil, orphaned: false, elapsed: 1, limit: 60), .wait)
        XCTAssertEqual(Listener.step(&state, record: done, inbox: nil, orphaned: false, elapsed: 2, limit: 60), .wait)
        XCTAssertEqual(state.doneAt, 11)
        XCTAssertEqual(Listener.step(&state, record: done, inbox: .message("go on"), orphaned: false, elapsed: 30, limit: 60),
                       .deliver("go on"))
    }

    func testListenerQuitsWhenTheSessionMovesOnOrItsClaudeIsGone() {
        var state = Listener.State()
        state.doneAt = 11
        let nextTurn = SessionRecord(id: "s", state: .working, updated: 20)
        XCTAssertEqual(Listener.step(&state, record: nextTurn, inbox: nil, orphaned: false, elapsed: 5, limit: 60), .quit)
        let done = SessionRecord(id: "s", state: .done, updated: 11)
        XCTAssertEqual(Listener.step(&state, record: done, inbox: nil, orphaned: true, elapsed: 5, limit: 60), .quit)
        XCTAssertEqual(Listener.step(&state, record: done, inbox: nil, orphaned: false, elapsed: 60, limit: 60), .quit)
        var fresh = Listener.State()
        XCTAssertEqual(Listener.step(&fresh, record: nil, inbox: nil, orphaned: false, elapsed: Listener.settleTime, limit: 60), .quit)
    }

    func testInboxAndListenerRegistryOnDisk() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let inbox = Inbox(directory: root.appendingPathComponent("inbox"))
        inbox.post(.message("hi"), to: "s")
        XCTAssertEqual(inbox.peek("s"), .message("hi"))
        inbox.post(.stop, to: "s")
        XCTAssertEqual(inbox.peek("s"), .stop)
        inbox.remove("s")
        XCTAssertNil(inbox.peek("s"))

        let registry = ListenerRegistry(directory: root.appendingPathComponent("listeners"))
        registry.register("s", pid: getpid())
        XCTAssertTrue(registry.isListening("s"))
        registry.unregister("s", pid: getpid() + 1)
        XCTAssertTrue(registry.isListening("s"), "another listener's pid must not remove this one")
        registry.unregister("s", pid: getpid())
        XCTAssertFalse(registry.isListening("s"))
        registry.register("dead", pid: 999_999)
        XCTAssertFalse(registry.isListening("dead"))
    }
}
