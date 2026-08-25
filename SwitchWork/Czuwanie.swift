//
//  Czuwanie.swift
//  Switch-Work
//
//  Stan przełącznika: czy czuwamy, do kiedy i co dokładnie blokujemy.
//

import AppKit

@MainActor
final class Czuwanie {

    static let shared = Czuwanie()

    /// Tekst, który widać w `pmset -g assertions` przy naszym wpisie.
    private static let powod = "Switch-Work keeps this Mac awake"

    private let blokada = BlokadaUspienia()
    private var budzik: Timer?

    /// Do kiedy czuwamy. `nil` znaczy: przełącznik wyłączony.
    private(set) var koniec: Date?

    /// Wołane po każdej zmianie stanu — ikona i menu odświeżają się z tego jednego miejsca.
    var przyZmianie: (() -> Void)?

    var wlaczone: Bool { koniec != nil }

    var pozostalo: TimeInterval {
        guard let koniec else { return 0 }
        return max(0, koniec.timeIntervalSinceNow)
    }

    /// Czy razem z systemem trzymamy też ekran. Ustawienie przeżywa restart programu.
    var trzymajEkran: Bool {
        get { UserDefaults.standard.bool(forKey: Ustawienia.trzymajEkran) }
        set {
            UserDefaults.standard.set(newValue, forKey: Ustawienia.trzymajEkran)
            // Zmiana w locie: gdy czuwamy, blokada ekranu dokłada się albo znika
            // bez zerowania odliczania.
            if wlaczone { _ = blokada.ustaw(zadaneBlokady, powod: Self.powod) }
            przyZmianie?()
        }
    }

    private init() {
        // Zegar nie chodzi, kiedy Mac śpi. Gdyby mimo blokad zasnął (zamknięta klapa),
        // po wybudzeniu termin trzeba sprawdzić datą, a nie czekać na wystrzał zegara.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(poWybudzeniu),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    /// Włącza czuwanie na zadaną liczbę minut (albo przestawia termin, gdy już czuwamy).
    ///
    /// - Returns: blokady, których system **nie przyjął**. Pusto = wszystko gra.
    ///   Gdy odmówiona jest blokada systemu, przełącznik wraca do pozycji OFF —
    ///   bez niej reszta niczego nie chroni, a kolorowa ikona kłamałaby.
    @discardableResult
    func wlacz(minuty: Int) -> [RodzajBlokady] {
        koniec = Date().addingTimeInterval(TimeInterval(minuty) * 60)
        let odmowione = blokada.ustaw(zadaneBlokady, powod: Self.powod)

        if odmowione.contains(.system) {
            wylacz()
            return odmowione
        }

        ustawBudzik()
        przyZmianie?()
        return odmowione
    }

    /// Wyłącza czuwanie i zdejmuje wszystkie blokady — system wraca do swoich ustawień.
    func wylacz() {
        koniec = nil
        budzik?.invalidate()
        budzik = nil
        blokada.zdejmijWszystkie()
        przyZmianie?()
    }

    /// Blokady, które przy obecnych ustawieniach powinny wisieć w systemie.
    private var zadaneBlokady: Set<RodzajBlokady> {
        guard wlaczone else { return [] }
        var zestaw: Set<RodzajBlokady> = [.system, .dyski]
        if trzymajEkran { zestaw.insert(.ekran) }
        return zestaw
    }

    private func ustawBudzik() {
        budzik?.invalidate()
        guard let koniec else { return }
        // Sekunda zapasu, żeby zegar nie wystrzelił tuż przed terminem i nie odbił się
        // od `sprawdzTermin` w kółko.
        let zegar = Timer(
            fireAt: koniec.addingTimeInterval(1),
            interval: 0,
            target: self,
            selector: #selector(sprawdzTermin),
            userInfo: nil,
            repeats: false
        )
        // .common — inaczej zegar milczy, kiedy menu paska jest otwarte.
        RunLoop.main.add(zegar, forMode: .common)
        budzik = zegar
    }

    @objc private func sprawdzTermin() {
        guard wlaczone else { return }
        if pozostalo <= 0 { wylacz() } else { ustawBudzik() }
    }

    @objc private func poWybudzeniu() {
        sprawdzTermin()
    }
}
