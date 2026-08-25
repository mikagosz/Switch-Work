//
//  Czas.swift
//  Switch-Work
//

import Foundation

enum Czas {

    /// Najdłuższe czuwanie, jakie przyjmujemy z pola „własny czas" — tydzień.
    /// Nie jest ograniczeniem systemu, tylko sitem na literówkę w rodzaju „6000000".
    static let maksMinuty = 7 * 24 * 60

    /// Opis pozostałego czasu w formie „1 godz. 47 min".
    /// Jednostki tłumaczy system (`DateComponentsFormatter`), więc nie ma ich w katalogu.
    static func opis(_ sekundy: TimeInterval) -> String {
        guard sekundy >= 60 else { return String(localized: "less than a minute") }
        let formater = DateComponentsFormatter()
        formater.allowedUnits = [.hour, .minute]
        formater.unitsStyle = .short
        formater.zeroFormattingBehavior = .dropAll
        return formater.string(from: sekundy) ?? ""
    }

    /// Zamienia to, co użytkownik wpisał w pole, na liczbę minut.
    /// Zwraca `nil`, gdy tekst nie jest liczbą albo wypada poza zakres 1…maksMinuty.
    static func minuty(zTekstu tekst: String) -> Int? {
        let oczyszczony = tekst.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minuty = Int(oczyszczony), minuty >= 1, minuty <= maksMinuty else { return nil }
        return minuty
    }
}
