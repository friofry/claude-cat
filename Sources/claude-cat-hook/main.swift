// Claude Code hook for ClaudeCat.
//
//   claude-cat-hook         records the session's state and delivers stop requests and messages
//                           from ClaudeCat; prints JSON only when it has one to deliver.
//   claude-cat-hook listen  an asyncRewake Stop hook: waits for a reply from ClaudeCat and wakes
//                           the session with it (exit 2), or exits 0 once the session moves on.
import ClaudeCatCore
import Foundation

let store = SessionStore()
let inbox = Inbox()
guard let input = HookInput(json: FileHandle.standardInput.readDataToEndOfFile()) else { exit(0) }
let id = input.sessionId

if CommandLine.arguments.dropFirst().first == "listen" {
    let registry = ListenerRegistry()
    let pid = getpid()
    let started = Date()
    var state = Listener.State()
    registry.register(id, pid: pid)
    while true {
        let message = inbox.peek(id).flatMap { item -> InboxItem? in
            if case .message = item { return item }
            return nil
        }
        let step = Listener.step(&state, record: store.read(id), inbox: message, orphaned: getppid() == 1,
                                 elapsed: Date().timeIntervalSince(started), limit: 6 * 3600)
        switch step {
        case .wait:
            usleep(500_000)
        case .deliver(let text):
            inbox.remove(id)
            registry.unregister(id, pid: pid)
            FileHandle.standardError.write(Data(HookControl.userMessage(text).utf8))
            exit(2)
        case .quit:
            registry.unregister(id, pid: pid)
            exit(0)
        }
    }
}

let outcome = Transition.apply(input, to: store.read(id), now: Date().timeIntervalSince1970) {
    input.transcriptPath.flatMap { Transcript.title(at: $0) }
}
switch outcome {
case .ignore: break
case .remove: store.remove(id)
case .write(let record): store.write(record)
}

if let item = inbox.peek(id) {
    let response = HookControl.respond(to: input.event, with: item)
    if response.consume { inbox.remove(id) }
    if let output = response.output { FileHandle.standardOutput.write(output) }
}
exit(0)
