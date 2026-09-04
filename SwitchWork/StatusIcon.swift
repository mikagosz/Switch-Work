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

    /// Point size of the symbol in the menu bar.
    ///
    /// [U] asked for 18–19 pt on 2026-09-04; 19 is the top of that range and still clears
    /// the menu bar's usable height, checked on a rendered image rather than assumed.
    static let pointSize: CGFloat = 19

    // MARK: - The icon

    /// The stopwatch, in one size and one shape for both states.
    ///
    /// > [!important] The outline must NOT shrink when the icon turns green
    /// > [U], 2026-09-04: *„jak zielony to nie zmniejszaj konturu ikony"*. The tempting
    /// > pairing — `timer` for off and `timer.circle.fill` for on — breaks exactly that:
    /// > the filled variant redraws the stopwatch **smaller**, because it has to fit
    /// > inside a disc. The glyph would jump in size on every toggle.
    /// >
    /// > Both states use `timer` at the same point size. The outline is identical down
    /// > to the pixel; only what happens *inside* it changes.
    ///
    /// > [!info] The fill shrinks with the remaining time
    /// > [U], 2026-09-04: *„zrobisz aby wypełnienie się kurczyło jak czas stopera?"*.
    /// > A full green disc means the whole stretch is ahead; it empties clockwise as the
    /// > session runs down, and the last minutes leave a thin wedge. So the icon answers
    /// > *how much longer* without opening the menu — which is the one thing the menu
    /// > was needed for.
    ///
    /// - Parameter progress: share of the session still ahead, `0…1`. Ignored when off.
    static func toggle(isOn: Bool, progress: Double = 1) -> NSImage? {
        let label = isOn
            ? String(localized: "Switch-Work is on")
            : String(localized: "Switch-Work is off")

        var configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        if isOn {
            // The outline has to be painted here: an image drawn into another image is
            // not a template any more, so the menu bar would leave it black.
            configuration = configuration.applying(
                NSImage.SymbolConfiguration(hierarchicalColor: onColor))
        }
        guard let symbol = NSImage(systemSymbolName: "timer", accessibilityDescription: label)?
            .withSymbolConfiguration(configuration)
        else { return nil }

        guard isOn else {
            // OFF stays a template: the menu bar paints it black or white by itself and
            // follows the system appearance without us knowing which one is in force.
            symbol.isTemplate = true
            return symbol
        }

        // 🔴 `NSImage(size:flipped:drawingHandler:)`, NOT lockFocus.
        //
        // lockFocus bakes the drawing into a bitmap at the size given — 19×19 points,
        // one pixel per point. On a Retina menu bar that gets scaled up and the outline
        // turns soft. The handler is called again for every scale the system needs, so
        // the icon stays sharp at 1x and 2x alike. Caught by Harness/T2, which measured
        // the empty fill at 89 lit pixels against the OFF icon's 580: same shape, six
        // times less ink, because one had been flattened and the other had not.
        let obraz = NSImage(size: symbol.size, flipped: false) { _ in
            if progress > 0 {
                NSGraphicsContext.current?.saveGraphicsState()
                wedge(in: symbol.size, progress: progress).addClip()
                onColor.setFill()
                tarcza(in: symbol.size).fill()
                NSGraphicsContext.current?.restoreGraphicsState()
            }
            symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        obraz.isTemplate = false
        return obraz
    }

    // MARK: - Geometry

    /// The dial inside the stopwatch outline.
    ///
    /// Measured against the symbol, not guessed: `timer` puts its dial in the lower part
    /// of the box and keeps the top for the crown, so a circle centred on the box would
    /// sit too high and spill over the strokes. The inset keeps the fill clear of the
    /// outline, which is what makes both readable at 19 pt.
    private static func tarcza(in size: NSSize) -> NSBezierPath {
        let bok = min(size.width, size.height)
        let promien = bok * 0.30
        let srodek = NSPoint(x: size.width / 2, y: size.height * 0.44)
        return NSBezierPath(ovalIn: NSRect(x: srodek.x - promien, y: srodek.y - promien,
                                           width: promien * 2, height: promien * 2))
    }

    /// The wedge still to run, drawn clockwise from twelve o'clock.
    ///
    /// Clockwise and from the top, because that is how every countdown dial a person has
    /// ever seen behaves — the opposite direction reads as filling up, not running out.
    private static func wedge(in size: NSSize, progress: Double) -> NSBezierPath {
        let bok = min(size.width, size.height)
        let srodek = NSPoint(x: size.width / 2, y: size.height * 0.44)
        let promien = bok  // beyond the dial: this path only clips, the dial gives the shape

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
