import AppKit

/// Strolls the pet left and right near its home spot every so often while nothing needs attention.
@MainActor
final class PetWalker {
    private(set) var isWalking = false
    private(set) var facingLeft = false
    var onStep: (() -> Void)?
    var onChange: (() -> Void)?

    private let speed: CGFloat = 26
    private let range: CGFloat = 140
    private let stepsPerSecond: Double = 30
    private var target: CGFloat = 0
    private var nextStroll = Date().addingTimeInterval(20)
    private var timer: Timer?

    /// Starts a stroll when `allowed` and one is due; stops one in progress when no longer allowed.
    func consider(_ pet: PetWindow, home: NSPoint, allowed: Bool) {
        if isWalking {
            if !allowed { stop() }
            return
        }
        guard allowed, Date() >= nextStroll else { return }
        let visible = pet.panel.screen?.visibleFrame ?? .zero
        let half = pet.view.petSize.width / 2
        let minX = max(home.x - range, visible.minX + half)
        let maxX = min(home.x + range, visible.maxX - half)
        let x = pet.anchor.x
        guard maxX - minX > 40 else { scheduleNext(); return }
        var goal = CGFloat.random(in: minX...maxX)
        if abs(goal - x) < 30 { goal = x - minX > maxX - x ? minX : maxX }

        target = goal
        facingLeft = goal < x
        isWalking = true
        onChange?()
        timer = Timer.scheduledTimer(withTimeInterval: 1 / stepsPerSecond, repeats: true) { [weak self, weak pet] _ in
            MainActor.assumeIsolated {
                guard let self, let pet else { return }
                self.step(pet)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        scheduleNext()
        guard isWalking else { return }
        isWalking = false
        facingLeft = false
        onChange?()
    }

    private func step(_ pet: PetWindow) {
        var anchor = pet.anchor
        let dx = speed / CGFloat(stepsPerSecond)
        if abs(target - anchor.x) <= dx {
            anchor.x = target
            pet.anchor = anchor
            stop()
        } else {
            anchor.x += facingLeft ? -dx : dx
            pet.anchor = anchor
            onStep?()
        }
    }

    private func scheduleNext() {
        nextStroll = Date().addingTimeInterval(.random(in: 25...60))
    }
}
