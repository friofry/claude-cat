import Foundation

public typealias Grid = [[Character?]]

/// A pixel-art pet. Frames are grids of palette keys; `tick` runs at `Skins.fps`.
public protocol PetSkin {
    var id: String { get }
    var width: Int { get }
    var height: Int { get }
    func frame(mode: PetMode, tick: Int) -> Grid
}

public enum Skins {
    public static let fps: Double = 8
    public static let headroom = 5
    public static let all: [PetSkin] = [CatSkin(), ClawdSkin(), SlimeSkin()]

    public static func named(_ id: String?) -> PetSkin {
        all.first { $0.id == id } ?? all[0]
    }

    public enum Look { case open, blink, wide, happy, closed }

    public static func look(_ mode: PetMode, _ tick: Int) -> Look {
        switch mode {
        case .idle, .working: return tick % 48 == 0 ? .blink : .open
        case .waiting: return .wide
        case .happy: return .happy
        case .sleeping: return .closed
        }
    }

    /// A short hop every 1.5 s while waiting.
    public static func hop(_ mode: PetMode, _ tick: Int) -> Int {
        mode == .waiting && tick % 12 < 2 ? -1 : 0
    }
}

public struct Canvas {
    public let width: Int
    public let height: Int
    public var grid: Grid

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        grid = Array(repeating: Array(repeating: nil, count: width), count: height)
    }

    public mutating func put(_ col: Int, _ row: Int, _ ch: Character) {
        guard row >= 0, row < height, col >= 0, col < width else { return }
        grid[row][col] = ch
    }

    /// Paints rows at (col, row); '.' is transparent and `map` can recolor or drop marker characters.
    public mutating func stamp(_ rows: [String], col: Int, row: Int, map: (Character) -> Character? = { $0 }) {
        for (r, line) in rows.enumerated() {
            for (c, ch) in line.enumerated() where ch != "." {
                if let out = map(ch) { put(col + c, row + r, out) }
            }
        }
    }

    /// Two 2-pixel eyes whose top-left pixels are at `xs`, `row`.
    public mutating func eyes(_ xs: [Int], row: Int, look: Skins.Look, ink: Character, shine: Bool) {
        for x in xs {
            switch look {
            case .open:
                put(x, row, shine ? "w" : "e"); put(x + 1, row, "e")
                put(x, row + 1, "e"); put(x + 1, row + 1, "e")
            case .blink:
                put(x, row + 1, ink); put(x + 1, row + 1, ink)
            case .wide:
                put(x, row - 1, shine ? "w" : "e"); put(x + 1, row - 1, "e")
                put(x, row, "e"); put(x + 1, row, "e")
                put(x, row + 1, "e"); put(x + 1, row + 1, "e")
            case .happy:
                put(x, row, ink); put(x + 1, row, ink)
                put(x - 1, row + 1, ink); put(x + 2, row + 1, ink)
            case .closed:
                put(x - 1, row, ink); put(x + 2, row, ink)
                put(x, row + 1, ink); put(x + 1, row + 1, ink)
            }
        }
    }

    public mutating func extras(_ mode: PetMode, tick: Int) {
        switch mode {
        case .waiting:
            for row in [0, 1, 2, 4] {
                put(width - 3, row, "r"); put(width - 2, row, "r")
            }
        case .sleeping:
            let rise = (tick / 8) % 4
            stamp(["zzzz", "..z.", ".z..", "zzzz"], col: width - 6 + rise / 2, row: 3 - rise) { _ in "z" }
        case .happy:
            if tick % 8 < 4 {
                put(1, 3, "y"); put(width - 2, 1, "y")
            } else {
                put(0, 1, "y"); put(width - 3, 3, "y")
            }
        case .idle, .working:
            break
        }
    }
}

public struct CatSkin: PetSkin {
    public let id = "cat"
    public let width = 24
    public let height = Skins.headroom + 20

    public static let body: [String] = [
        "..k..............k..",
        "..kk............kk..",
        "..kok..........kok..",
        "..kpok........kopk..",
        "..kppokkkkkkkkoppk..",
        "..kooooooooooooook..",
        ".kooooooooooooooook.",
        ".kooooooooooooooook.",
        ".kooEEooooooooEEook.",
        ".kooEEooooooooEEook.",
        ".koppoooonnooooppok.",
        ".kooooookookooooook.",
        ".koooooookkoooooook.",
        "..kooooooooooooook..",
        "...kkooooooooookk...",
        "...koollllllllook...",
        "...koollllllllook...",
        "...koollllllllook...",
        "...kPPkooooookPPk...",
        "...kkkkkkkkkkkkkk...",
    ]

    // Tail frames start at body row 9, column 16.
    public static let tailUp: [String] = [
        "........", "......k.", ".....kok", ".....kok", "....kok.",
        "....kok.", "...kok..", "..kok...", ".kok....", "kok.....",
    ]
    public static let tailDown: [String] = [
        "........", "........", "........", "........", "........",
        "......kk", "....kkok", "..kkook.", ".kook...", "kkk.....",
    ]

    public func frame(mode: PetMode, tick: Int) -> Grid {
        var c = Canvas(width: width, height: height)
        let top = Skins.headroom + Skins.hop(mode, tick)

        let tail: [String]
        switch mode {
        case .working: tail = Self.tailUp
        case .waiting, .happy: tail = tick % 8 < 4 ? Self.tailUp : Self.tailDown
        case .idle: tail = tick % 64 < 3 ? Self.tailDown : Self.tailUp
        case .sleeping: tail = Self.tailDown
        }
        c.stamp(tail, col: 16, row: top + 9)
        c.stamp(Self.body, col: 0, row: top) { $0 == "E" ? "o" : $0 }
        c.eyes([4, 14], row: top + 8, look: Skins.look(mode, tick), ink: "k", shine: true)

        if mode == .working {
            // Paws take turns tapping, twice a second.
            let raised = tick % 8 < 4 ? 3 : 13
            c.stamp(["kPPk"], col: raised, row: top + 17)
            c.put(raised + 1, top + 18, "o")
            c.put(raised + 2, top + 18, "o")
        }
        c.extras(mode, tick: tick)
        return c.grid
    }
}

/// Inspired by the Claude Code terminal mascot: flat coral block, side arms, four legs.
public struct ClawdSkin: PetSkin {
    public let id = "clawd"
    public let width = 24
    public let height = Skins.headroom + 11

    public static let body: [String] = [
        "...oooooooooooooo...",
        "...oooooooooooooo...",
        "...ooEEooooooEEoo...",
        "...ooEEooooooEEoo...",
        "...oooooooooooooo...",
        ".AooooooooooooooooA.",
        ".AooooooooooooooooA.",
        "...oooooooooooooo...",
        "...dddddddddddddd...",
        "....L.L......L.L....",
        "....L.L......L.L....",
    ]

    public func frame(mode: PetMode, tick: Int) -> Grid {
        var c = Canvas(width: width, height: height)
        let top = Skins.headroom + Skins.hop(mode, tick)
        let x = 2
        c.stamp(Self.body, col: x, row: top) { ch in
            switch ch {
            case "E": return "o"
            case "A", "L": return nil
            default: return ch
            }
        }
        c.eyes([x + 5, x + 13], row: top + 2, look: Skins.look(mode, tick), ink: "e", shine: false)

        // Arms: rows 5-6 at rest; one lifts at a time while working, both wave when happy.
        let half = tick % 8 < 4
        let leftUp = (mode == .working && half) || mode == .happy
        let rightUp = (mode == .working && !half) || mode == .happy
        let wave = mode == .happy && half ? 1 : 0
        for (col, up) in [(x + 1, leftUp), (x + 18, rightUp)] {
            // A raised arm reaches down to the shoulder at row 5 so it stays attached.
            let rows = up ? Array((top + 3 + wave)...(top + 5)) : [top + 5, top + 6]
            for row in rows { c.put(col, row, "o") }
        }

        // Legs: marching in place while working.
        for (i, col) in [x + 4, x + 6, x + 13, x + 15].enumerated() {
            let lifted = mode == .working && (i % 2 == 0) == half
            c.put(col, top + 9, "d")
            if !lifted { c.put(col, top + 10, "d") }
        }
        c.extras(mode, tick: tick)
        return c.grid
    }
}

public struct SlimeSkin: PetSkin {
    public let id = "slime"
    public let width = 24
    public let height = Skins.headroom + 12

    public static let body: [String] = [
        "......kkkkkkkk......",
        "....kkggggggggkk....",
        "...kggggggggggggk...",
        "..kggggggggggggggk..",
        "..kggggggggggggggk..",
        ".kggggggggggggggggk.",
        ".kggggEEggggEEggggk.",
        ".kggggEEggggEEggggk.",
        ".kggppgggkkgggppggk.",
        "kggggggggggggggggggk",
        "kGGGGGGGGGGGGGGGGGGk",
        "kkkkkkkkkkkkkkkkkkkk",
    ]

    public func frame(mode: PetMode, tick: Int) -> Grid {
        var c = Canvas(width: width, height: height)
        // Breathes once a second while working.
        let bob = mode == .working && tick % 8 >= 4 ? -1 : 0
        let top = Skins.headroom + Skins.hop(mode, tick) + bob
        let x = 2
        c.stamp(Self.body, col: x, row: top) { $0 == "E" ? "g" : $0 }
        c.put(x + 5, top + 2, "w"); c.put(x + 4, top + 3, "w"); c.put(x + 5, top + 3, "w")
        if bob != 0 {
            // Keep the base on the ground while the top rises.
            c.stamp([Self.body[11]], col: x, row: Skins.headroom + 11)
            c.stamp([Self.body[10]], col: x, row: Skins.headroom + 10)
        }
        c.eyes([x + 6, x + 12], row: top + 6, look: Skins.look(mode, tick), ink: "k", shine: true)
        c.extras(mode, tick: tick)
        return c.grid
    }
}
