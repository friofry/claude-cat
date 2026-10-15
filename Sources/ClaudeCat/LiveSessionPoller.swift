import ClaudeCatCore
import Foundation

/// Runs `claude agents --json` every few seconds off the main thread and keeps the latest list.
@MainActor
final class LiveSessionPoller {
    private(set) var sessions: [LiveSession]?
    private(set) var takenAt: Double = 0
    var onUpdate: (() -> Void)?

    private let queue = DispatchQueue(label: "claude-cat.live-sessions", qos: .utility)
    private var executable: String?
    private var inFlight = false

    func start(every interval: TimeInterval) {
        queue.async {
            let path = Self.findClaude()
            DispatchQueue.main.async {
                self.executable = path
                self.poll()
                Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.poll() }
                }
            }
        }
    }

    private func poll() {
        guard let executable, !inFlight else { return }
        inFlight = true
        queue.async {
            let started = Date().timeIntervalSince1970
            let parsed = Self.run(executable, ["agents", "--json"]).flatMap(LiveSessions.parse)
            DispatchQueue.main.async {
                self.inFlight = false
                // A failed run keeps the hooks as the only source rather than hiding every session.
                guard let parsed else { return }
                self.sessions = parsed
                self.takenAt = started
                self.onUpdate?()
            }
        }
    }

    /// Apps started from Finder get a minimal PATH, so look where installers put the CLI, then ask a login shell.
    nonisolated static func findClaude() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = ["/opt/homebrew/bin/claude", "/usr/local/bin/claude", "\(home)/.local/bin/claude", "\(home)/.claude/local/claude"]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) { return found }
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let path = run(shell, ["-lc", "command -v claude"]).map { String(decoding: $0, as: UTF8.self) }
        return path?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    /// Stdout of a finished process, or nil if it fails or takes longer than `timeout`.
    nonisolated static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 15) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do { try process.run() } catch { return nil }
        // Read while waiting, so a large output cannot fill the pipe and stall the process.
        let reader = DispatchGroup()
        nonisolated(unsafe) var data = Data()
        DispatchQueue.global(qos: .utility).async(group: reader) {
            data = output.fileHandleForReading.readDataToEndOfFile()
        }
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return nil
        }
        reader.wait()
        return process.terminationStatus == 0 ? data : nil
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
