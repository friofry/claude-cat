import AppKit
import ClaudeCatCore

/// Renders every skin in every mode into one PNG, for previews and for eyeballing sprite changes.
enum SheetRenderer {
    static func render(to path: String, pixel: CGFloat = 6, ticks: [Int] = [1, 4]) {
        let modes = PetMode.allCases
        let cellW = CGFloat(Skins.all.map(\.width).max() ?? 24) * pixel + 12
        let cellH = CGFloat(Skins.all.map(\.height).max() ?? 25) * pixel + 12
        let size = NSSize(width: cellW * CGFloat(modes.count * ticks.count) + 12,
                          height: cellH * CGFloat(Skins.all.count) + 12)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let flip = NSAffineTransform()
        flip.translateX(by: 0, yBy: size.height)
        flip.scaleX(by: 1, yBy: -1)
        flip.concat()
        NSColor(white: 0.93, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        for (row, skin) in Skins.all.enumerated() {
            var x: CGFloat = 12
            let y = CGFloat(row + 1) * cellH - CGFloat(skin.height) * pixel
            for mode in modes {
                for tick in ticks {
                    PetView.drawGrid(skin.frame(mode: mode, tick: tick), pixel: pixel, origin: NSPoint(x: x, y: y))
                    x += cellW
                }
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
