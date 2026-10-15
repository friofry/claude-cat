import AppKit
import ClaudeCatCore

/// Wires the session store to the pet, its cards, the toolbar and the composer.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let petView = PetView()
    private lazy var pet = PetWindow(view: petView)
    private let cards = CardStack()
    private let toolbar = Toolbar()
    private let composer = Composer()
    private let walker = PetWalker()
    private let store = SessionStore()
    private let inbox = Inbox()
    private let listeners = ListenerRegistry()
    private let board = Board()
    private let desktop = DesktopSessionIndex()
    private let live = LiveSessionPoller()
    private let preferences = Preferences()
    private var watcher: DirectoryWatcher?

    private var records: [SessionRecord] = []
    private var seen: [String: String] = [:]
    private var dismissed: [String: String] = [:]
    private var happyUntil: Double = 0
    private var topCard: String?
    private var boardMode: PetMode = .sleeping
    private var petHovered = false
    private var toolbarHovered = false
    private var hideToolbar: DispatchWorkItem?

    private let claudeBundleId = "com.anthropic.claudefordesktop"
    private let happyDuration: Double = 30

    func applicationDidFinishLaunching(_ notification: Notification) {
        petView.skin = Skins.named(preferences.skinId)
        petView.pixel = preferences.pixel
        pet.show(at: home)

        petView.onClick = { [weak self] in self?.openSession(self?.topCard ?? self?.records.first?.id) }
        petView.onMoved = { [weak self] in self?.savePosition() }
        petView.onMenu = { [weak self] event in self?.showMenu(event) }
        petView.onHover = { [weak self] inside in self?.petHovered = inside; self?.hoverChanged() }
        toolbar.onHover = { [weak self] inside in self?.toolbarHovered = inside; self?.hoverChanged() }
        toolbar.onNewChat = { [weak self] in self?.compose(.newChat, dictate: false) }
        toolbar.onVoice = { [weak self] in self?.compose(.newChat, dictate: true) }
        toolbar.onToggleCards = { [weak self] in self?.toggleCards() }
        cards.onAction = { [weak self] id, action in self?.perform(action, on: id) }
        composer.onSubmit = { [weak self] text, target in self?.submit(text, to: target) }
        composer.onClose = { [weak self] in self?.hoverChanged() }
        walker.onStep = { [weak self] in self?.layout() }
        walker.onChange = { [weak self] in self?.updatePet() }
        live.onUpdate = { [weak self] in self?.reload() }

        store.createDirectory()
        records = loadRecords()
        for r in records { seen[r.id] = r.stateKey }
        render()
        live.start(every: 5)

        watcher = DirectoryWatcher(store.directory) { [weak self] in self?.reload() }
        // Cards expire, the pet falls asleep and strolls with time, not only with file changes.
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        Timer.scheduledTimer(withTimeInterval: 1 / Skins.fps, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.petView.tick += 1 }
        }
    }

    private var now: Double { Date().timeIntervalSince1970 }
    private var home: NSPoint { preferences.anchor ?? pet.defaultAnchor }

    // MARK: - State

    /// Hook records reconciled with the CLI's live session list.
    private func loadRecords() -> [SessionRecord] {
        LiveSessions.merge(store.loadAll(now: now), live: live.sessions, takenAt: live.takenAt)
    }

    private func reload() {
        records = loadRecords()
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
        boardMode = board.mode(for: records, now: now, happyUntil: happyUntil)
        walker.consider(pet, home: home, allowed: boardMode == .idle && !petHovered && !toolbarHovered && !composer.isOpen)
        updatePet()
        layout()
    }

    private func updatePet() {
        petView.mode = walker.isWalking ? .walking : boardMode
        petView.facingLeft = walker.facingLeft
    }

    /// Toolbar and composer go below the pet when there is room, else above it; cards always stack above.
    private func layout() {
        let boardCards = board.cards(for: records, dismissed: dismissed, now: now)
        topCard = boardCards.first?.record.id
        let hidden = preferences.cardsHidden
        toolbar.configure(cardsHidden: hidden, hiddenCount: boardCards.count)

        let frame = pet.panel.frame
        let visible = pet.panel.screen?.visibleFrame ?? .zero
        let below = frame.minY - visible.minY >= Toolbar.size.height + Composer.size.height + 12
        var aboveY = frame.maxY + 2
        var belowY = frame.minY - 2
        func origin(for size: NSSize) -> NSPoint {
            let x = max(visible.minX + 4, min(frame.midX - size.width / 2, visible.maxX - size.width - 4))
            if below {
                belowY -= size.height
                defer { belowY -= 4 }
                return NSPoint(x: x, y: belowY)
            }
            defer { aboveY += size.height + 4 }
            return NSPoint(x: x, y: aboveY)
        }
        // The toolbar's slot is kept even while it is hidden, so hovering the pet never moves the cards.
        let toolbarOrigin = origin(for: Toolbar.size)
        if toolbar.isShown { toolbar.show(at: toolbarOrigin, parent: pet.panel) }
        if composer.isOpen { composer.place(at: origin(for: Composer.size)) }

        let items = hidden ? [] : boardCards.map { card in
            CardItem(id: card.record.id, kind: card.kind, title: Strings.title(card.record),
                     subtitle: Strings.subtitle(card, pending: card.kind == .working ? inbox.peek(card.record.id) : nil))
        }
        cards.update(items, over: pet.panel, baseY: aboveY + 2)
    }

    // MARK: - Hover

    private func hoverChanged() {
        hideToolbar?.cancel()
        if petHovered || toolbarHovered || composer.isOpen {
            walker.stop()
            if !toolbar.isShown {
                toolbar.show(at: pet.panel.frame.origin, parent: pet.panel)
                layout()
            }
            return
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            toolbar.hide()
            layout()
        }
        hideToolbar = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    // MARK: - Actions

    private func perform(_ action: CardAction, on id: String) {
        guard let record = records.first(where: { $0.id == id }) else { return }
        switch action {
        case .dismiss:
            dismissed[id] = record.stateKey
            render()
        case .open:
            openSession(id)
        case .stop:
            inbox.post(.stop, to: id)
            render()
        case .reply:
            compose(.session(id: id, title: Strings.title(record), working: record.state == .working), dictate: false)
        }
    }

    private func compose(_ target: ComposerTarget, dictate: Bool) {
        let placeholder: String
        switch target {
        case .newChat: placeholder = Strings.Composer.newChat
        case .session(_, let title, let working): placeholder = working ? Strings.Composer.message(title) : Strings.Composer.reply(title)
        }
        walker.stop()
        composer.open(target, placeholder: placeholder, parent: pet.panel, dictate: dictate)
        hoverChanged()
        layout()
    }

    /// A working session gets the message at its next tool step, a finished one through its reply listener.
    /// Without a listener the text goes to the clipboard and the session opens, so nothing typed is lost.
    private func submit(_ text: String, to target: ComposerTarget) {
        switch target {
        case .newChat:
            if let url = newChatLink(text) { NSWorkspace.shared.open(url) }
            composer.close()
        case .session(let id, _, _):
            let working = records.first(where: { $0.id == id })?.state == .working
            if working || listeners.isListening(id) {
                inbox.post(.message(text), to: id)
                composer.finish(Strings.Composer.sent)
            } else {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                openSession(id)
                composer.finish(Strings.Composer.copied)
            }
            render()
        }
    }

    /// `claude://code/new` with the prompt filled in, in the folder of the latest session.
    private func newChatLink(_ prompt: String) -> URL? {
        var components = URLComponents()
        components.scheme = "claude"
        components.host = "code"
        components.path = "/new"
        var query = [URLQueryItem(name: "q", value: prompt), URLQueryItem(name: "source", value: "claude_cat")]
        if let folder = records.first(where: { $0.cwd != nil })?.cwd { query.append(URLQueryItem(name: "folder", value: folder)) }
        components.queryItems = query
        // URLSearchParams reads "+" as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }

    private func toggleCards() {
        preferences.cardsHidden.toggle()
        layout()
    }

    /// Opens the session in Claude Desktop, or brings Claude forward for sessions outside it.
    /// Its card stays; only × hides a card.
    private func openSession(_ id: String?) {
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
        walker.stop()
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
        layout()
    }
}
