import AppKit

/// New chat, voice input and show/hide cards, shown while the pointer is over the pet.
@MainActor
final class Toolbar {
    static let size = NSSize(width: 132, height: 40)

    let panel: NSPanel
    var onNewChat: (() -> Void)?
    var onVoice: (() -> Void)?
    var onToggleCards: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    private(set) var isShown = false

    private let root = HoverView()
    private let pill = PillView()
    private let newChat = CircleButton(symbol: "square.and.pencil", size: 32, filled: false)
    private let voice = CircleButton(symbol: "waveform", size: 32, filled: false)
    private let toggle = CircleButton(symbol: "chevron.down", size: 32, filled: false)

    init() {
        panel = .overlay(size: Self.size)
        panel.hasShadow = true
        root.frame = NSRect(origin: .zero, size: Self.size)
        pill.frame = root.bounds
        panel.contentView = root
        root.addSubview(pill)

        let buttons = [newChat, voice, toggle]
        let spacing = (Self.size.width - 12 - 32 * 3) / 2
        for (i, button) in buttons.enumerated() {
            button.setFrameOrigin(NSPoint(x: 6 + CGFloat(i) * (32 + spacing), y: (Self.size.height - 32) / 2))
            pill.addSubview(button)
        }
        for i in 1..<buttons.count {
            let line = NSBox(frame: NSRect(x: 6 + CGFloat(i) * (32 + spacing) - spacing / 2, y: 11, width: 1, height: 18))
            line.boxType = .separator
            pill.addSubview(line)
        }
        newChat.action = { [weak self] in self?.onNewChat?() }
        voice.action = { [weak self] in self?.onVoice?() }
        toggle.action = { [weak self] in self?.onToggleCards?() }
        root.onHover = { [weak self] inside in self?.onHover?(inside) }
    }

    /// The chevron points up to bring hidden cards back and carries their count.
    func configure(cardsHidden: Bool, hiddenCount: Int) {
        toggle.symbol = cardsHidden ? "chevron.up" : "chevron.down"
        toggle.badge = cardsHidden ? hiddenCount : 0
    }

    func show(at origin: NSPoint, parent: NSWindow) {
        panel.setFrameOrigin(origin)
        guard !isShown else { return }
        isShown = true
        parent.addChildWindow(panel, ordered: .above)
        panel.orderFrontRegardless()
    }

    func hide() {
        guard isShown else { return }
        isShown = false
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }
}
