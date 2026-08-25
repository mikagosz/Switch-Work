//
//  Ikona.swift
//  Switch-Work
//
//  Ikona przełącznika w pasku menu. Wydzielona z MenuPaska, żeby sprawdzian
//  headless mógł policzyć piksele bez uruchamiania całego programu.
//

import AppKit

enum Ikona {

    /// Barwa pozycji ON. Glif włącznika zostaje czarny — polecenie [U] 2026-08-25:
    /// zielona ikona ma nieść ten sam kontur włącznika, co monochromatyczna przy OFF.
    static let barwaWlaczonej = NSColor.systemGreen
    static let barwaGlifu = NSColor.black

    /// - OFF: `power.circle` jako szablon — monochromatyczny, idzie za kolorem paska.
    /// - ON: `power.circle.fill` malowany paletą **dwubarwną**.
    ///
    /// Dwie barwy palety trafiają w dwie warstwy symbolu: pierwsza w glif włącznika,
    /// druga w koło pod nim. Kolejność ma znaczenie — odwrócona maluje czarne koło
    /// i zielony glif. Zmierzone na pikselach, pilnuje tego `Harness/T2-test-ikony.swift`.
    /// Przy jednej barwie palety glif zlewa się z kołem i znika — tak wyglądała ikona
    /// do 0.1.0.
    static func przelacznik(wlaczony: Bool) -> NSImage? {
        let nazwa = wlaczony ? "power.circle.fill" : "power.circle"
        let opis = wlaczony
            ? String(localized: "Switch-Work is on")
            : String(localized: "Switch-Work is off")

        var ustawienia = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        if wlaczony {
            ustawienia = ustawienia.applying(
                NSImage.SymbolConfiguration(paletteColors: [barwaGlifu, barwaWlaczonej])
            )
        }

        let ikona = NSImage(systemSymbolName: nazwa, accessibilityDescription: opis)?
            .withSymbolConfiguration(ustawienia)
        // Kolor przeżywa wyłącznie poza trybem szablonu; przy OFF szablon jest
        // pożądany, bo wtedy pasek sam dobiera czerń albo biel.
        ikona?.isTemplate = !wlaczony
        return ikona
    }
}
