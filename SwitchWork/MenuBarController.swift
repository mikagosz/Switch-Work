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

    /// The OFF icon is built once — it never changes. The ON one is redrawn as the
    /// session runs down, because its fill shows how much time is left.
    private lazy var offIcon: NSImage? = StatusIcon.toggle(isOn: false)

    /// What the icon currently shows: the state, and the fill rounded to whole percent.
    ///
    /// Rounding is what keeps this cheap. Without it every tick would redraw an image
    /// identical to the one already on screen; with it the icon is rebuilt at most a
    /// hundred times over the whole session, however long it is.
    private var ostatniaIkona: (isOn: Bool, procent: Int)?

    /// Redraws the shrinking fill. Only alive while a session runs.
    ///
    /// 🔴 Fires every 5 s regardless of session length, and that is deliberate: at one
    /// tick per percent a two-hour session would refresh every 72 s and the wedge would
    /// visibly jump. Five seconds is below the eye's threshold for "it moved", and the
    /// percent check above means most of those ticks cost nothing.
    private var zegarIkony: Timer?

    /// Last refusal from `SMAppService`, shown under the footer until it changes.
    ///
    /// Not an alert: this app has no window to put one over, and a modal for a checkbox
    /// is heavier than the thing it explains. TokenTime shows the same note the same way.
    private var launchNote: String?

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
        let procent = isOn ? Int((session.progress * 100).rounded()) : 0

        zaplanujOdswiezanie(isOn)

        // Nothing to do when neither the state nor the visible fill has moved.
        guard ostatniaIkona?.isOn != isOn || ostatniaIkona?.procent != procent else { return }
        ostatniaIkona = (isOn, procent)

        let icon = isOn
            ? StatusIcon.toggle(isOn: true, progress: session.progress)
            : offIcon
        button.image = icon
        // Should the symbol ever fail to load, the button would sit in the menu bar as an
        // empty square: nothing to see, nothing to explain it, and the menu reachable only
        // by guessing where to click. A word is worse looking and far better than that.
        button.title = icon == nil
            ? (isOn ? String(localized: "On") : String(localized: "Off"))
            : ""
    }

    /// Starts the redraw timer with the session and stops it with the session.
    ///
    /// A timer ticking while the switch is off would be pure waste: the OFF icon has
    /// nothing to animate. This app sits in the menu bar for days, so "pure waste" here
    /// means days of wake-ups for no picture change at all.
    private func zaplanujOdswiezanie(_ isOn: Bool) {
        if isOn, zegarIkony == nil {
            let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refreshIcon() }
            }
            // .common, so the icon keeps counting down while a menu is open — the
            // default mode stalls every timer for as long as the user holds it there.
            RunLoop.main.add(timer, forMode: .common)
            zegarIkony = timer
        } else if !isOn {
            zegarIkony?.invalidate()
            zegarIkony = nil
        }
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

        // Colour of the ON icon. A submenu, because ten entries in the main menu would
        // bury the two things this app is actually for — turning the block on and off.
        let kolory = NSMenuItem(title: String(localized: "Icon colour"), action: nil, keyEquivalent: "")
        kolory.submenu = menuKolorow()
        menu.addItem(kolory)

        menu.addItem(.separator())

        // The version belongs somewhere the user actually looks. It used to appear only
        // inside the "my own time" prompt, which meant reading it required opening a
        // dialog about something else — so in practice nobody ever saw it.
        if let versionLine {
            let stamp = NSMenuItem(title: versionLine, action: nil, keyEquivalent: "")
            stamp.isEnabled = false
            menu.addItem(stamp)
        }

        menu.addItem(stopka())
        if let launchNote {
            let note = NSMenuItem(title: launchNote, action: nil, keyEquivalent: "")
            note.isEnabled = false
            menu.addItem(note)
        }
    }

    /// Ten system colours, each with its own swatch.
    ///
    /// The swatch is not decoration: "teal" and "cyan" are one word apart in the list and
    /// worlds apart on screen, and the same goes for indigo against purple. Reading the
    /// names alone would make choosing a guess.
    private func menuKolorow() -> NSMenu {
        let podmenu = NSMenu()
        let biezacy = IconColor.wybrany
        for kolor in IconColor.allCases {
            let pozycja = NSMenuItem(title: kolor.nazwa,
                                     action: #selector(wybierzKolor(_:)),
                                     keyEquivalent: "")
            pozycja.target = self
            pozycja.representedObject = kolor.rawValue
            pozycja.image = kolor.probka
            pozycja.state = kolor == biezacy ? .on : .off
            podmenu.addItem(pozycja)
        }
        return podmenu
    }

    @objc private func wybierzKolor(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let kolor = IconColor(rawValue: raw) else { return }
        IconColor.ustaw(kolor)
        // The icon caches what it last drew, so a colour change alone would not repaint
        // it — the state and the percentage are both unchanged. Dropping the cache is
        // what makes the new colour show up at once instead of at the next tick.
        ostatniaIkona = nil
        refreshIcon()
    }

    // MARK: - Stopka

    /// One row holding both footer controls, the way TokenTime does it.
    ///
    /// > [!info] Why a custom view and not two menu items
    /// > [U] asked for exactly this bar on 2026-09-04, pointing at TokenTime. There it
    /// > is SwiftUI inside a `MenuBarExtra`; here the whole menu is `NSMenu`, and a plain
    /// > `NSMenuItem` cannot hold two controls side by side. A view can.
    /// >
    /// > It buys one more thing: clicking a control inside a custom view does **not**
    /// > close the menu, so the tick flips under the cursor and a refusal can be shown
    /// > right there — instead of a modal alert over an app that has no windows.
    private func stopka() -> NSMenuItem {
        let szerokosc: CGFloat = 260
        let widok = NSView(frame: NSRect(x: 0, y: 0, width: szerokosc, height: 28))

        let start = NSButton(checkboxWithTitle: String(localized: "Open at login"),
                             target: self, action: #selector(toggleLoginItem))
        start.font = .menuFont(ofSize: NSFont.systemFontSize)
        start.state = LoginItem.isEnabled ? .on : .off
        if LoginItem.needsApproval {
            // Not the same as being on: registration went through, but the item will not
            // launch until the user allows it. A full tick would promise a restart
            // behaviour that is not going to happen.
            start.allowsMixedState = true
            start.state = .mixed
            start.toolTip = String(localized: "Waiting for your approval in System Settings → General → Login Items.")
        }
        start.sizeToFit()
        start.frame.origin = CGPoint(x: 14, y: (28 - start.frame.height) / 2)
        widok.addSubview(start)

        let koniec = NSButton(title: String(localized: "Quit"),
                              target: self, action: #selector(quit))
        koniec.isBordered = false
        koniec.font = .menuFont(ofSize: NSFont.systemFontSize)
        koniec.contentTintColor = .secondaryLabelColor
        koniec.sizeToFit()
        koniec.frame.origin = CGPoint(x: szerokosc - koniec.frame.width - 14,
                                      y: (28 - koniec.frame.height) / 2)
        widok.addSubview(koniec)

        let pozycja = NSMenuItem()
        pozycja.view = widok
        return pozycja
    }

    /// Flips the login item and says out loud when the system refused.
    ///
    /// A silent refusal is the bad case here, exactly like with the sleep block: the tick
    /// would stay off, the user would shrug, and the app would quietly not start at the
    /// next login.
    @objc private func toggleLoginItem() {
        launchNote = LoginItem.enable(!LoginItem.isEnabled)
        // Rebuild in place: the menu is still open, so the tick has to correct itself
        // under the cursor. Reading the state again also means a refusal leaves the
        // checkbox where the system actually put it, not where the click aimed.
        if let menu = statusItem?.menu { menuNeedsUpdate(menu) }
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
    /// described and then quietly lies. `nil` when the key is missing — the line is
    /// simply left out rather than showing a blank.
    ///
    /// > [!info] The build number is deliberately not here
    /// > It used to read "Switch-Work 0.3.0 (build 2)". `CFBundleVersion` matters to
    /// > macOS when it has to tell two copies of the same release apart; it tells the
    /// > person reading the menu nothing. [U] asked for the plain line on 2026-09-04.
    private var versionLine: String? {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        else { return nil }
        return String(format: String(localized: "Switch-Work v.%@"), version)
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
