//
//  Ustawienia.swift
//  Switch-Work
//

import Foundation

/// Klucze w `UserDefaults` i ich wartości domyślne.
enum Ustawienia {

    /// Czy razem z systemem trzymamy też włączony ekran.
    static let trzymajEkran = "trzymajEkran"

    /// Ostatnia wartość z pola „własny czas" — podpowiadana przy następnym otwarciu.
    static let ostatnieMinuty = "ostatnieMinuty"

    static let domyslne: [String: Any] = [
        trzymajEkran: false,
        ostatnieMinuty: 60,
    ]
}
