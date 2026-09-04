//
//  IconColor.swift
//  Switch-Work
//
//  The colour of the ON icon. Chosen by the user, remembered between launches.
//

import AppKit

/// The palette offered in the menu, and the one currently in force.
///
/// > [!info] Why a fixed list and not a colour picker
/// > [U], 2026-09-04: *„chcę z 10 głównych kolorów"*. A picker would also let the user
/// > land on something invisible — dark grey in dark mode, pale yellow in light. Every
/// > entry here is a **system** colour, which means macOS itself adjusts it for light and
/// > dark appearance and for increased contrast. The user picks a hue; the system keeps
/// > it legible.
///
/// > [!important] Green stays the default
/// > [U] in the same breath: *„domyślnie zostawiamy zielony"*. `.green` is first in the
/// > list and is what a fresh install uses; nothing here changes for somebody who never
/// > opens the submenu.
nonisolated enum IconColor: String, CaseIterable, Sendable {
    case green, blue, teal, cyan, indigo, purple, pink, red, orange, yellow

    /// The system colour behind the case.
    ///
    /// System colours, not literals: they carry two definitions each, one for light
    /// appearance and one for dark, and macOS swaps them without the app being told.
    var nsColor: NSColor {
        switch self {
        case .green:  return .systemGreen
        case .blue:   return .systemBlue
        case .teal:   return .systemTeal
        case .cyan:   return .systemCyan
        case .indigo: return .systemIndigo
        case .purple: return .systemPurple
        case .pink:   return .systemPink
        case .red:    return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        }
    }

    /// What the menu entry says.
    var nazwa: String {
        switch self {
        case .green:  return String(localized: "Green")
        case .blue:   return String(localized: "Blue")
        case .teal:   return String(localized: "Teal")
        case .cyan:   return String(localized: "Cyan")
        case .indigo: return String(localized: "Indigo")
        case .purple: return String(localized: "Purple")
        case .pink:   return String(localized: "Pink")
        case .red:    return String(localized: "Red")
        case .orange: return String(localized: "Orange")
        case .yellow: return String(localized: "Yellow")
        }
    }

    /// The one in force, read from `UserDefaults` on every call.
    ///
    /// Read rather than cached, for the same reason the login item is: the icon is drawn
    /// from one place and a cached copy would be one more thing that can fall out of step
    /// with what is actually stored.
    ///
    /// An unknown stored value falls back to green instead of throwing the icon away —
    /// that happens when a colour is dropped from the list in a later version, and losing
    /// the icon over it would be a poor trade.
    static var wybrany: IconColor {
        let zapisany = UserDefaults.standard.string(forKey: Defaults.iconColor) ?? ""
        return IconColor(rawValue: zapisany) ?? .green
    }

    static func ustaw(_ kolor: IconColor) {
        UserDefaults.standard.set(kolor.rawValue, forKey: Defaults.iconColor)
    }

    /// A filled dot for the menu entry, so the choice is visible without reading names.
    ///
    /// Colour names are the weakest part of a list like this — "teal" and "cyan" are one
    /// word apart and worlds apart on screen. The swatch settles it.
    var probka: NSImage? {
        NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nazwa)?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
                    .applying(NSImage.SymbolConfiguration(hierarchicalColor: nsColor)))
    }
}

/// The colour of the stopwatch outline drawn over the disc.
///
/// > [!info] Why three options and not two
/// > [U], 2026-09-04: *„daj mi wybór między białym i czarnym konturem"*. Both are here —
/// > and so is the behaviour they replace, as the default. Dropping it would be a step
/// > back for anybody who switches appearance during the day: a fixed white outline
/// > disappears into a light menu bar and a fixed black one into a dark one. `.auto`
/// > keeps the old behaviour for whoever never opens this submenu.
nonisolated enum OutlineColor: String, CaseIterable, Sendable {
    case auto, black, white

    var nsColor: NSColor {
        switch self {
        case .auto:  return .labelColor   // macOS resolves it against the appearance
        case .black: return .black
        case .white: return .white
        }
    }

    var nazwa: String {
        switch self {
        case .auto:  return String(localized: "Automatic")
        case .black: return String(localized: "Black")
        case .white: return String(localized: "White")
        }
    }

    /// What the entry says under its name, so „Automatic" is not a guess.
    var opis: String? {
        self == .auto
            ? String(localized: "Black on a light menu bar, white on a dark one")
            : nil
    }

    static var wybrany: OutlineColor {
        let zapisany = UserDefaults.standard.string(forKey: Defaults.outlineColor) ?? ""
        return OutlineColor(rawValue: zapisany) ?? .auto
    }

    static func ustaw(_ kolor: OutlineColor) {
        UserDefaults.standard.set(kolor.rawValue, forKey: Defaults.outlineColor)
    }

    /// A swatch with a visible rim, because a black dot on a dark menu is a hole and a
    /// white one on a light menu is nothing at all.
    var probka: NSImage? {
        NSImage(systemSymbolName: "circle.circle.fill", accessibilityDescription: nazwa)?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
                    .applying(NSImage.SymbolConfiguration(
                        paletteColors: [nsColor, .secondaryLabelColor])))
    }
}
