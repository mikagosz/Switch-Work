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

        let icon = isOn ? onIcon : offIcon
        button.image = icon
        // Should the symbol ever fail to load, the button would sit in the menu bar as an
        // empty square: nothing to see, nothing to explain it, and the menu reachable only
        // by guessing where to click. A word is worse looking and far better than that.
        button.title = icon == nil
            ? (isOn ? String(localized: "On") : String(localized: "Off"))
            : ""
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

        // Launch at login. State comes from SMAppService on every menu open, never from
        // a cached flag — macOS lets the user revoke a login item in System Settings
        // without telling the app, and a stale tick would be worse than no tick.
        let login = item(String(localized: "Open at login"), #selector(toggleLoginItem))
        login.state = LoginItem.isEnabled ? .on : .off
        if LoginItem.needsApproval {
            // Not the same as being on: registration went through, but the user still
            // has to allow it. Saying "on" here would promise something that will not
            // happen at the next restart.
            login.state = .mixed
            login.toolTip = String(localized: "Waiting for your approval in System Settings → General → Login Items.")
        }
        menu.addItem(login)

        menu.addItem(.separator())

        // The version belongs somewhere the user actually looks. It was only in the
        // "my own time" dialog, which meant reading it required opening a prompt about
        // something else entirely — so in practice nobody ever saw it.
        if let versionLine {
            let stamp = NSMenuItem(title: versionLine, action: nil, keyEquivalent: "")
            stamp.isEnabled = false
            menu.addItem(stamp)
        }

        menu.addItem(item(String(localized: "Quit Switch-Work"), #selector(quit), key: "q"))
    }

    /// Flips the login item and says out loud when the system refused.
    ///
    /// A silent refusal is the bad case here, exactly like with the sleep block: the tick
    /// would stay off, the user would shrug, and the app would quietly not start at the
    /// next login.
    @objc private func toggleLoginItem() {
        let turningOn = !LoginItem.isEnabled
        if let problem = LoginItem.enable(turningOn) {
            warn(String(localized: "Launch at login did not change"), problem)
        }
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

    /// Same rule as when turning the switch on: a refusal the user cannot see is worse
    /// than no feature at all.
    @objc private func toggleScreen() {
        let refused = session.setKeepScreenOn(!session.keepScreenOn)
        guard !refused.isEmpty else { return }

        let names = refused.map(\.rawValue).joined(separator: ", ")
        warn(
            String(localized: "Part of the block was refused"),
            String(format: String(localized: "The Mac will stay awake, but macOS refused: %@"), names)
        )
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// What the app reports about itself, read from the bundle it is running from.
    ///
    /// Never a number typed into the code: a hand-written version outlives the build it
    /// described and then quietly lies. `nil` when the keys are missing — the line is
    /// simply left out rather than showing a blank.
    private var versionLine: String? {
        let info = Bundle.main.infoDictionary
        guard let version = info?["CFBundleShortVersionString"] as? String,
              let build = info?["CFBundleVersion"] as? String else { return nil }
        return String(format: String(localized: "Switch-Work %@ (build %@)"), version, build)
    }

    @objc private func customTime() {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
        field.stringValue = String(UserDefaults.standard.integer(forKey: Defaults.lastMinutes))
        field.alignment = .right

        // The one window this app has, so this is where the version belongs. The field
        // keeps the top row; the version sits under it, quiet and right-aligned.
        let versionLine = versionLine
        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: versionLine == nil ? 24 : 46))
        field.frame = NSRect(x: 140, y: accessory.frame.height - 24, width: 80, height: 24)
        accessory.addSubview(field)

        if let versionLine {
            let label = NSTextField(labelWithString: versionLine)
            label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            label.textColor = .secondaryLabelColor
            label.alignment = .right
            label.frame = NSRect(x: 0, y: 0, width: 220, height: 16)
            accessory.addSubview(label)
        }

        let prompt = NSAlert()
        prompt.messageText = String(localized: "How long should Switch-Work stay awake?")
        prompt.informativeText = String(localized: "Enter the time in minutes.")
        prompt.addButton(withTitle: String(localized: "Turn on"))
        prompt.addButton(withTitle: String(localized: "Cancel"))
        prompt.accessoryView = accessory

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
