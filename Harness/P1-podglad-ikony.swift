import AppKit

// Podglad ikony, nie test. Rysuje StatusIcon.toggle przy kilku stanach licznika i w kilku
// kolorach, na tle jasnym i ciemnym — bo kontur bierze labelColor i ma sie do nich
// dostosowac. Zadna liczba nie powie tego tak dobrze jak obrazek.

let etapy: [(Double, String)] = [(1.0, "100%"), (0.75, "75%"), (0.5, "50%"),
                                 (0.25, "25%"), (0.08, "8%"), (0.0, "0%")]

func rysujW(_ jasny: Bool, _ blok: () -> Void) {
    let wyglad = NSAppearance(named: jasny ? .aqua : .darkAqua)!
    if #available(macOS 11.0, *) { wyglad.performAsCurrentDrawingAppearance { blok() } }
    else { NSAppearance.current = wyglad; blok() }
}

let W: CGFloat = 820, H: CGFloat = 400
let plotno = NSImage(size: NSSize(width: W, height: H))
plotno.lockFocus()
NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()

func napis(_ t: String, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ k: NSColor) {
    (t as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
        .font: NSFont.systemFont(ofSize: r, weight: .medium), .foregroundColor: k])
}

napis("Kula czasu \(Int(StatusIcon.pointSize)) pt · kontur \(Int(StatusIcon.outlineSize)) pt, czarny albo bialy",
      16, H - 26, 13, .white)

// Dwa paski: jasny i ciemny
for (rzad, jasny) in [(0, true), (1, false)].enumerated().map({ ($0.offset, $0.element.1) }) {
    let yPas = H - 90 - CGFloat(rzad) * 120
    NSColor(calibratedWhite: jasny ? 0.95 : 0.10, alpha: 1).setFill()
    NSRect(x: 16, y: yPas - 10, width: W - 32, height: 46).fill()
    napis(jasny ? "pasek jasny" : "pasek ciemny", 16, yPas + 42, 10, .secondaryLabelColor)

    var x: CGFloat = 34
    rysujW(jasny) {
        if let off = StatusIcon.toggle(isOn: false) {
            // OFF jest szablonem: pasek maluje go sam, wiec tu robimy to za niego.
            let kopia = NSImage(size: off.size)
            kopia.lockFocus()
            (jasny ? NSColor.black : NSColor.white).set()
            NSRect(origin: .zero, size: off.size).fill(using: .sourceOver)
            off.draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1)
            kopia.unlockFocus()
            kopia.draw(in: NSRect(x: x, y: yPas, width: off.size.width * 1.4, height: off.size.height * 1.4))
        }
        x += 60
        for (p, _) in etapy {
            if let ik = StatusIcon.toggle(isOn: true, progress: p) {
                ik.draw(in: NSRect(x: x, y: yPas, width: ik.size.width * 1.4, height: ik.size.height * 1.4))
            }
            x += 60
        }
    }
    // podpisy etapow tylko raz
    if rzad == 0 {
        var xs: CGFloat = 34
        napis("OFF", xs, yPas + 30, 9, .secondaryLabelColor); xs += 60
        for (_, opis) in etapy { napis(opis, xs, yPas + 30, 9, .secondaryLabelColor); xs += 60 }
    }
}

// Paleta
napis("Dziesiec kolorow (60% czasu, pasek ciemny)", 16, 118, 12, .white)
NSColor(calibratedWhite: 0.10, alpha: 1).setFill()
NSRect(x: 16, y: 56, width: W - 32, height: 52).fill()
rysujW(false) {
    for (i, kolor) in IconColor.allCases.enumerated() {
        IconColor.ustaw(kolor)
        guard let ik = StatusIcon.toggle(isOn: true, progress: 0.6) else { continue }
        let x = 30 + CGFloat(i) * 78
        ik.draw(in: NSRect(x: x, y: 66, width: ik.size.width * 1.6, height: ik.size.height * 1.6))
    }
}
for (i, kolor) in IconColor.allCases.enumerated() {
    napis(kolor.nazwa, 24 + CGFloat(i) * 78, 38, 9, .secondaryLabelColor)
}
UserDefaults.standard.removeObject(forKey: Defaults.iconColor)

plotno.unlockFocus()
let rep = NSBitmapImageRep(data: plotno.tiffRepresentation!)!
let cel = URL(fileURLWithPath: "/private/tmp/claude-501/-Users-maczek-Desktop-My-Code/6af03c96-ba59-481d-afb5-5a919c9ec767/scratchpad/ikona-stoper.png")
try! rep.representation(using: .png, properties: [:])!.write(to: cel)
print("zapisano \(cel.path)")
