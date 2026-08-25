import AppKit

// Harness T2 — czy zielona ikona naprawde niesie czarny kontur wlacznika.
//
// Zgloszenie [U] 2026-08-25: "zielona ikona niech ma na sobie czarny kontur wlacznika,
// taki jak jest na off". Do 0.1.0 paleta miala jedna barwe, przez co glif zlewal sie
// z kolem i znikal — a kod wygladal wtedy identycznie jak dzialajacy. Dlatego ten
// sprawdzian nie oglada konfiguracji, tylko liczy PIKSELE gotowego obrazka.

var passed = 0
var failed = 0

func check(_ label: String, _ condition: Bool) {
    if condition { passed += 1 } else { failed += 1; print("  CZERWONE: \(label)") }
}

func checkEqual<T: Equatable>(_ label: String, _ lhs: T, _ rhs: T) {
    if lhs == rhs { passed += 1 } else { failed += 1; print("  CZERWONE: \(label) — jest \(lhs), ma byc \(rhs)") }
}

/// Rysuje obrazek na bialym tle i liczy piksele w trzech kubelkach.
func policz(_ obraz: NSImage?) -> (czarne: Int, zielone: Int, inne: Int) {
    guard let obraz else { return (0, 0, 0) }
    let bok = 64
    let mapa = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: bok, pixelsHigh: bok,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: mapa)
    obraz.draw(in: NSRect(x: 0, y: 0, width: bok, height: bok))
    NSGraphicsContext.restoreGraphicsState()

    var czarne = 0, zielone = 0, inne = 0
    for y in 0..<bok {
        for x in 0..<bok {
            guard let k = mapa.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), k.alphaComponent > 0.9
            else { continue }
            let r = k.redComponent, g = k.greenComponent, b = k.blueComponent
            if r < 0.2 && g < 0.2 && b < 0.2 { czarne += 1 }
            else if g > 0.5 && r < 0.5 && b < 0.5 { zielone += 1 }
            else { inne += 1 }
        }
    }
    return (czarne, zielone, inne)
}

// --- PROBKA KONTROLNA -------------------------------------------------------
// Bez niej "zero czarnych pikseli" nie odroznialoby zlego koloru od nieudanego
// rysowania. Czysty czarny kwadrat ma wyjsc w calosci czarny.
let kwadrat = NSImage(size: NSSize(width: 64, height: 64))
kwadrat.lockFocus()
NSColor.black.setFill()
NSRect(x: 0, y: 0, width: 64, height: 64).fill()
kwadrat.unlockFocus()
let kontrola = policz(kwadrat)
print("PROBKA KONTROLNA: czarny kwadrat → czarne \(kontrola.czarne), zielone \(kontrola.zielone)")
check("licznik pikseli w ogole dziala", kontrola.czarne > 4000)
check("licznik nie widzi zieleni tam, gdzie jej nie ma", kontrola.zielone == 0)

// --- IKONA WLACZONA ---------------------------------------------------------
let wlaczona = Ikona.przelacznik(wlaczony: true)
check("symbol wlaczonej istnieje", wlaczona != nil)
checkEqual("wlaczona NIE jest szablonem (inaczej kolor by zginal)", wlaczona?.isTemplate, false)

let w = policz(wlaczona)
print("  wlaczona: czarne \(w.czarne), zielone \(w.zielone), inne \(w.inne)")
check("na ikonie jest zielen (kolo)", w.zielone > 100)
check("na ikonie jest czern (kontur wlacznika)", w.czarne > 20)
check("czerni jest mniej niz zieleni — glif siedzi NA kole, nie odwrotnie",
      w.czarne < w.zielone)

// --- KONTROLA DODATNIA: odwrocona paleta ma dac odwrotny wynik ---------------
// Gdyby liczby wychodzily te same przy kazdej palecie, powyzsze nic by nie znaczylo.
let odwrotna = NSImage(systemSymbolName: "power.circle.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(
        NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [Ikona.barwaWlaczonej, Ikona.barwaGlifu])))
odwrotna?.isTemplate = false
let o = policz(odwrotna)
print("  odwrocona paleta: czarne \(o.czarne), zielone \(o.zielone)")
check("odwrocona paleta daje odwrotny uklad barw", o.czarne > o.zielone)

// --- IKONA WYLACZONA --------------------------------------------------------
let wylaczona = Ikona.przelacznik(wlaczony: false)
check("symbol wylaczonej istnieje", wylaczona != nil)
checkEqual("wylaczona JEST szablonem — pasek dobiera jej barwe sam", wylaczona?.isTemplate, true)
let z = policz(wylaczona)
print("  wylaczona: czarne \(z.czarne), zielone \(z.zielone), inne \(z.inne)")
check("wylaczona nie ma w sobie zieleni", z.zielone == 0)
check("wylaczona cos rysuje", z.czarne + z.inne > 20)

print("")
print("ZIELONE: \(passed), CZERWONE: \(failed)")
exit(failed == 0 ? 0 : 1)
