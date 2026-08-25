//
//  TimeFormat.swift
//  Switch-Work
//

import Foundation

enum TimeFormat {

    /// The longest session accepted from the "my own time" field — one week.
    /// Not a system limit, just a sieve for a typo such as "6000000".
    static let maxMinutes = 7 * 24 * 60

    /// Describes the remaining time as "1 hr 47 min".
    /// The units are translated by the system (`DateComponentsFormatter`), so they are
    /// not part of the string catalog.
    static func describe(_ seconds: TimeInterval) -> String {
        guard seconds >= 60 else { return String(localized: "less than a minute") }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: seconds) ?? ""
    }

    /// Turns whatever the user typed into a number of minutes.
    /// Returns `nil` when the text is not a number or falls outside 1…maxMinutes.
    static func minutes(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Int(trimmed), minutes >= 1, minutes <= maxMinutes else { return nil }
        return minutes
    }
}
