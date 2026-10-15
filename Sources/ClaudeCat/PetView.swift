import AppKit
import ClaudeCatCore

final class PetView: NSView {
    static let palette: [Character: NSColor] = [
        "k": NSColor(srgbRed: 0.17, green: 0.11, blue: 0.08, alpha: 1),
        "o": NSColor(srgbRed: 0.85, green: 0.47, blue: 0.34, alpha: 1),
        "d": NSColor(srgbRed: 0.70, green: 0.36, blue: 0.25, alpha: 1),
        "l": NSColor(srgbRed: 0.94, green: 0.72, blue: 0.60, alpha: 1),
        "p": NSColor(srgbRed: 0.96, green: 0.60, blue: 0.62, alpha: 1),
        "n": NSColor(srgbRed: 0.72, green: 0.30, blue: 0.33, alpha: 1),
        "P": NSColor(srgbRed: 0.98, green: 0.86, blue: 0.78, alpha: 1),
        "g": NSColor(srgbRed: 0.53, green: 0.84, blue: 0.70, alpha: 1),
        "G": NSColor(srgbRed: 0.33, green: 0.66, blue: 0.54, alpha: 1),
        "w": NSColor.white,
        "e": NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1),
        "r": NSColor(srgbRed: 0.90, green: 0.28, blue: 0.30, alpha: 1),
        "y": NSColor(srgbRed: 0.98, green: 0.80, blue: 0.25, alpha: 1),
        "z": NSColor(srgbRed: 0.45, green: 0.55, blue: 0.85, alpha: 1),
    ]

    var skin: PetSkin = Skins.all[0]
    var pixel: CGFloat = 3.5
    var mode: PetMode = .sleeping
    var tick = 0 { didSet { needsDisplay = true } }

    var onClick: (() -> Void)?
    var onMoved: (() -> Void)?
    var onMenu: ((NSEvent) -> Void)?

    private var dragStart = NSPoint.zero
    private var windowStart = NSPoint.zero
    private var dragged = false

    var petSize: NSSize {
        NSSize(width: CGFloat(skin.width) * pixel, height: CGFloat(skin.height) * pixel)
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Self.drawGrid(skin.frame(mode: mode, tick: tick), pixel: pixel)
    }

    static func drawGrid(_ grid: Grid, pixel: CGFloat, origin: NSPoint = .zero) {
        NSGraphicsContext.current?.shouldAntialias = false
        for (r, row) in grid.enumerated() {
            for (c, ch) in row.enumerated() {
                guard let ch, let color = palette[ch] else { continue }
                color.setFill()
                NSRect(x: origin.x + CGFloat(c) * pixel, y: origin.y + CGFloat(r) * pixel, width: pixel, height: pixel).fill()
            }
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        windowStart = window?.frame.origin ?? .zero
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        let p = NSEvent.mouseLocation
        let dx = p.x - dragStart.x, dy = p.y - dragStart.y
        if abs(dx) + abs(dy) > 3 { dragged = true }
        if dragged { window?.setFrameOrigin(NSPoint(x: windowStart.x + dx, y: windowStart.y + dy)) }
    }

    override func mouseUp(with event: NSEvent) {
        if dragged { onMoved?() } else { onClick?() }
    }

    override func rightMouseDown(with event: NSEvent) {
        onMenu?(event)
    }
}
