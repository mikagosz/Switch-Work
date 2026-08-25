import AppKit

// Harness T2 — does the green icon really carry a black power outline?
//
// Up to 0.1.0 the palette had a single colour, so the glyph blended into the circle and
// vanished — and the code looked exactly like code that works. That is why this check
// does not read the configuration: it counts PIXELS of the finished image.

var passed = 0
var failed = 0

func check(_ label: String, _ condition: Bool) {
    if condition { passed += 1 } else { failed += 1; print("  FAILED: \(label)") }
}

func checkEqual<T: Equatable>(_ label: String, _ lhs: T, _ rhs: T) {
    if lhs == rhs { passed += 1 } else { failed += 1; print("  FAILED: \(label) — got \(lhs), want \(rhs)") }
}

/// Draws the image and sorts its pixels into three buckets.
func count(_ image: NSImage?) -> (black: Int, green: Int, other: Int) {
    guard let image else { return (0, 0, 0) }
    let side = 64
    let map = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: map)
    image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
    NSGraphicsContext.restoreGraphicsState()

    var black = 0, green = 0, other = 0
    for y in 0..<side {
        for x in 0..<side {
            guard let c = map.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent > 0.9
            else { continue }
            let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
            if r < 0.2 && g < 0.2 && b < 0.2 { black += 1 }
            else if g > 0.5 && r < 0.5 && b < 0.5 { green += 1 }
            else { other += 1 }
        }
    }
    return (black, green, other)
}

// --- CONTROL SAMPLE ---------------------------------------------------------
// Without it "zero black pixels" would not tell a wrong colour apart from a drawing that
// never happened. A plain black square has to come out black all over.
let square = NSImage(size: NSSize(width: 64, height: 64))
square.lockFocus()
NSColor.black.setFill()
NSRect(x: 0, y: 0, width: 64, height: 64).fill()
square.unlockFocus()
let control = count(square)
print("CONTROL SAMPLE: black square → black \(control.black), green \(control.green)")
check("the pixel counter works at all", control.black > 4000)
check("the counter sees no green where there is none", control.green == 0)

// --- THE ON ICON ------------------------------------------------------------
let on = StatusIcon.toggle(isOn: true)
check("the ON symbol exists", on != nil)
checkEqual("ON is NOT a template (colour would be lost otherwise)", on?.isTemplate, false)

let onPixels = count(on)
print("  on:  black \(onPixels.black), green \(onPixels.green), other \(onPixels.other)")
check("there is green on the icon (the circle)", onPixels.green > 100)
check("there is black on the icon (the power outline)", onPixels.black > 20)
check("less black than green — the glyph sits ON the circle, not the other way round",
      onPixels.black < onPixels.green)

// --- POSITIVE CONTROL: a reversed palette has to give the reverse result -----
// If the numbers came out the same for every palette, the checks above would mean nothing.
let reversed = NSImage(systemSymbolName: "power.circle.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(
        NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [StatusIcon.onColor, StatusIcon.glyphColor])))
reversed?.isTemplate = false
let reversedPixels = count(reversed)
print("  reversed palette: black \(reversedPixels.black), green \(reversedPixels.green)")
check("a reversed palette gives the reversed layout", reversedPixels.black > reversedPixels.green)

// --- THE OFF ICON -----------------------------------------------------------
let off = StatusIcon.toggle(isOn: false)
check("the OFF symbol exists", off != nil)
checkEqual("OFF IS a template — the menu bar picks its colour", off?.isTemplate, true)
let offPixels = count(off)
print("  off: black \(offPixels.black), green \(offPixels.green), other \(offPixels.other)")
check("OFF carries no green", offPixels.green == 0)
check("OFF draws something", offPixels.black + offPixels.other > 20)

print("")
print("PASSED: \(passed), FAILED: \(failed)")
exit(failed == 0 ? 0 : 1)
