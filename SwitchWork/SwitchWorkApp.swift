//
//  SwitchWorkApp.swift
//  Switch-Work
//

import AppKit

@main
enum SwitchWorkMain {
    @MainActor
    static func main() {
        let program = NSApplication.shared
        let delegat = AppDelegate()
        program.delegate = delegat
        // .accessory — program żyje wyłącznie w pasku menu: bez ikony w Docku
        // i bez pozycji w przełączniku programów.
        program.setActivationPolicy(.accessory)
        _ = delegat            // delegat musi przeżyć uruchomienie pętli zdarzeń
        program.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var menu: MenuPaska?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: Ustawienia.domyslne)
        menu = MenuPaska()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Blokady i tak giną razem z procesem — to jest sprzątnięcie jawne,
        // żeby nie polegać na tym, że system zdąży posprzątać po nas sam.
        Czuwanie.shared.wylacz()
    }
}
