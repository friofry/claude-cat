// Claude Code hook: records each session's state for ClaudeCat.
// It never writes to stdout and always exits 0, so it cannot change Claude's behavior.
import ClaudeCatCore
import Foundation

let store = SessionStore()
if let input = HookInput(json: FileHandle.standardInput.readDataToEndOfFile()) {
    let outcome = Transition.apply(input, to: store.read(input.sessionId), now: Date().timeIntervalSince1970) {
        input.transcriptPath.flatMap { Transcript.title(at: $0) }
    }
    switch outcome {
    case .ignore: break
    case .remove: store.remove(input.sessionId)
    case .write(let record): store.write(record)
    }
}
exit(0)
