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
    /// 19 pt since 2026-09-04. On 2026-10-24, with the ziomek in
    /// the ring: 30 pt and a larger figure inside the ring — the MacBook's
    /// menu bar is 34 pt tall (measured that day), so 30 pt still leaves 2 pt above and below.
    static let pointSize: CGFloat = 30

    /// The ring: radius and stroke, in points, inside `pointSize`.
    ///
    /// The stroke stayed at the 2 pt approved at 22 pt; the radius is the largest that keeps
    /// the coloured part inside the box.
    static let ringRadius: CGFloat = 13.7
    static let lineWidth: CGFloat = 2

    /// The coloured part of the ring is a hair thicker than the rest, so it covers the
    /// grey track under it completely instead of leaving a fringe on both edges.
    static let fillWidth: CGFloat = 2.4

    /// The laptop lid while the session runs. Since 2026-10-24 the
    /// laptop screen turns blue — blue whatever colour the ring is.
    static let screenColor: NSColor = .systemBlue

    // MARK: - The ziomek

    /// The original drawing (`ziomek.png`, 1024 × 1024, corrected by hand on 2026-10-24),
    /// cut out of its dark background into a greyscale mask: white is the figure.
    ///
    /// 🔴 It is NOT redrawn. Two redrawn versions on 2026-10-24 were rejected: the figure
    /// is not to be changed as a whole. To change the figure, replace the PNG.
    ///
    /// From the bundle in the app; next to this source file in the headless check.
    static let maska: CGImage? = {
        let url = Bundle.main.url(forResource: "ziomek-maska", withExtension: "png")
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("ziomek-maska.png")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return NSBitmapImageRep(data: data)?.cgImage
    }()

    /// The circle of the drawing that goes inside the ring, in its pixels (y down). The figure
    /// is larger than the ring's inside, so the bottom of his back and a corner of the lid
    /// are cut by it — as on the approved preview.
    static let maskaSrodek = NSPoint(x: 540, y: 525)
    static let maskaPromien: CGFloat = 480

    /// The lid in the drawing's pixels — only this part of the figure turns blue.
    static let klapa: [NSPoint] = [NSPoint(x: 680, y: 940), NSPoint(x: 806, y: 608),
                                   NSPoint(x: 1020, y: 608), NSPoint(x: 905, y: 940)]

    // MARK: - The icon

    /// The ziomek at his laptop inside a ring that empties with the session.
    ///
    /// > [!important] The figure and the track are NEVER in the ring's colour
    /// > 2026-09-04, after a green outline was tried: the outline stays black or
    /// > white, and the choice between them is the user's. `OutlineColor` holds
    /// > that choice; its default follows the appearance, so a fixed white outline does
    /// > not vanish into a light menu bar for somebody who never opens the submenu.
    /// > Only the part of the ring still ahead takes the user's colour, and only the lid
    /// > turns blue.
    ///
    /// > [!important] The symbol must not change size between states
    /// > Both states draw the same ring and the same figure in the same box — only the
    /// > paint changes. Since 2026-09-04: a green icon keeps its full outline.
    ///
    /// > [!info] The ring disappears with the remaining time
    /// > 2026-10-22: a menu bar icon in which this bar runs out.
    /// > A full coloured ring means the whole stretch is ahead; it retracts clockwise
    /// > towards twelve o'clock. The used part stays as a faint track, so the ring keeps
    /// > its shape.
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
            // Full ring, the whole figure in one paint, lid included.
            let puste = NSImage(size: pudlo, flipped: false) { _ in
                NSColor.black.setStroke()
                pierscien(in: pudlo, udzial: 1, grubosc: lineWidth).stroke()
                ziomek(in: pudlo, kontur: .black, ekran: nil)
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

            ziomek(in: pudlo, kontur: kontur, ekran: screenColor)
            return true
        }
        obraz.isTemplate = false
        obraz.accessibilityDescription = label
        return obraz
    }

    // MARK: - Geometry

    /// The ring from twelve o'clock, clockwise, for `udzial` of its length.
    ///
    /// Clockwise and anchored at the top, because that is how a countdown dial runs —
    /// the end that moves is the one coming back round towards twelve.
    private static func pierscien(in size: NSSize, udzial: Double, grubosc: CGFloat) -> NSBezierPath {
        let srodek = NSPoint(x: size.width / 2, y: size.height / 2)
        let sciezka = NSBezierPath()
        sciezka.appendArc(withCenter: srodek, radius: ringRadius,
                          startAngle: 90,  // AppKit counts degrees anticlockwise from three o'clock
                          endAngle: 90 - 360 * CGFloat(udzial),
                          clockwise: true)
        sciezka.lineWidth = grubosc
        sciezka.lineCapStyle = .round
        return sciezka
    }

    /// The figure inside the ring: the mask filled with `kontur`, the lid with `ekran`
    /// (or with `kontur` too when `ekran` is nil).
    private static func ziomek(in size: NSSize, kontur: NSColor, ekran: NSColor?) {
        guard let maska, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let wR = ringRadius - lineWidth * 0.9
        let srodek = NSPoint(x: size.width / 2, y: size.height / 2)
        let k = wR / maskaPromien
        func Q(_ p: NSPoint) -> NSPoint {
            NSPoint(x: srodek.x + (p.x - maskaSrodek.x) * k, y: srodek.y - (p.y - maskaSrodek.y) * k)
        }
        let obraz = NSRect(x: srodek.x - maskaSrodek.x * k,
                           y: srodek.y + maskaSrodek.y * k - CGFloat(maska.height) * k,
                           width: CGFloat(maska.width) * k, height: CGFloat(maska.height) * k)
        let wnetrze = CGPath(ellipseIn: CGRect(x: srodek.x - wR, y: srodek.y - wR, width: 2 * wR, height: 2 * wR),
                             transform: nil)
        let lid = CGMutablePath()
        lid.addLines(between: klapa.map(Q))
        lid.closeSubpath()

        // Everything but the lid
        ctx.saveGState()
        ctx.addPath(wnetrze); ctx.clip()
        let reszta = CGMutablePath()
        reszta.addRect(obraz.insetBy(dx: -1, dy: -1))
        reszta.addPath(lid)
        ctx.addPath(reszta); ctx.clip(using: .evenOdd)
        ctx.clip(to: obraz, mask: maska)
        ctx.setFillColor(kontur.cgColor)
        ctx.fill(obraz)
        ctx.restoreGState()

        // The lid
        ctx.saveGState()
        ctx.addPath(wnetrze); ctx.clip()
        ctx.addPath(lid); ctx.clip()
        ctx.clip(to: obraz, mask: maska)
        ctx.setFillColor((ekran ?? kontur).cgColor)
        ctx.fill(obraz)
        ctx.restoreGState()
    }
}
