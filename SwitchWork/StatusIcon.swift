//
//  StatusIcon.swift
//  Switch-Work
//
//  The menu bar icon. Split out of the menu bar controller so the headless check can
//  count its pixels without bringing up the whole app.
//

import AppKit

enum StatusIcon {

    /// The colour of the ON state — the one the user picked, green until they pick.
    ///
    /// Computed, not stored: the icon is redrawn every few seconds anyway, so reading
    /// the preference here means a new colour shows up without any wiring between the
    /// menu and this file.
    static var onColor: NSColor { IconColor.wybrany.nsColor }

    /// The box the icon is drawn in, and the diameter of the countdown disc.
    ///
    /// [U], 2026-09-04: *„niech kula czasu ma 19pt a kontur 17pt"*.
    static let pointSize: CGFloat = 19

    /// The stopwatch outline, drawn two points smaller than the disc behind it.
    ///
    /// The gap is the point: at the same size the outline would sit exactly on the disc's
    /// rim and the two edges would fight each other. Two points in means the coloured
    /// disc reads as a background and the stopwatch as a thing standing on it.
    static let outlineSize: CGFloat = 17

    // MARK: - The icon

    /// The stopwatch: a coloured disc that empties with the session, under a black or
    /// white outline.
    ///
    /// > [!important] The outline is NEVER coloured
    /// > [U], 2026-09-04, after seeing a green outline: *„kontur ma zostać czarny albo
    /// > biały"*, then: *„daj mi wybór między białym i czarnym"*. `OutlineColor` holds
    /// > that choice; its default follows the appearance, so a fixed white outline does
    /// > not vanish into a light menu bar for somebody who never opens the submenu.
    ///
    /// > [!important] The outline must not change size between states
    /// > Both states draw the same symbol at `outlineSize`. The tempting pairing —
    /// > `timer` for off and `timer.circle.fill` for on — redraws the stopwatch smaller
    /// > to fit inside a disc, so the glyph would jump on every toggle.
    ///
    /// > [!info] The disc shrinks with the remaining time
    /// > [U]: *„zrobisz aby wypełnienie się kurczyło jak czas stopera?"*. A full disc
    /// > means the whole stretch is ahead; it empties clockwise from twelve, and the last
    /// > minutes leave a thin wedge. The icon answers *how much longer* without the menu.
    ///
    /// - Parameter progress: share of the session still ahead, `0…1`. Ignored when off.
    static func toggle(isOn: Bool, progress: Double = 1) -> NSImage? {
        let label = isOn
            ? String(localized: "Switch-Work is on")
            : String(localized: "Switch-Work is off")

        let podstawa = NSImage.SymbolConfiguration(pointSize: outlineSize, weight: .regular)
        // 🔴 The outline takes its colour from the CONFIGURATION, not from painting over
        // the finished image. The first attempt filled the outline's frame with
        // `.sourceAtop`, which lands on every non-transparent pixel underneath — so it
        // repainted the coloured disc as well and the icon came out with no colour at
        // all. Harness/T2 measured zero coloured pixels at every fill level.
        // `paletteColors`, not `hierarchicalColor`: the hierarchical variant dims the
        // symbol's secondary layers to a grey, and [U] asked for black or white —
        // the dimmed ring was visible next to the crisp OFF icon in the same render.
        let konturConf = podstawa.applying(
            NSImage.SymbolConfiguration(paletteColors: [OutlineColor.wybrany.nsColor]))
        guard let konturKolorowy = NSImage(systemSymbolName: "timer", accessibilityDescription: label)?
            .withSymbolConfiguration(konturConf),
              let konturSzablon = NSImage(systemSymbolName: "timer", accessibilityDescription: label)?
            .withSymbolConfiguration(podstawa)
        else { return nil }

        // The box is exactly the disc's size in both states, so switching does not nudge
        // the icon sideways. A 17 pt symbol reports a box slightly wider than 17, so the
        // outline is centred inside these 19 rather than setting the size itself.
        let pudlo = NSSize(width: pointSize, height: pointSize)

        guard isOn else {
            // OFF stays a template: the menu bar paints it black or white by itself,
            // and it keeps following the appearance without the app being told.
            let puste = NSImage(size: pudlo, flipped: false) { _ in
                rysujKontur(konturSzablon, w: pudlo)
                return true
            }
            puste.isTemplate = true
            return puste
        }

        // 🔴 `NSImage(size:flipped:drawingHandler:)`, NOT lockFocus.
        //
        // lockFocus bakes the drawing into a bitmap at the size given — one pixel per
        // point — and on a Retina menu bar that gets scaled up and turns soft. The
        // handler is called again for every scale the system needs.
        let obraz = NSImage(size: pudlo, flipped: false) { _ in
            if progress > 0 {
                NSGraphicsContext.current?.saveGraphicsState()
                wedge(in: pudlo, progress: progress).addClip()
                onColor.setFill()
                kula(in: pudlo).fill()
                NSGraphicsContext.current?.restoreGraphicsState()
            }

            // Black or white: `labelColor` is resolved against whatever appearance is
            // drawing us, and the handler runs again whenever that changes.
            rysujKontur(konturKolorowy, w: pudlo)
            return true
        }
        obraz.isTemplate = false
        return obraz
    }

    // MARK: - Drawing

    /// Puts the outline in the middle of the box, whatever the two sizes work out to.
    private static func rysujKontur(_ kontur: NSImage, w pudlo: NSSize) {
        let ramka = NSRect(x: (pudlo.width - kontur.size.width) / 2,
                           y: (pudlo.height - kontur.size.height) / 2,
                           width: kontur.size.width, height: kontur.size.height)
        kontur.draw(in: ramka, from: .zero, operation: .sourceOver, fraction: 1)
    }

    // MARK: - Geometry

    /// The countdown disc — the full `pointSize` across, minus a hair so its antialiased
    /// edge does not clip against the box.
    private static func kula(in size: NSSize) -> NSBezierPath {
        let promien = min(size.width, size.height) / 2 - 0.5
        let srodek = NSPoint(x: size.width / 2, y: size.height / 2)
        return NSBezierPath(ovalIn: NSRect(x: srodek.x - promien, y: srodek.y - promien,
                                           width: promien * 2, height: promien * 2))
    }

    /// The wedge still to run, drawn clockwise from twelve o'clock.
    ///
    /// Clockwise and from the top, because that is how every countdown dial a person has
    /// ever seen behaves — the opposite direction reads as filling up, not running out.
    private static func wedge(in size: NSSize, progress: Double) -> NSBezierPath {
        let srodek = NSPoint(x: size.width / 2, y: size.height / 2)
        let promien = max(size.width, size.height)  // only clips; the disc gives the shape

        let sciezka = NSBezierPath()
        sciezka.move(to: srodek)
        sciezka.appendArc(withCenter: srodek, radius: promien,
                          startAngle: 90,
                          endAngle: 90 - 360 * CGFloat(min(1, max(0, progress))),
                          clockwise: true)
        sciezka.close()
        return sciezka
    }
}
