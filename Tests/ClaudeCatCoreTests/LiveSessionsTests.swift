import ClaudeCatCore
import XCTest

final class LiveSessionsTests: XCTestCase {
    private let takenAt: Double = 1_000

    private func live(_ id: String, _ status: LiveSession.Status, waitingFor: String? = nil) -> LiveSession {
        LiveSession(id: id, name: "name-\(id)", cwd: "/work/\(id)", status: status, waitingFor: waitingFor, startedAt: 100)
    }

    func testParsesTheCliOutputAndSkipsRowsItCannotRead() {
        let json = #"""
        [{"pid":1,"cwd":"/w","kind":"interactive","startedAt":1791652364502,"sessionId":"a","name":"singline-dd",
          "status":"waiting","waitingFor":"permission prompt"},
         {"sessionId":"b","status":"exploding"},
         {"sessionId":"c","status":"busy"}]
        """#
        let sessions = LiveSessions.parse(Data(json.utf8))
        XCTAssertEqual(sessions?.map(\.id), ["a", "c"])
        XCTAssertEqual(sessions?.first?.startedAt, 1_791_652_364.502)
        XCTAssertEqual(sessions?.first?.waitingFor, "permission prompt")
        XCTAssertNil(LiveSessions.parse(Data("not json".utf8)))
    }

    func testSessionsTheHooksNeverSawAppear() {
        let merged = LiveSessions.merge([], live: [live("w", .waiting, waitingFor: "permission prompt"), live("b", .busy)], takenAt: takenAt)
        let waiting = merged.first { $0.id == "w" }
        XCTAssertEqual(waiting?.state, .waiting)
        XCTAssertEqual(waiting?.waitReason, .permission(tool: ""))
        XCTAssertEqual(waiting?.title, "name-w")
        XCTAssertEqual(waiting?.updated, 100, "a fixed time keeps a dismissed card hidden")
        XCTAssertEqual(merged.first { $0.id == "b" }?.state, .working)
    }

    func testTheCliCorrectsStaleRecords() {
        let interrupted = SessionRecord(id: "i", state: .working, title: "T", updated: 500)
        let prompted = SessionRecord(id: "p", state: .working, title: "T", updated: 500)
        let gone = SessionRecord(id: "g", state: .waiting, title: "T", updated: 500)
        let merged = LiveSessions.merge([interrupted, prompted, gone], live: [live("i", .idle), live("p", .waiting)], takenAt: takenAt)
        XCTAssertEqual(merged.first { $0.id == "i" }?.state, .idle)
        XCTAssertEqual(merged.first { $0.id == "p" }?.state, .waiting)
        XCTAssertEqual(merged.first { $0.id == "g" }?.state, .idle)
        XCTAssertEqual(merged.first { $0.id == "i" }?.title, "T", "hook details are kept")
    }

    func testRecordsNewerThanTheListWin() {
        let fresh = SessionRecord(id: "f", state: .working, activity: .thinking, updated: takenAt + 1)
        let merged = LiveSessions.merge([fresh], live: [live("f", .idle)], takenAt: takenAt)
        XCTAssertEqual(merged.first?.state, .working)
    }

    func testWithoutAListNothingChanges() {
        let record = SessionRecord(id: "r", state: .working, updated: 1)
        XCTAssertEqual(LiveSessions.merge([record], live: nil, takenAt: takenAt), [record])
    }
}
