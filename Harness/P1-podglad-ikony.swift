import AppKit

// Podglad ikony, nie test: rysuje StatusIcon.toggle przy kilku stanach licznika i zapisuje
// PNG. Sluzy do obejrzenia geometrii — tarcza ma siedziec WEWNATRZ konturu stopera,
// a tego zadna liczba nie powie tak dobrze jak obrazek.

let etapy: [(Double, String)] = [(1.0, "100%"), (0.75, "75%"), (0.5, "50%"),
                                 (0.25, "25%"), (0.08, "8%"), (0.0, "0%")]
let skale: [CGFloat] = [1, 4]

let szerKol: CGFloat = 120
let W = max(szerKol * CGFloat(etapy.count + 1), 74 * 10 + 40)
let H: CGFloat = 290

let plotno = NSImage(size: NSSize(width: W, height: H))
plotno.lockFocus()
NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()

func napis(_ t: String, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ k: NSColor) {
    (t as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
        .font: NSFont.systemFont(ofSize: r, weight: .medium), .foregroundColor: k])
}

napis("StatusIcon — wypelnienie kurczy sie z czasem (pointSize \(StatusIcon.pointSize))",
      16, H - 26, 13, .white)

// Stan wylaczony jako punkt odniesienia
napis("OFF", 30, H - 60, 11, .secondaryLabelColor)
if let off = StatusIcon.toggle(isOn: false) {
    let kopia = NSImage(size: off.size)
    kopia.lockFocus()
    NSColor.white.set()
    NSRect(origin: .zero, size: off.size).fill(using: .sourceOver)
    off.draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1)
    kopia.unlockFocus()
    kopia.draw(in: NSRect(x: 30, y: H - 95, width: off.size.width, height: off.size.height))
    kopia.draw(in: NSRect(x: 22, y: H - 190, width: off.size.width * 4, height: off.size.height * 4))
}

for (i, (p, opis)) in etapy.enumerated() {
    let x = szerKol * CGFloat(i + 1) + 16
    napis(opis, x, H - 60, 11, .white)
    guard let ikona = StatusIcon.toggle(isOn: true, progress: p) else { continue }
    ikona.draw(in: NSRect(x: x, y: H - 95, width: ikona.size.width, height: ikona.size.height))
    ikona.draw(in: NSRect(x: x - 8, y: H - 190,
                          width: ikona.size.width * 4, height: ikona.size.height * 4))
}

// Paleta: dziesiec kolorow do wyboru, kazdy przy polowie czasu.
napis("Dziesiec kolorow do wyboru (tu: 60% czasu)", 16, 78, 12, .white)
for (i, kolor) in IconColor.allCases.enumerated() {
    IconColor.ustaw(kolor)
    guard let ikona = StatusIcon.toggle(isOn: true, progress: 0.6) else { continue }
    let x = 16 + CGFloat(i) * 74
    ikona.draw(in: NSRect(x: x + 10, y: 44, width: ikona.size.width * 1.6,
                          height: ikona.size.height * 1.6))
    napis(kolor.nazwa, x, 30, 9, .secondaryLabelColor)
}
UserDefaults.standard.removeObject(forKey: Defaults.iconColor)

napis("gorny rzad: rozmiar paska menu   ·   srodkowy: x4", 16, 8, 10, .tertiaryLabelColor)
plotno.unlockFocus()

let rep = NSBitmapImageRep(data: plotno.tiffRepresentation!)!
let cel = URL(fileURLWithPath: "/private/tmp/claude-501/-Users-maczek-Desktop-My-Code/6af03c96-ba59-481d-afb5-5a919c9ec767/scratchpad/ikona-stoper.png")
try! rep.representation(using: .png, properties: [:])!.write(to: cel)
print("zapisano \(cel.path)")
