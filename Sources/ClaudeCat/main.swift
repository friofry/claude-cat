import AppKit

let arguments = CommandLine.arguments
if let flag = arguments.firstIndex(of: "--render-sheet"), flag + 1 < arguments.count {
    MainActor.assumeIsolated { SheetRenderer.render(to: arguments[flag + 1]) }
    exit(0)
}

if let id = Bundle.main.bundleIdentifier,
   NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
