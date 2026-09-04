import AppKit

// Harness T2 — does the icon keep the SAME outline when it turns green?
//
// [U], 2026-09-04: "jak zielony to nie zmniejszaj konturu ikony". The tempting pairing
// `timer` + `timer.circle.fill` breaks exactly that — the filled variant redraws the
// stopwatch smaller so it fits inside a disc, and the glyph jumps in size on every
// toggle. Both states now use `timer`, and only the colour changes.
//
// So this check counts PIXELS of the finished images and compares the two states'
// shapes against each other. Reading the configuration would not catch a symbol that
// silently draws itself at a different scale.

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
let on = StatusIcon.toggle(isOn: true, progress: 1)
check("the ON symbol exists", on != nil)
checkEqual("ON is NOT a template (colour would be lost otherwise)", on?.isTemplate, false)

let onPixels = count(on)
print("  on 100%: black \(onPixels.black), green \(onPixels.green), other \(onPixels.other)")
check("the ON icon is green", onPixels.green > 100)

// --- THE OFF ICON -----------------------------------------------------------
let off = StatusIcon.toggle(isOn: false)
check("the OFF symbol exists", off != nil)
checkEqual("OFF IS a template — the menu bar picks its colour", off?.isTemplate, true)
let offPixels = count(off)
print("  off:     black \(offPixels.black), green \(offPixels.green), other \(offPixels.other)")
check("OFF carries no green", offPixels.green == 0)
check("OFF draws something", offPixels.black + offPixels.other > 20)

// --- THE OUTLINE MUST NOT SHRINK --------------------------------------------
// [U]'s requirement, and the reason both states share one symbol at one point size.
//
// 🔴 Compared by SIZE, not by ink. An earlier version of this check counted lit pixels
// of both images scaled to 64×64 and "failed" at 96 against 580 — but it was comparing
// a system symbol, which scales as a vector, against an image drawn at 19 pt and then
// blown up. The icon was fine; the measurement was not. Size is the honest question
// here: same symbol, same point size, same box means the outline cannot have shrunk.
checkEqual("ON and OFF are the same size — the outline cannot shrink",
           on?.size, off?.size)
checkEqual("the box is the point size asked for",
           on?.size.height.rounded(), StatusIcon.pointSize + 3)  // symbol box > glyph

// --- THE FILL SHRINKS WITH THE REMAINING TIME -------------------------------
var poprzedni = Int.max
for p in [1.0, 0.75, 0.5, 0.25, 0.0] {
    let ile = count(StatusIcon.toggle(isOn: true, progress: p)).green
    print("  fill at \(Int(p * 100))%: green \(ile)")
    check("fill at \(Int(p * 100))% is smaller than the step before", ile < poprzedni)
    poprzedni = ile
}

// --- POSITIVE CONTROL -------------------------------------------------------
// The loop above would pass just as happily if `count` returned a falling sequence for
// anything at all. A full fill has to be substantially bigger than an empty one — if
// those two came out equal, every check above would be measuring nothing.
let pelnyGreen = count(StatusIcon.toggle(isOn: true, progress: 1)).green
let pustyGreen = count(StatusIcon.toggle(isOn: true, progress: 0)).green
print("  CONTROL: green full \(pelnyGreen) vs empty \(pustyGreen)")
check("the counter can tell a full dial from an empty one", pelnyGreen > pustyGreen * 2)

// --- SIZE -------------------------------------------------------------------
check("the symbol is sized in the range [U] asked for",
      StatusIcon.pointSize >= 18 && StatusIcon.pointSize <= 19)

// --- THE COLOUR IS THE USER'S ------------------------------------------------
// [U], 2026-09-04: ten colours to choose from, green until chosen.
checkEqual("there are ten colours to pick from", IconColor.allCases.count, 10)
checkEqual("green is first, so it is what a fresh install shows", IconColor.allCases.first, .green)

UserDefaults.standard.removeObject(forKey: Defaults.iconColor)
checkEqual("with nothing stored the icon is green", IconColor.wybrany, .green)

UserDefaults.standard.set("zielonkawy-fiolet", forKey: Defaults.iconColor)
checkEqual("an unknown stored colour falls back to green instead of losing the icon",
           IconColor.wybrany, .green)

IconColor.ustaw(.red)
checkEqual("a picked colour is what the icon asks for", IconColor.wybrany, .red)
let czerwona = count(StatusIcon.toggle(isOn: true, progress: 1))
print("  red icon: black \(czerwona.black), green \(czerwona.green), other \(czerwona.other)")
check("the red icon carries no green at all", czerwona.green == 0)
check("the red icon still draws something", czerwona.other > 100)

// Leave the machine as it was found — this check runs on [U]'s Mac.
UserDefaults.standard.removeObject(forKey: Defaults.iconColor)
checkEqual("the check put the setting back", IconColor.wybrany, .green)

print("")
print("PASSED: \(passed), FAILED: \(failed)")
exit(failed == 0 ? 0 : 1)
