import AppKit

/// The pet's skin, size and position, kept in UserDefaults.
struct Preferences {
    private let defaults = UserDefaults.standard

    var skinId: String? {
        get { defaults.string(forKey: "skin") }
        nonmutating set { defaults.set(newValue, forKey: "skin") }
    }

    var pixel: CGFloat {
        get { let value = defaults.double(forKey: "pixel"); return value > 0 ? value : 3.5 }
        nonmutating set { defaults.set(Double(newValue), forKey: "pixel") }
    }

    /// The saved bottom-center of the pet, if it is still on a connected screen.
    var anchor: NSPoint? {
        get {
            guard let saved = defaults.string(forKey: "anchor") else { return nil }
            let point = NSPointFromString(saved)
            return NSScreen.screens.contains { $0.frame.insetBy(dx: -20, dy: -20).contains(point) } ? point : nil
        }
        nonmutating set { defaults.set(newValue.map(NSStringFromPoint), forKey: "anchor") }
    }
}
