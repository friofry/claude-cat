import AppKit

enum ComposerTarget: Equatable {
    case newChat
    case session(id: String, title: String, working: Bool)
}

/// A panel that takes keyboard focus without being a regular window.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// A one-line message field that opens next to the pet.
@MainActor
final class Composer: NSObject, NSTextFieldDelegate {
    static let size = NSSize(width: 320, height: 44)

    let panel: KeyPanel
    var onSubmit: ((String, ComposerTarget) -> Void)?
    var onClose: (() -> Void)?
    private(set) var target: ComposerTarget?
    var isOpen: Bool { target != nil }

    private let pill = PillView()
    private let field = NSTextField()
    private let mic = CircleButton(symbol: "mic.fill", size: 28, filled: false)
    private let send = CircleButton(symbol: "arrow.up.circle.fill", size: 30, filled: false)

    override init() {
        panel = KeyPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.configureAsOverlay()
        panel.hasShadow = true
        pill.frame = NSRect(origin: .zero, size: Self.size)
        panel.contentView = pill

        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13)
        field.lineBreakMode = .byTruncatingHead
        field.cell?.usesSingleLineMode = true
        field.delegate = self
        field.frame = NSRect(x: 16, y: (Self.size.height - 18) / 2, width: Self.size.width - 16 - 70, height: 18)
        mic.setFrameOrigin(NSPoint(x: Self.size.width - 68, y: 8))
        send.setFrameOrigin(NSPoint(x: Self.size.width - 38, y: 7))
        for view in [field, mic, send] as [NSView] { pill.addSubview(view) }
        mic.action = { [weak self] in self?.startDictation() }
        send.action = { [weak self] in self?.submit() }

        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.field.stringValue.isEmpty else { return }
                self.close()
            }
        }
    }

    func open(_ target: ComposerTarget, placeholder: String, parent: NSWindow, dictate: Bool) {
        self.target = target
        field.placeholderString = placeholder
        field.stringValue = ""
        field.isEditable = true
        if panel.parent == nil { parent.addChildWindow(panel, ordered: .above) }
        // Typing needs the app to be active; it gives focus back when the field closes.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        if dictate {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.startDictation() }
        }
    }

    func place(at origin: NSPoint) {
        panel.setFrameOrigin(origin)
    }

    /// Shows a short confirmation in place of the text, then closes.
    func finish(_ note: String) {
        field.stringValue = ""
        field.placeholderString = note
        field.isEditable = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in self?.close() }
    }

    func close() {
        guard target != nil else { return }
        target = nil
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        NSApp.hide(nil)
        onClose?()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)): submit(); return true
        case #selector(NSResponder.cancelOperation(_:)): close(); return true
        default: return false
        }
    }

    private func submit() {
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let target else { return }
        onSubmit?(text, target)
    }

    /// macOS dictation into the field; the system asks to turn it on the first time.
    private func startDictation() {
        panel.makeFirstResponder(field)
        NSApp.sendAction(Selector(("startDictation:")), to: nil, from: field)
    }
}
