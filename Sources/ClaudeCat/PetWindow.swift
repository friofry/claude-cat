import AppKit

extension NSPanel {
    /// A transparent, click-through-where-empty panel that floats above the Dock on every Space.
    static func overlay(size: NSSize = .zero) -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // An accessory app is never active, so a panel that hides on deactivate would never show.
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }
}

/// The pet's window, positioned by its bottom-center "anchor" so resizing keeps the pet in place.
@MainActor
final class PetWindow {
    let panel: NSPanel
    let view: PetView

    init(view: PetView) {
        self.view = view
        panel = .overlay(size: view.petSize)
        panel.hasShadow = false
        panel.contentView = view
    }

    var anchor: NSPoint {
        get { NSPoint(x: panel.frame.midX, y: panel.frame.minY) }
        set { panel.setFrameOrigin(NSPoint(x: newValue.x - view.petSize.width / 2, y: newValue.y)) }
    }

    /// On the top edge of the Dock, near the right side of the main screen.
    var defaultAnchor: NSPoint {
        let visible = NSScreen.main?.visibleFrame ?? .zero
        return NSPoint(x: visible.maxX - 260, y: visible.minY - view.pixel)
    }

    /// Applies a skin or size change without moving the pet's feet.
    func resize(_ change: () -> Void) {
        let keep = anchor
        change()
        panel.setContentSize(view.petSize)
        view.frame = NSRect(origin: .zero, size: view.petSize)
        anchor = keep
        view.needsDisplay = true
    }

    func show(at anchor: NSPoint) {
        self.anchor = anchor
        panel.orderFrontRegardless()
    }
}
