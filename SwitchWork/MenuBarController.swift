//
//  MenuBarController.swift
//  Switch-Work
//
//  The menu bar icon and all of the app's controls.
//

import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {

    private let session = WakeSession.shared
    private var statusItem: NSStatusItem?

    /// Icons built once. The app sits in the menu bar for days on end — there is no
    /// reason to create an image on every refresh.
    private lazy var offIcon: NSImage? = StatusIcon.toggle(isOn: false)
    private lazy var onIcon: NSImage? = StatusIcon.toggle(isOn: true)
    private var lastIsOn: Bool?

    override init() {
        super.init()

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        self.statusItem = statusItem

        session.onChange = { [weak self] in self?.refreshIcon() }
        refreshIcon()
    }

    // MARK: - Icon

    private func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let isOn = session.isOn
        guard lastIsOn != isOn else { return }
        lastIsOn = isOn
        button.image = isOn ? onIcon : offIcon
    }

    // MARK: - Menu

    /// The menu is rebuilt on every open — that way the app needs no timer ticking once
    /// a second just to keep the remaining-time line up to date.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let isOn = session.isOn

        let header = NSMenuItem(title: stateLine(), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        if isOn {
            menu.addItem(item(String(localized: "Turn off now"), #selector(turnOff)))
            menu.addItem(.separator())
        }

        menu.addItem(item(
            isOn ? String(localized: "Set to 1 hour") : String(localized: "Turn on for 1 hour"),
            #selector(oneHour)))
        menu.addItem(item(
            isOn ? String(localized: "Set to 2 hours") : String(localized: "Turn on for 2 hours"),
            #selector(twoHours)))
        menu.addItem(item(
            isOn ? String(localized: "Set my own time…") : String(localized: "Turn on for my own time…"),
            #selector(customTime)))

        menu.addItem(.separator())

        let screen = item(String(localized: "Keep the screen on too"), #selector(toggleScreen))
        screen.state = session.keepScreenOn ? .on : .off
        menu.addItem(screen)

        menu.addItem(.separator())
        menu.addItem(item(String(localized: "Quit Switch-Work"), #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func stateLine() -> String {
        guard session.isOn else { return String(localized: "Switch-Work is off") }
        return String(
            format: String(localized: "Awake — %@ left"),
            TimeFormat.describe(session.remaining)
        )
    }

    // MARK: - Actions

    @objc private func oneHour() { turnOn(minutes: 60) }
    @objc private func twoHours() { turnOn(minutes: 120) }
    @objc private func turnOff() { session.turnOff() }

    @objc private func toggleScreen() {
        session.keepScreenOn.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func customTime() {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
        field.stringValue = String(UserDefaults.standard.integer(forKey: Defaults.lastMinutes))
        field.alignment = .right

        let prompt = NSAlert()
        prompt.messageText = String(localized: "How long should Switch-Work stay awake?")
        prompt.informativeText = String(localized: "Enter the time in minutes.")
        prompt.addButton(withTitle: String(localized: "Turn on"))
        prompt.addButton(withTitle: String(localized: "Cancel"))
        prompt.accessoryView = field

        NSApp.activate(ignoringOtherApps: true)
        prompt.window.initialFirstResponder = field
        guard prompt.runModal() == .alertFirstButtonReturn else { return }

        guard let minutes = TimeFormat.minutes(from: field.stringValue) else {
            warn(
                String(localized: "That is not a number of minutes"),
                String(format: String(localized: "Enter a whole number from 1 to %lld."), TimeFormat.maxMinutes)
            )
            return
        }

        UserDefaults.standard.set(minutes, forKey: Defaults.lastMinutes)
        turnOn(minutes: minutes)
    }

    /// Starts a session and — when the system refused something — says so out loud.
    /// A silent refusal would be the worst case: the icon glows and the Mac sleeps anyway.
    private func turnOn(minutes: Int) {
        let refused = session.turnOn(minutes: minutes)
        guard !refused.isEmpty else { return }

        let names = refused.map(\.rawValue).joined(separator: ", ")
        if refused.contains(.system) {
            warn(
                String(localized: "macOS refused to block sleep"),
                String(format: String(localized: "Switch-Work stays off — without this block nothing would be protected. Refused: %@"), names)
            )
        } else {
            warn(
                String(localized: "Part of the block was refused"),
                String(format: String(localized: "The Mac will stay awake, but macOS refused: %@"), names)
            )
        }
    }

    private func warn(_ title: String, _ body: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: String(localized: "OK"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
