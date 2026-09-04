//
//  Defaults.swift
//  Switch-Work
//

import Foundation

/// The `UserDefaults` keys and their default values.
enum Defaults {

    /// Whether the screen is kept awake along with the system.
    static let keepScreenOn = "keepScreenOn"

    /// The last value from the "my own time" field — offered again next time.
    static let lastMinutes = "lastMinutes"

    /// Which colour the ON icon is painted with. Stored as `IconColor.rawValue`.
    static let iconColor = "iconColor"

    /// The stopwatch outline over it. Stored as `OutlineColor.rawValue`.
    static let outlineColor = "outlineColor"

    static let registered: [String: Any] = [
        keepScreenOn: false,
        lastMinutes: 60,
        iconColor: IconColor.green.rawValue,
        outlineColor: OutlineColor.auto.rawValue,
    ]
}
