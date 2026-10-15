import Foundation

public enum Transcript {
    /// The latest session title in a Claude Code transcript (JSONL), searching only its last `window` bytes.
    public static func title(at path: String, window: UInt64 = 1 << 20) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > window ? size - window : 0)
        guard let data = try? handle.readToEnd() else { return nil }
        // The window may start mid-character; decoding with repair keeps the rest readable.
        let text = String(decoding: data, as: UTF8.self)
        for line in text.split(separator: "\n").reversed() {
            guard line.contains("\"custom-title\"") || line.contains("\"ai-title\"") || line.contains("\"summary\"") else { continue }
            guard let entry = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any] else { continue }
            for key in ["customTitle", "aiTitle", "title", "summary"] {
                if let title = entry[key] as? String, !title.isEmpty { return title }
            }
        }
        return nil
    }
}
