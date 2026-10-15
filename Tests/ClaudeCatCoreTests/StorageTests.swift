import ClaudeCatCore
import XCTest

final class StorageTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testStoreRoundTripsRecordsAndPrunesStaleOnes() {
        let store = SessionStore(directory: directory.appendingPathComponent("sessions"))
        let now: Double = 100_000
        let fresh = SessionRecord(id: "fresh", state: .waiting, title: "T", waitReason: .question("Q?"), updated: now - 60)
        store.write(fresh)
        store.write(SessionRecord(id: "stale", state: .done, updated: now - store.staleAfter - 1))
        XCTAssertEqual(store.read("fresh"), fresh)
        XCTAssertEqual(store.loadAll(now: now).map(\.id), ["fresh"])
        XCTAssertNil(store.read("stale"))
        store.remove("fresh")
        XCTAssertTrue(store.loadAll(now: now).isEmpty)
    }

    func testDesktopIndexFindsTheLocalSessionForACliSession() throws {
        let folder = directory.appendingPathComponent("account/org", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(#"{"sessionId":"local_aaa-111","cliSessionId":"cli-1"}"#.utf8).write(to: folder.appendingPathComponent("local_aaa-111.json"))
        try Data(#"{"sessionId":"local_bbb-222","cliSessionId":"cli-2"}"#.utf8).write(to: folder.appendingPathComponent("local_bbb-222.json"))
        let index = DesktopSessionIndex(root: directory)
        XCTAssertEqual(index.localId(forCliSession: "cli-2"), "local_bbb-222")
        XCTAssertEqual(index.deepLink(forCliSession: "cli-1")?.absoluteString,
                       "claude://code/continue?session=local_aaa-111&source=claude_cat")
        XCTAssertNil(index.deepLink(forCliSession: "terminal-only"))
    }

    func testTranscriptTitleIsTheLatestTitleEntry() throws {
        let file = directory.appendingPathComponent("t.jsonl")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lines = [
            #"{"type":"custom-title","customTitle":"First"}"#,
            #"{"type":"assistant","message":"mentions "custom-title" in text"}"#,
            #"{"type":"custom-title","customTitle":"Second"}"#,
            #"{"type":"user","message":"hi"}"#,
        ]
        try Data(lines.joined(separator: "\n").utf8).write(to: file)
        XCTAssertEqual(Transcript.title(at: file.path), "Second")
        XCTAssertNil(Transcript.title(at: directory.appendingPathComponent("missing").path))
    }
}
