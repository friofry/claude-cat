import AppKit
import ClaudeCatCore
import QuartzCore

/// One session card: title, a live subtitle, and hover buttons to dismiss or open.
struct CardItem: Equatable {
    let id: String
    let kind: BoardCard.Kind
    let title: String
    let subtitle: String
}

/// Cards stacked above the pet, most urgent on top, like the Codex pet's chat stack.
@MainActor
final class CardStack {
    var onOpen: ((String) -> Void)?
    var onDismiss: ((String) -> Void)?
    private var cards: [String: Card] = [:]
    private let gap: CGFloat = 6

    func update(_ items: [CardItem], above pet: NSWindow) {
        let ids = Set(items.map(\.id))
        for (id, card) in cards where !ids.contains(id) {
            card.close()
            cards[id] = nil
        }

        let visible = pet.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var y = pet.frame.maxY + 2
        for item in items.reversed() {
            let card = cards[item.id] ?? makeCard(item.id)
            card.configure(item)
            let size = card.panel.frame.size
            var x = pet.frame.midX - size.width / 2
            x = max(visible.minX + 4, min(x, visible.maxX - size.width - 4))
            card.place(at: NSPoint(x: x, y: y - Card.margin), parent: pet)
            y += size.height - Card.margin * 2 + gap
        }
    }

    private func makeCard(_ id: String) -> Card {
        let card = Card()
        card.onOpen = { [weak self] in self?.onOpen?(id) }
        card.onDismiss = { [weak self] in self?.onDismiss?(id) }
        cards[id] = card
        return card
    }
}

@MainActor
final class Card: NSObject {
    static let margin: CGFloat = 9
    static let width: CGFloat = 300

    let panel: NSPanel
    var onOpen: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let root = HoverView()
    private let effect = NSVisualEffectView()
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let subtitle = NSTextField(labelWithString: "")
    private let closeButton = CircleButton(symbol: "xmark", size: 20)
    private let openButton = CircleButton(symbol: "arrow.turn.down.left", size: 30)
    private var item: CardItem?
    private var shown = false

    private let padH: CGFloat = 18
    private let padV: CGFloat = 11

    override init() {
        panel = .overlay()
        super.init()
        panel.hasShadow = true
        panel.contentView = root

        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        root.addSubview(effect)

        title.font = .boldSystemFont(ofSize: 13)
        title.textColor = .labelColor
        subtitle.font = .systemFont(ofSize: 12.5)
        subtitle.textColor = .secondaryLabelColor
        for field in [title, subtitle] {
            field.lineBreakMode = .byTruncatingTail
            field.maximumNumberOfLines = 1
            effect.addSubview(field)
        }
        subtitle.wantsLayer = true
        icon.imageScaling = .scaleProportionallyUpOrDown
        effect.addSubview(icon)
        effect.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(clicked)))

        closeButton.action = { [weak self] in self?.onDismiss?() }
        openButton.action = { [weak self] in self?.onOpen?() }
        root.addSubview(openButton)
        root.addSubview(closeButton)
        setButtonsVisible(false)
        root.onHover = { [weak self] inside in self?.setButtonsVisible(inside) }
    }

    func configure(_ new: CardItem) {
        guard new != item else { return }
        item = new

        let symbol: String?
        let tint: NSColor
        switch new.kind {
        case .done: symbol = "checkmark.circle.fill"; tint = .systemGreen
        case .waiting: symbol = "exclamationmark.circle.fill"; tint = .systemOrange
        case .working: symbol = nil; tint = .clear
        }
        let iconSize: CGFloat = 15
        if let symbol {
            let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
                .applying(.init(paletteColors: [.white, tint]))
            icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        }
        icon.isHidden = symbol == nil
        title.stringValue = new.title
        subtitle.stringValue = new.subtitle

        let lineH = ceil(title.fittingSize.height)
        let subH = ceil(subtitle.fittingSize.height)
        let height = padV * 2 + lineH + 2 + subH
        let m = Self.margin
        panel.setContentSize(NSSize(width: Self.width + m * 2, height: height + m * 2))
        root.frame = NSRect(x: 0, y: 0, width: Self.width + m * 2, height: height + m * 2)
        effect.frame = NSRect(x: m, y: m, width: Self.width, height: height)

        let titleY = height - padV - lineH
        let textX = symbol == nil ? padH : padH + iconSize + 6
        icon.frame = NSRect(x: padH, y: titleY + (lineH - iconSize) / 2, width: iconSize, height: iconSize)
        title.frame = NSRect(x: textX, y: titleY, width: Self.width - textX - padH, height: lineH)
        subtitle.frame = NSRect(x: padH, y: padV, width: Self.width - padH * 2, height: subH)

        closeButton.setFrameOrigin(NSPoint(x: m - 7, y: m + height - 13))
        openButton.setFrameOrigin(NSPoint(x: m + Self.width - 30 - 10, y: m + (height - 30) / 2))

        let radius = min(22, height / 2)
        effect.maskImage = NSImage(size: effect.frame.size, flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        panel.invalidateShadow()
        setShimmer(new.kind == .working)
    }

    func place(at origin: NSPoint, parent: NSWindow) {
        if !shown {
            shown = true
            panel.setFrameOrigin(origin)
            panel.alphaValue = 0
            parent.addChildWindow(panel, ordered: .above)
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().alphaValue = 1
            }
        } else if panel.frame.origin != origin {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().setFrameOrigin(origin)
            }
        }
    }

    func close() {
        let panel = self.panel
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated {
                panel.parent?.removeChildWindow(panel)
                panel.orderOut(nil)
            }
        })
    }

    private func setButtonsVisible(_ visible: Bool) {
        closeButton.isHidden = !visible
        openButton.isHidden = !visible
    }

    /// A soft highlight sweeping across the subtitle while the session works.
    private func setShimmer(_ on: Bool) {
        guard let layer = subtitle.layer else { return }
        guard on else { layer.mask = nil; return }
        let mask = CAGradientLayer()
        mask.frame = layer.bounds
        mask.startPoint = CGPoint(x: 0, y: 0.5)
        mask.endPoint = CGPoint(x: 1, y: 0.5)
        let dim = NSColor(white: 1, alpha: 0.45).cgColor
        mask.colors = [dim, NSColor.white.cgColor, dim]
        mask.locations = [0, 0.1, 0.2]
        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = [-0.3, -0.15, 0]
        sweep.toValue = [1, 1.15, 1.3]
        sweep.duration = 2.2
        sweep.repeatCount = .infinity
        mask.add(sweep, forKey: "shimmer")
        layer.mask = mask
    }

    @objc private func clicked() {
        onOpen?()
    }
}

final class HoverView: NSView {
    var onHover: ((Bool) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}

final class CircleButton: NSView {
    var action: (() -> Void)?
    private let symbol: String

    init(symbol: String, size: CGFloat) {
        self.symbol = symbol
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
        NSColor.windowBackgroundColor.withAlphaComponent(0.95).setFill()
        circle.fill()
        NSColor.separatorColor.setStroke()
        circle.lineWidth = 0.5
        circle.stroke()
        let config = NSImage.SymbolConfiguration(pointSize: bounds.width * 0.42, weight: .bold)
            .applying(.init(paletteColors: [.secondaryLabelColor]))
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
        let s = image.size
        image.draw(in: NSRect(x: (bounds.width - s.width) / 2, y: (bounds.height - s.height) / 2, width: s.width, height: s.height))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { action?() }
    }
}
