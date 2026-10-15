import Foundation

/// What the pet shows. `walking` is never chosen by `Board`; the app uses it while the pet strolls.
public enum PetMode: CaseIterable, Sendable {
    case idle, working, waiting, happy, sleeping, walking
}

public struct BoardCard: Equatable, Sendable {
    public enum Kind: Sendable { case waiting, done, working }
    public let kind: Kind
    public let record: SessionRecord
}

/// Decides which sessions get a card and how the pet behaves.
public struct Board: Sendable {
    public var maxCards = 4
    public var doneLifetime: Double = 30 * 60
    public var workingTimeout: Double = 3 * 3600
    public var idleWindow: Double = 20 * 60

    public init() {}

    /// Waiting sessions first, then finished, then working, newest first within each.
    /// A session the user dismissed stays hidden until its `stateKey` changes.
    public func cards(for records: [SessionRecord], dismissed: [String: String], now: Double) -> [BoardCard] {
        let ranked: [(card: BoardCard, rank: Int)] = records.compactMap { r in
            guard dismissed[r.id] != r.stateKey else { return nil }
            switch r.state {
            case .waiting:
                return (BoardCard(kind: .waiting, record: r), 0)
            case .done where now - r.updated < doneLifetime:
                return (BoardCard(kind: .done, record: r), 1)
            case .working where now - r.updated < workingTimeout:
                return (BoardCard(kind: .working, record: r), 2)
            default:
                return nil
            }
        }
        return ranked
            .sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.card.record.updated > $1.card.record.updated }
            .prefix(maxCards)
            .map(\.card)
    }

    /// The most urgent state across all sessions.
    public func mode(for records: [SessionRecord], now: Double, happyUntil: Double) -> PetMode {
        if records.contains(where: { $0.state == .waiting }) { return .waiting }
        if records.contains(where: { $0.state == .working && now - $0.updated < workingTimeout }) { return .working }
        if now < happyUntil { return .happy }
        if let newest = records.map(\.updated).max(), now - newest < idleWindow { return .idle }
        return .sleeping
    }
}
