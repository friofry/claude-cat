import AppKit
import ClaudeCatCore

/// Wires the session store to the pet and its cards.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let petView = PetView()
    private lazy var pet = PetWindow(view: petView)
    private let cards = CardStack()
    private let store = SessionStore()
    private let board = Board()
    private let desktop = DesktopSessionIndex()
    private let preferences = Preferences()
    private var watcher: DirectoryWatcher?

    private var records: [SessionRecord] = []
    private var seen: [String: String] = [:]
    private var dismissed: [String: String] = [:]
    private var happyUntil: Double = 0
    private var topCard: String?

    private let claudeBundleId = "com.anthropic.claudefordesktop"
    private let happyDuration: Double = 30

    func applicationDidFinishLaunching(_ notification: Notification) {
        petView.skin = Skins.named(preferences.skinId)
        petView.pixel = preferences.pixel
        pet.show(at: preferences.anchor ?? pet.defaultAnchor)

        petView.onClick = { [weak self] in self?.openSession(self?.topCard ?? self?.records.first?.id) }
        petView.onMoved = { [weak self] in self?.savePosition() }
        petView.onMenu = { [weak self] event in self?.showMenu(event) }
        cards.onOpen = { [weak self] id in self?.openSession(id) }
        cards.onDismiss = { [weak self] id in self?.dismiss(id) }

        store.createDirectory()
        records = store.loadAll(now: now)
        for r in records { seen[r.id] = r.stateKey }
        render()

        watcher = DirectoryWatcher(store.directory) { [weak self] in self?.reload() }
        // Cards expire and the pet falls asleep with time, not only with file changes.
        Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        Timer.scheduledTimer(withTimeInterval: 1 / Skins.fps, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.petView.tick += 1 }
        }
    }

    private var now: Double { Date().timeIntervalSince1970 }

    private func reload() {
        records = store.loadAll(now: now)
        for r in records where seen[r.id] != r.stateKey {
            seen[r.id] = r.stateKey
            if r.state == .done { happyUntil = now + happyDuration }
        }
        let alive = Set(records.map(\.id))
        seen = seen.filter { alive.contains($0.key) }
        dismissed = dismissed.filter { alive.contains($0.key) }
        render()
    }

    private func render() {
        let boardCards = board.cards(for: records, dismissed: dismissed, now: now)
        topCard = boardCards.first?.record.id
        let items = boardCards.map {
            CardItem(id: $0.record.id, kind: $0.kind, title: Strings.title($0.record), subtitle: Strings.subtitle($0))
        }
        cards.update(items, above: pet.panel)
        petView.mode = board.mode(for: records, now: now, happyUntil: happyUntil)
    }

    private func dismiss(_ id: String) {
        if let record = records.first(where: { $0.id == id }) { dismissed[id] = record.stateKey }
        render()
    }

    /// Opens the session in Claude Desktop, or brings Claude forward for sessions outside it.
    private func openSession(_ id: String?) {
        if let id, records.first(where: { $0.id == id })?.state == .done { dismiss(id) }
        let desktop = self.desktop
        let bundleId = claudeBundleId
        // The lookup reads Claude Desktop's session files, so it stays off the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            let link = id.flatMap { desktop.deepLink(forCliSession: $0) }
            DispatchQueue.main.async {
                if let link {
                    NSWorkspace.shared.open(link)
                } else if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
                }
            }
        }
    }

    private func showMenu(_ event: NSEvent) {
        let menu = PetMenu(
            records: records,
            skinId: petView.skin.id,
            pixel: petView.pixel,
            openSession: { [weak self] id in self?.openSession(id) },
            selectSkin: { [weak self] id in
                self?.preferences.skinId = id
                self?.pet.resize { self?.petView.skin = Skins.named(id) }
                self?.savePosition()
            },
            selectSize: { [weak self] pixel in
                self?.preferences.pixel = pixel
                self?.pet.resize { self?.petView.pixel = pixel }
                self?.savePosition()
            },
            hideCards: { [weak self] in
                guard let self else { return }
                for r in records { dismissed[r.id] = r.stateKey }
                render()
            },
            forgetSessions: { [weak self] in self?.store.clear() },
            backToDock: { [weak self] in
                guard let self else { return }
                pet.anchor = pet.defaultAnchor
                savePosition()
            })
        NSMenu.popUpContextMenu(menu.build(), with: event, for: petView)
    }

    private func savePosition() {
        preferences.anchor = pet.anchor
        render()
    }
}
