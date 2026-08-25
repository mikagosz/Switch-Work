//
//  BlokadaUspienia.swift
//  Switch-Work
//
//  Sedno programu: zgłoszenie systemowi, że ma nie zasypiać.
//

import Foundation
import IOKit.pwr_mgt

/// Rodzaje blokad, którymi macOS steruje zasypianiem.
///
/// Wartości to literały z `<IOKit/pwr_mgt/IOPMLib.h>` — dokładnie te same nazwy,
/// które wypisuje `pmset -g assertions`. Wpisane wprost, a nie przez stałe z nagłówka,
/// bo `kIOPMAssertPreventDiskIdle` nie przechodzi do Swift jako stała (pozostałe dwie
/// przechodzą — dla spójności wszystkie trzy stoją tu tak samo).
enum RodzajBlokady: String, CaseIterable {
    /// Mac nie zaśnie z bezczynności. Bez tej jednej cała reszta nie ma sensu.
    case system = "PreventUserIdleSystemSleep"
    /// Dyski nie uśpią talerzy ani nie zaparkują się z bezczynności.
    case dyski = "PreventDiskIdle"
    /// Ekran nie gaśnie. Najdroższa bateryjnie, więc domyślnie wyłączona.
    case ekran = "PreventUserIdleDisplaySleep"
}

/// Trzyma uchwyty do blokad systemowych i pilnuje, żeby stan w systemie
/// zgadzał się z tym, o co poproszono.
///
/// Świadomie **nie** rusza ustawień użytkownika (`pmset`): blokada jest przypięta do
/// tego procesu, więc znika sama — przy wyłączeniu przełącznika, przy zamknięciu
/// programu i przy jego krachu. Nie ma czego „przywracać do poprzedniego stanu",
/// bo nic nie zostało zmienione.
final class BlokadaUspienia {

    private var uchwyty: [RodzajBlokady: IOPMAssertionID] = [:]

    /// Blokady, które w tej chwili naprawdę wiszą w systemie.
    var aktywne: Set<RodzajBlokady> { Set(uchwyty.keys) }

    /// Doprowadza system do zadanego zestawu blokad — dokłada brakujące, zdejmuje zbędne.
    ///
    /// - Returns: blokady, których system **nie przyjął**. Pusta tablica = wszystko gra.
    @discardableResult
    func ustaw(_ zadane: Set<RodzajBlokady>, powod: String) -> [RodzajBlokady] {
        var odmowione: [RodzajBlokady] = []

        for rodzaj in RodzajBlokady.allCases where zadane.contains(rodzaj) && uchwyty[rodzaj] == nil {
            if !wlacz(rodzaj, powod: powod) { odmowione.append(rodzaj) }
        }
        for rodzaj in RodzajBlokady.allCases where !zadane.contains(rodzaj) {
            zdejmij(rodzaj)
        }
        return odmowione
    }

    /// Zdejmuje wszystko — system wraca do swoich zwykłych ustawień usypiania.
    func zdejmijWszystkie() {
        _ = ustaw([], powod: "")
    }

    private func wlacz(_ rodzaj: RodzajBlokady, powod: String) -> Bool {
        var uchwyt: IOPMAssertionID = IOPMAssertionID(0)
        let wynik = IOPMAssertionCreateWithName(
            rodzaj.rawValue as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            powod as CFString,
            &uchwyt
        )
        guard wynik == kIOReturnSuccess else { return false }
        uchwyty[rodzaj] = uchwyt
        return true
    }

    private func zdejmij(_ rodzaj: RodzajBlokady) {
        guard let uchwyt = uchwyty.removeValue(forKey: rodzaj) else { return }
        IOPMAssertionRelease(uchwyt)
    }

    deinit {
        for (_, uchwyt) in uchwyty { IOPMAssertionRelease(uchwyt) }
    }
}
