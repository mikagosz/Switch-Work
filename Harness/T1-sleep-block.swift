import Foundation

// Harness T1 — is the sleep block really held by the system?
//
// The point of the app: one click and macOS will not fall asleep. Code that creates a
// block and never checks the result looks exactly like code that works — so this check
// does not ask our own object about its state. It reads `pmset -g assertions`, which is
// what the system sees.

var passed = 0
var failed = 0

func check(_ label: String, _ condition: Bool) {
    if condition { passed += 1 } else { failed += 1; print("  FAILED: \(label)") }
}

func checkEqual<T: Equatable>(_ label: String, _ lhs: T, _ rhs: T) {
    if lhs == rhs { passed += 1 } else { failed += 1; print("  FAILED: \(label) — got \(lhs), want \(rhs)") }
}

/// A raw reading from the system — not from our object.
func pmset() -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["-g", "assertions"]
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(data: data, encoding: .utf8) ?? ""
}

// The token written as the block's reason. Odd enough not to show up by accident in
// some other program's entry.
let token = "SwitchWork-harness-T1-4f2a"

func systemSees(_ needle: String) -> Bool { pmset().contains(needle) }

let block = SleepBlock()

// --- CONTROL SAMPLE ---------------------------------------------------------
// Without it "the system sees our block" would mean nothing: if pmset returned an empty
// string, every "it is not there" check would pass for the wrong reason.
let beforeStart = pmset()
print("CONTROL SAMPLE: pmset returned \(beforeStart.count) characters")
check("pmset returns anything at all", beforeStart.count > 100)
check("pmset knows the PreventUserIdleSystemSleep type", beforeStart.contains("PreventUserIdleSystemSleep"))
check("our token is not there yet", !beforeStart.contains(token))
checkEqual("the object starts with no blocks", block.active.count, 0)

// --- TURNING ON: system + disks, no screen ----------------------------------
let refused1 = block.apply([.system, .disk], reason: token)
checkEqual("the system accepted both blocks", refused1.count, 0)
checkEqual("the object holds two handles", block.active.count, 2)
check("THE SYSTEM SEES our block by its reason", systemSees(token))

/// The rows of the "Listed by owning process" table that carry our token — that is,
/// exactly the blocks this process created, not anyone else's in the system.
func ourRows() -> [String] {
    pmset().split(separator: "\n").map(String.init).filter { $0.contains(token) }
}

let rows2 = ourRows()
for row in rows2 { print("  listed: \(row.trimmingCharacters(in: .whitespaces))") }
checkEqual("the system lists exactly two blocks of OURS", rows2.count, 2)
check("one of them is PreventUserIdleSystemSleep",
      rows2.contains { $0.contains("PreventUserIdleSystemSleep") })
check("the other is PreventDiskIdle", rows2.contains { $0.contains("PreventDiskIdle") })
check("we are not blocking the screen yet",
      !rows2.contains { $0.contains("PreventUserIdleDisplaySleep") })

// A positive control for the summary counter at the top of the listing: our type has to
// carry a number there, and at least one.
func counter(_ type: String) -> Int? {
    for line in pmset().split(separator: "\n") {
        let fields = line.split(separator: " ")
        if fields.count == 2, fields[0] == type, let value = Int(fields[1]) { return value }
    }
    return nil
}
let count = counter("PreventUserIdleSystemSleep")
print("  summary counter for PreventUserIdleSystemSleep: \(count.map(String.init) ?? "no such row")")
check("the summary counter exists and is not zero", (count ?? 0) >= 1)

// --- ADDING THE SCREEN ON THE FLY -------------------------------------------
let refused2 = block.apply([.system, .disk, .display], reason: token)
checkEqual("the screen was accepted too", refused2.count, 0)
checkEqual("three handles", block.active.count, 3)
let rows3 = ourRows()
checkEqual("the system lists three blocks of OURS", rows3.count, 3)
check("THE SYSTEM SEES our screen block",
      rows3.contains { $0.contains("PreventUserIdleDisplaySleep") })

// --- DROPPING ONLY THE SCREEN -----------------------------------------------
_ = block.apply([.system, .disk], reason: token)
checkEqual("back to two handles", block.active.count, 2)
let rows4 = ourRows()
checkEqual("two blocks of OURS again", rows4.count, 2)
check("the screen block is gone", !rows4.contains { $0.contains("PreventUserIdleDisplaySleep") })
check("the system block still stands", rows4.contains { $0.contains("PreventUserIdleSystemSleep") })

// --- TURNING OFF ------------------------------------------------------------
block.releaseAll()
checkEqual("the object holds nothing", block.active.count, 0)
check("THE SYSTEM NO LONGER SEES our block", !systemSees(token))

// --- TIME: description and the sieve on typed text --------------------------
check("under a minute has its own wording", TimeFormat.describe(30).contains("minute"))
check("an hour is described non-empty", !TimeFormat.describe(3600).isEmpty)
check("1 hr 47 min contains 47", TimeFormat.describe(3600 + 47 * 60).contains("47"))

checkEqual("60 minutes passes", TimeFormat.minutes(from: "60"), 60)
checkEqual("spaces around the number do not matter", TimeFormat.minutes(from: "  90 "), 90)
check("zero is rejected", TimeFormat.minutes(from: "0") == nil)
check("a negative number is rejected", TimeFormat.minutes(from: "-5") == nil)
check("text is rejected", TimeFormat.minutes(from: "an hour") == nil)
check("empty is rejected", TimeFormat.minutes(from: "") == nil)
check("more than a week is rejected", TimeFormat.minutes(from: "999999") == nil)
checkEqual("exactly one week passes", TimeFormat.minutes(from: "\(TimeFormat.maxMinutes)"), TimeFormat.maxMinutes)

print("")
print("PASSED: \(passed), FAILED: \(failed)")
exit(failed == 0 ? 0 : 1)
