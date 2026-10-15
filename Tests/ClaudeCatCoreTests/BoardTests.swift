import ClaudeCatCore
import XCTest

final class BoardTests: XCTestCase {
    private let board = Board()
    private let now: Double = 10_000

    private func session(_ id: String, _ state: SessionState, age: Double) -> SessionRecord {
        SessionRecord(id: id, state: state, updated: now - age)
    }

    func testWaitingComesFirstThenDoneThenWorking() {
        let records = [session("w", .working, age: 1), session("d", .done, age: 2), session("q", .waiting, age: 3)]
        XCTAssertEqual(board.cards(for: records, dismissed: [:], now: now).map(\.record.id), ["q", "d", "w"])
    }

    func testNewestFirstWithinAKindAndAtMostFourCards() {
        let records = (1...6).map { session("d\($0)", .done, age: Double($0)) }
        XCTAssertEqual(board.cards(for: records, dismissed: [:], now: now).map(\.record.id), ["d1", "d2", "d3", "d4"])
    }

    func testFinishedCardsExpireAndIdleSessionsGetNone() {
        let records = [session("old", .done, age: 31 * 60), session("idle", .idle, age: 1)]
        XCTAssertTrue(board.cards(for: records, dismissed: [:], now: now).isEmpty)
    }

    func testDismissedWorkingCardStaysHiddenUntilTheSessionFinishes() {
        let working = session("s", .working, age: 1)
        let dismissed = ["s": working.stateKey]
        let laterTool = session("s", .working, age: 0)
        XCTAssertTrue(board.cards(for: [laterTool], dismissed: dismissed, now: now).isEmpty)
        let finished = session("s", .done, age: 0)
        XCTAssertEqual(board.cards(for: [finished], dismissed: dismissed, now: now).count, 1)
    }

    func testModeFollowsTheMostUrgentSession() {
        XCTAssertEqual(board.mode(for: [session("a", .working, age: 1), session("b", .waiting, age: 1)], now: now, happyUntil: 0), .waiting)
        XCTAssertEqual(board.mode(for: [session("a", .working, age: 1)], now: now, happyUntil: 0), .working)
        XCTAssertEqual(board.mode(for: [session("a", .done, age: 1)], now: now, happyUntil: now + 5), .happy)
        XCTAssertEqual(board.mode(for: [session("a", .done, age: 60)], now: now, happyUntil: 0), .idle)
        XCTAssertEqual(board.mode(for: [session("a", .done, age: 21 * 60)], now: now, happyUntil: 0), .sleeping)
        XCTAssertEqual(board.mode(for: [], now: now, happyUntil: 0), .sleeping)
    }
}
