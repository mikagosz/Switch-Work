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
    /// menu bar is 34 pt tall (measured that day). Then, after seeing 30 pt on the bar:
    /// 2 pt smaller — 28 pt, 3 pt free above and below.
    static let pointSize: CGFloat = 28

    /// The ring: radius and stroke, in points, inside `pointSize`.
    ///
    /// The stroke stayed at the 2 pt approved at 22 pt; the radius is the largest that keeps
    /// the coloured part inside the box.
    static let ringRadius: CGFloat = 12.7
    static let lineWidth: CGFloat = 2

    /// The coloured part of the ring is a hair thicker than the rest, so it covers the
    /// grey track under it completely instead of leaving a fringe on both edges.
    static let fillWidth: CGFloat = 2.4

    /// The laptop lid while the session runs. Since 2026-10-24 the
    /// laptop screen turns blue — blue whatever colour the ring is.
    static let screenColor: NSColor = .systemBlue

    /// The cap and the hoodie while the session runs. Since 2026-10-24 the
    /// cap turns red and the hoodie violet — like the lid, whatever colour the ring is.
    /// The hoodie's shade picked from eight samples the same day: indigo.
    static let capColor: NSColor = .systemRed
    static let hoodieColor: NSColor = .systemIndigo

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

    /// The circle of the drawing that goes inside the ring, in its pixels (y down): the
    /// smallest one holding every white pixel (measured: centre 488, 636, radius 523) plus a
    /// hair, so the whole figure fits. On 2026-10-24 version 0.3.10 at radius 480
    /// cut the figure at the sides.
    static let maskaSrodek = NSPoint(x: 488, y: 636)
    static let maskaPromien: CGFloat = 540

    /// The lid in the drawing's pixels — it turns blue.
    static let klapa: [NSPoint] = [NSPoint(x: 680, y: 940), NSPoint(x: 806, y: 608),
                                   NSPoint(x: 1020, y: 608), NSPoint(x: 905, y: 940)]

    /// The cap with its brim, in the drawing's pixels. The lower edge runs through the
    /// black gap between the cap and the hair (measured: the cap ends at y 367 on the left).
    static let czapka: [NSPoint] = [NSPoint(x: 300, y: 90), NSPoint(x: 870, y: 90),
                                    NSPoint(x: 870, y: 392), NSPoint(x: 712, y: 392),
                                    NSPoint(x: 712, y: 366), NSPoint(x: 300, y: 370)]

    /// The hoodie with the sleeve, up to the hand and the keyboard; the neck stays out.
    static let bluza: [NSPoint] = [NSPoint(x: 20, y: 470), NSPoint(x: 330, y: 470),
                                   NSPoint(x: 395, y: 600), NSPoint(x: 440, y: 640),
                                   NSPoint(x: 455, y: 760), NSPoint(x: 495, y: 785),
                                   NSPoint(x: 485, y: 875), NSPoint(x: 408, y: 882),
                                   NSPoint(x: 400, y: 935), NSPoint(x: 20, y: 935)]

    // MARK: - The icon

    /// The ziomek at his laptop inside a ring that empties with the session.
    ///
    /// > [!important] The figure and the track are NEVER in the ring's colour
    /// > 2026-09-04, after a green outline was tried: the outline stays black or
    /// > white, and the choice between them is the user's. `OutlineColor` holds
    /// > that choice; its default follows the appearance, so a fixed white outline does
    /// > not vanish into a light menu bar for somebody who never opens the submenu.
    /// > Only the part of the ring still ahead takes the user's colour; the lid turns
    /// > blue, the cap red and the hoodie purple.
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
                ziomek(in: pudlo, kontur: .black, strefy: [])
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

            ziomek(in: pudlo, kontur: kontur,
                   strefy: [(klapa, screenColor), (czapka, capColor), (bluza, hoodieColor)])
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

    /// The figure inside the ring: the mask filled with `kontur`, each of `strefy` (a
    /// polygon in the drawing's pixels) with its own colour. No zones — all `kontur`.
    private static func ziomek(in size: NSSize, kontur: NSColor, strefy: [([NSPoint], NSColor)]) {
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
        let sciezki: [(CGPath, NSColor)] = strefy.map { punkty, kolor in
            let p = CGMutablePath()
            p.addLines(between: punkty.map(Q))
            p.closeSubpath()
            return (p, kolor)
        }

        // Everything outside the zones (they do not overlap, so even-odd cuts each out)
        ctx.saveGState()
        ctx.addPath(wnetrze); ctx.clip()
        let reszta = CGMutablePath()
        reszta.addRect(obraz.insetBy(dx: -1, dy: -1))
        for (p, _) in sciezki { reszta.addPath(p) }
        ctx.addPath(reszta); ctx.clip(using: .evenOdd)
        ctx.clip(to: obraz, mask: maska)
        ctx.setFillColor(kontur.cgColor)
        ctx.fill(obraz)
        ctx.restoreGState()

        // Each zone in its own colour
        for (p, kolor) in sciezki {
            ctx.saveGState()
            ctx.addPath(wnetrze); ctx.clip()
            ctx.addPath(p); ctx.clip()
            ctx.clip(to: obraz, mask: maska)
            ctx.setFillColor(kolor.cgColor)
            ctx.fill(obraz)
            ctx.restoreGState()
        }
    }
}
