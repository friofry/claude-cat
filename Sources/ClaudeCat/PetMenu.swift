import AppKit
import ClaudeCatCore

/// The pet's right-click menu.
@MainActor
struct PetMenu {
    var records: [SessionRecord]
    var skinId: String
    var pixel: CGFloat
    var openSession: (String) -> Void
    var selectSkin: (String) -> Void
    var selectSize: (CGFloat) -> Void
    var hideCards: () -> Void
    var forgetSessions: () -> Void
    var backToDock: () -> Void

    func build() -> NSMenu {
        let menu = NSMenu()
        if records.isEmpty {
            menu.addItem(withTitle: Strings.Menu.noSessions, action: nil, keyEquivalent: "")
        }
        for record in records.prefix(12) {
            let id = record.id
            menu.addItem(ActionItem("\(Strings.title(record)) — \(Strings.state(record.state))") { openSession(id) })
        }
        menu.addItem(.separator())

        let skins = NSMenu()
        for skin in Skins.all {
            let id = skin.id
            skins.addItem(ActionItem(Strings.skin(id), checked: id == skinId) { selectSkin(id) })
        }
        menu.addItem(withTitle: Strings.Menu.pet, action: nil, keyEquivalent: "").submenu = skins

        let sizes = NSMenu()
        for size in Strings.sizes {
            sizes.addItem(ActionItem(size.name, checked: size.pixel == pixel) { selectSize(size.pixel) })
        }
        menu.addItem(withTitle: Strings.Menu.size, action: nil, keyEquivalent: "").submenu = sizes

        menu.addItem(ActionItem(Strings.Menu.hideCards, action: hideCards))
        menu.addItem(ActionItem(Strings.Menu.forgetSessions, action: forgetSessions))
        menu.addItem(ActionItem(Strings.Menu.backToDock, action: backToDock))
        menu.addItem(.separator())
        menu.addItem(ActionItem(Strings.Menu.quit) { NSApp.terminate(nil) })
        return menu
    }
}

/// A menu item that runs a closure.
final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, checked: Bool = false, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
        state = checked ? .on : .off
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func fire() { handler() }
}
