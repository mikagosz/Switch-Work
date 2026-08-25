//
//  StatusIcon.swift
//  Switch-Work
//
//  The menu bar toggle icon. Split out of the menu bar controller so the headless check
//  can count its pixels without bringing up the whole app.
//

import AppKit

enum StatusIcon {

    /// The colour of the ON state. The power glyph stays black so the green icon carries
    /// the same switch outline as the monochrome OFF one.
    static let onColor = NSColor.systemGreen
    static let glyphColor = NSColor.black

    /// - OFF: `power.circle` as a template — monochrome, follows the menu bar colour.
    /// - ON: `power.circle.fill` painted with a **two-colour** palette.
    ///
    /// The two palette colours land on the symbol's two layers: the first on the power
    /// glyph, the second on the circle behind it. The order matters — reversed, it paints
    /// a black circle and a green glyph. Measured on pixels; `Harness/T2-status-icon.swift`
    /// guards it. With a single palette colour the glyph blends into the circle and
    /// disappears — that is how the icon looked up to 0.1.0.
    static func toggle(isOn: Bool) -> NSImage? {
        let name = isOn ? "power.circle.fill" : "power.circle"
        let label = isOn
            ? String(localized: "Switch-Work is on")
            : String(localized: "Switch-Work is off")

        var configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        if isOn {
            configuration = configuration.applying(
                NSImage.SymbolConfiguration(paletteColors: [glyphColor, onColor])
            )
        }

        let icon = NSImage(systemSymbolName: name, accessibilityDescription: label)?
            .withSymbolConfiguration(configuration)
        // Colour only survives outside template mode; for OFF the template is what we want,
        // because then the menu bar picks black or white by itself.
        icon?.isTemplate = !isOn
        return icon
    }
}
