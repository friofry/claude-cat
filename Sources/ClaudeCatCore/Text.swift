import Foundation

public enum Text {
    /// One line of plain text: Markdown markers dropped, whitespace collapsed, cut to `limit` characters.
    public static func oneLine(_ text: String, limit: Int = 200) -> String {
        let unprefixed = text.replacingOccurrences(of: "(?m)^\\s*(#+|>|[-*+]|\\d+\\.)\\s+", with: "", options: .regularExpression)
        let plain = unprefixed.replacingOccurrences(of: "[*`|]", with: "", options: .regularExpression)
        let collapsed = plain.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return collapsed.count > limit ? String(collapsed.prefix(limit)) + "…" : collapsed
    }
}
