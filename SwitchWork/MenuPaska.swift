//
//  MenuPaska.swift
//  Switch-Work
//
//  Ikona w pasku menu i całe sterowanie programem.
//

import AppKit

@MainActor
final class MenuPaska: NSObject, NSMenuDelegate {

    private let czuwanie = Czuwanie.shared
    private var pozycja: NSStatusItem?

    /// Ikony budowane raz. Program wisi w pasku całymi dniami — nie ma powodu
    /// tworzyć obrazka przy każdym odświeżeniu.
    private lazy var ikonaWylaczona: NSImage? = Ikona.przelacznik(wlaczony: false)
    private lazy var ikonaWlaczona: NSImage? = Ikona.przelacznik(wlaczony: true)
    private var ostatnioWlaczone: Bool?

    override init() {
        super.init()

        let pozycja = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        pozycja.menu = menu
        self.pozycja = pozycja

        czuwanie.przyZmianie = { [weak self] in self?.odswiezIkone() }
        odswiezIkone()
    }

    // MARK: - Ikona

    private func odswiezIkone() {
        guard let przycisk = pozycja?.button else { return }
        let wlaczone = czuwanie.wlaczone
        guard ostatnioWlaczone != wlaczone else { return }
        ostatnioWlaczone = wlaczone
        przycisk.image = wlaczone ? ikonaWlaczona : ikonaWylaczona
    }

    // MARK: - Menu

    /// Menu składane od nowa przy każdym otwarciu — dzięki temu program nie potrzebuje
    /// zegara tykającego co sekundę tylko po to, żeby odświeżać napis o pozostałym czasie.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let wlaczone = czuwanie.wlaczone

        let naglowek = NSMenuItem(title: opisStanu(), action: nil, keyEquivalent: "")
        naglowek.isEnabled = false
        menu.addItem(naglowek)
        menu.addItem(.separator())

        if wlaczone {
            menu.addItem(pozycjaMenu(String(localized: "Turn off now"), #selector(wylacz)))
            menu.addItem(.separator())
        }

        menu.addItem(pozycjaMenu(
            wlaczone ? String(localized: "Set to 1 hour") : String(localized: "Turn on for 1 hour"),
            #selector(godzina)))
        menu.addItem(pozycjaMenu(
            wlaczone ? String(localized: "Set to 2 hours") : String(localized: "Turn on for 2 hours"),
            #selector(dwieGodziny)))
        menu.addItem(pozycjaMenu(
            wlaczone ? String(localized: "Set my own time…") : String(localized: "Turn on for my own time…"),
            #selector(wlasnyCzas)))

        menu.addItem(.separator())

        let ekran = pozycjaMenu(String(localized: "Keep the screen on too"), #selector(przelaczEkran))
        ekran.state = czuwanie.trzymajEkran ? .on : .off
        menu.addItem(ekran)

        menu.addItem(.separator())
        menu.addItem(pozycjaMenu(String(localized: "Quit Switch-Work"), #selector(zakoncz), klawisz: "q"))
    }

    private func pozycjaMenu(_ tytul: String, _ akcja: Selector, klawisz: String = "") -> NSMenuItem {
        let pozycja = NSMenuItem(title: tytul, action: akcja, keyEquivalent: klawisz)
        pozycja.target = self
        return pozycja
    }

    private func opisStanu() -> String {
        guard czuwanie.wlaczone else { return String(localized: "Switch-Work is off") }
        return String(
            format: String(localized: "Awake — %@ left"),
            Czas.opis(czuwanie.pozostalo)
        )
    }

    // MARK: - Akcje

    @objc private func godzina() { wlacz(minuty: 60) }
    @objc private func dwieGodziny() { wlacz(minuty: 120) }
    @objc private func wylacz() { czuwanie.wylacz() }

    @objc private func przelaczEkran() {
        czuwanie.trzymajEkran.toggle()
    }

    @objc private func zakoncz() {
        NSApp.terminate(nil)
    }

    @objc private func wlasnyCzas() {
        let pole = NSTextField(frame: NSRect(x: 0, y: 0, width: 80, height: 24))
        pole.stringValue = String(UserDefaults.standard.integer(forKey: Ustawienia.ostatnieMinuty))
        pole.alignment = .right

        let pytanie = NSAlert()
        pytanie.messageText = String(localized: "How long should Switch-Work stay awake?")
        pytanie.informativeText = String(localized: "Enter the time in minutes.")
        pytanie.addButton(withTitle: String(localized: "Turn on"))
        pytanie.addButton(withTitle: String(localized: "Cancel"))
        pytanie.accessoryView = pole

        NSApp.activate(ignoringOtherApps: true)
        pytanie.window.initialFirstResponder = pole
        guard pytanie.runModal() == .alertFirstButtonReturn else { return }

        guard let minuty = Czas.minuty(zTekstu: pole.stringValue) else {
            ostrzez(
                String(localized: "That is not a number of minutes"),
                String(format: String(localized: "Enter a whole number from 1 to %lld."), Czas.maksMinuty)
            )
            return
        }

        UserDefaults.standard.set(minuty, forKey: Ustawienia.ostatnieMinuty)
        wlacz(minuty: minuty)
    }

    /// Włącza czuwanie i — gdy system czegoś nie przyjął — mówi o tym wprost.
    /// Milcząca odmowa byłaby najgorszym wariantem: ikona świeci, a Mac i tak zasypia.
    private func wlacz(minuty: Int) {
        let odmowione = czuwanie.wlacz(minuty: minuty)
        guard !odmowione.isEmpty else { return }

        let nazwy = odmowione.map(\.rawValue).joined(separator: ", ")
        if odmowione.contains(.system) {
            ostrzez(
                String(localized: "macOS refused to block sleep"),
                String(format: String(localized: "Switch-Work stays off — without this block nothing would be protected. Refused: %@"), nazwy)
            )
        } else {
            ostrzez(
                String(localized: "Part of the block was refused"),
                String(format: String(localized: "The Mac will stay awake, but macOS refused: %@"), nazwy)
            )
        }
    }

    private func ostrzez(_ tytul: String, _ tresc: String) {
        let okno = NSAlert()
        okno.alertStyle = .warning
        okno.messageText = tytul
        okno.informativeText = tresc
        okno.addButton(withTitle: String(localized: "OK"))
        NSApp.activate(ignoringOtherApps: true)
        okno.runModal()
    }
}
