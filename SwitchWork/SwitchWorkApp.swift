//
//  SwitchWorkApp.swift
//  Switch-Work
//

import AppKit

@main
enum SwitchWorkMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // .accessory — the app lives in the menu bar only: no Dock icon and no entry in
        // the app switcher.
        app.setActivationPolicy(.accessory)
        _ = delegate            // the delegate has to outlive the start of the event loop
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: Defaults.registered)
        menuBar = MenuBarController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // The blocks die with the process anyway — this is an explicit cleanup, so as not
        // to rely on the system tidying up after us in time.
        WakeSession.shared.turnOff()
    }
}
