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

    /// The box the icon is drawn in.
    ///
    /// 19 pt since 2026-09-04. The stopwatch is gone, the box
    /// stayed — so the icon does not nudge its neighbours on the menu bar after the update.
    static let pointSize: CGFloat = 19

    /// The power ring: radius and stroke, in points, inside `pointSize`.
    ///
    /// Measured off the prototype picked on 2026-10-22, drawn at the same 19 pt.
    static let ringRadius: CGFloat = 7.3
    static let lineWidth: CGFloat = 1.9

    /// The coloured part of the ring is a hair thicker than the rest, so it covers the
    /// grey track under it completely instead of leaving a fringe on both edges.
    static let fillWidth: CGFloat = 2.3

    /// Half the gap at the top of the ring where the bar stands, in degrees.
    static let gapHalf: CGFloat = 38

    // MARK: - The icon

    /// The power symbol: a ring that empties with the session, and a bar through its gap.
    ///
    /// > [!important] The bar and the track are NEVER coloured
    /// > 2026-09-04, after a green outline was tried: the outline stays black or
    /// > white, and the choice between them is the user's. `OutlineColor` holds
    /// > that choice; its default follows the appearance, so a fixed white outline does
    /// > not vanish into a light menu bar for somebody who never opens the submenu.
    /// > Only the part of the ring still ahead takes the user's colour.
    ///
    /// > [!important] The symbol must not change size between states
    /// > Both states draw the same ring and the same bar in the same box — only the
    /// > paint changes. Since 2026-09-04: a green icon keeps its full outline.
    ///
    /// > [!info] The ring disappears with the remaining time
    /// > 2026-10-22: a menu bar icon in which this bar runs out.
    /// > A full coloured ring means the whole stretch is ahead; it retracts clockwise
    /// > towards the bar, and the last minutes leave a short stub right of it. The used
    /// > part stays as a faint track, so the ring keeps its shape.
    ///
    /// - Parameter progress: share of the session still ahead, `0…1`. Ignored when off.
    static func toggle(isOn: Bool, progress: Double = 1) -> NSImage? {
        let label = isOn
            ? String(localized: "Switch-Work is on")
            : String(localized: "Switch-Work is off")
        let pudlo = NSSize(width: pointSize, height: pointSize)

        guard isOn else {
            // OFF stays a template: the menu bar paints it black or white by itself,
            // and it keeps following the appearance without the app being told.
            //
            // Upside down, bar at the bottom. Since 2026-10-22, when the icon was hard to spot on the
            // menu bar: turn it over while the timer is off — an ordinary power symbol
            // reads as one more system glyph, a flipped one says „off" at a glance.
            // Rotated whole, so the box and the stroke stay the same.
            let puste = NSImage(size: pudlo, flipped: false) { _ in
                let obrot = NSAffineTransform()
                obrot.translateX(by: pudlo.width, yBy: pudlo.height)
                obrot.rotate(byDegrees: 180)
                obrot.concat()
                NSColor.black.setStroke()
                pierscien(in: pudlo, udzial: 1, grubosc: lineWidth).stroke()
                kreska(in: pudlo).stroke()
                return true
            }
            puste.isTemplate = true
            puste.accessibilityDescription = label
            return puste
        }

        // 🔴 `NSImage(size:flipped:drawingHandler:)`, NOT lockFocus.
        //
        // lockFocus bakes the drawing into a bitmap at the size given — one pixel per
        // point — and on a Retina menu bar that gets scaled up and turns soft. The
        // handler is called again for every scale the system needs.
        let obraz = NSImage(size: pudlo, flipped: false) { _ in
            // Black or white: `labelColor` is resolved against whatever appearance is
            // drawing us, and the handler runs again whenever that changes.
            let kontur = OutlineColor.wybrany.nsColor

            kontur.withAlphaComponent(0.22).setStroke()
            pierscien(in: pudlo, udzial: 1, grubosc: lineWidth).stroke()

            let udzial = min(1, max(0, progress))
            if udzial > 0 {
                onColor.setStroke()
                pierscien(in: pudlo, udzial: udzial, grubosc: fillWidth).stroke()
            }

            kontur.setStroke()
            kreska(in: pudlo).stroke()
            return true
        }
        obraz.isTemplate = false
        obraz.accessibilityDescription = label
        return obraz
    }

    // MARK: - Geometry

    /// The ring from the right edge of the gap, clockwise, for `udzial` of its length.
    ///
    /// Clockwise and anchored at the bar, because that is how a countdown dial runs —
    /// the end that moves is the one coming back round towards twelve o'clock.
    private static func pierscien(in size: NSSize, udzial: Double, grubosc: CGFloat) -> NSBezierPath {
        let srodek = NSPoint(x: size.width / 2, y: size.height / 2)
        let rozpietosc = 360 - 2 * gapHalf
        let start = 90 - gapHalf  // AppKit counts degrees anticlockwise from three o'clock

        let sciezka = NSBezierPath()
        sciezka.appendArc(withCenter: srodek, radius: ringRadius,
                          startAngle: start,
                          endAngle: start - rozpietosc * CGFloat(udzial),
                          clockwise: true)
        sciezka.lineWidth = grubosc
        sciezka.lineCapStyle = .round
        return sciezka
    }

    /// The bar through the gap, from near the top of the box down to just past the middle.
    private static func kreska(in size: NSSize) -> NSBezierPath {
        let x = size.width / 2
        let sciezka = NSBezierPath()
        sciezka.move(to: NSPoint(x: x, y: size.height - 1.6))
        sciezka.line(to: NSPoint(x: x, y: size.height / 2 + 0.1))
        sciezka.lineWidth = lineWidth
        sciezka.lineCapStyle = .round
        return sciezka
    }
}
