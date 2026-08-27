import AppKit

// Harness T3 — does the switch really go out by itself, and does the screen block
// really follow the menu option?
//
// T1 proves the blocks can be held. This one proves the other half of the promise: that
// they are dropped when the time runs out, without anyone clicking anything. It does not
// ask WakeSession about its own state where the state could lie — it reads
// `pmset -g assertions`, which is what the system sees.
//
// It takes just over a minute to run: the shortest session the app offers is one minute,
// and shortening it for the check would mean checking something the app cannot do.

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

/// The reason WakeSession writes on its blocks — the same string `pmset` prints for them.
let token = "Switch-Work keeps this Mac awake"

/// How `pmset` labels the rows belonging to this process.
let ourProcess = "pid \(ProcessInfo.processInfo.processIdentifier)("

/// The rows of the "Listed by owning process" table that are **ours**.
///
/// Filtered by process id as well as by the reason, because the reason is not unique:
/// the real app writes exactly the same one, and it may well be running on this Mac
/// while the check runs. Filtering by the text alone would count its blocks as ours —
/// which is precisely what happened the first time this check ran.
func ourRows() -> [String] {
    pmset()
        .split(separator: "\n")
        .map(String.init)
        .filter { $0.contains(token) && $0.contains(ourProcess) }
}

@MainActor
func run() {
    // --- CONTROL SAMPLE -----------------------------------------------------
    // Without it "the system no longer sees our block" would pass for the wrong reason
    // on an empty reading.
    let before = pmset()
    print("CONTROL SAMPLE: pmset returned \(before.count) characters")
    check("pmset returns anything at all", before.count > 100)
    check("pmset knows the PreventUserIdleSystemSleep type", before.contains("PreventUserIdleSystemSleep"))
    checkEqual("this process holds no blocks yet", ourRows().count, 0)
    if before.contains(token) {
        print("  note: something else already holds a block under the same reason" +
              " — the app itself, most likely. Filtered out by process id.")
    }

    let session = WakeSession.shared
    check("the switch starts off", !session.isOn)

    // --- TURNING ON FOR ONE MINUTE ------------------------------------------
    let refused = session.turnOn(minutes: 1)
    checkEqual("the system accepted every block", refused.count, 0)
    check("the switch is on", session.isOn)
    check("about a minute left (\(Int(session.remaining)) s)", session.remaining > 55 && session.remaining <= 60)

    let rows = ourRows()
    for row in rows { print("  listed: \(row.trimmingCharacters(in: .whitespaces))") }
    checkEqual("THE SYSTEM LISTS exactly two blocks of ours", rows.count, 2)
    check("one of them is PreventUserIdleSystemSleep",
          rows.contains { $0.contains("PreventUserIdleSystemSleep") })
    check("the other is PreventDiskIdle", rows.contains { $0.contains("PreventDiskIdle") })
    check("the screen is not blocked by default",
          !rows.contains { $0.contains("PreventUserIdleDisplaySleep") })

    // --- THE SCREEN OPTION, ON THE FLY --------------------------------------
    let deadlineBefore = session.remaining
    checkEqual("turning the screen block on was accepted", session.setKeepScreenOn(true).count, 0)
    check("THE SYSTEM SEES the screen block",
          ourRows().contains { $0.contains("PreventUserIdleDisplaySleep") })
    check("the countdown was not reset", session.remaining <= deadlineBefore)

    checkEqual("turning it back off was accepted", session.setKeepScreenOn(false).count, 0)
    check("the screen block is gone from the system",
          !ourRows().contains { $0.contains("PreventUserIdleDisplaySleep") })
    check("the other two still stand", ourRows().count == 2)

    // --- MOVING THE DEADLINE ------------------------------------------------
    // Picking a duration while running moves the end, it does not start a second session.
    _ = session.turnOn(minutes: 2)
    check("the deadline moved out (\(Int(session.remaining)) s)", session.remaining > 110)
    checkEqual("still exactly two blocks, not four", ourRows().count, 2)

    // Back to one minute, so the check does not sit here for two.
    _ = session.turnOn(minutes: 1)

    // --- GOING OUT BY ITSELF ------------------------------------------------
    print("  waiting 70 s for the session to end on its own…")
    let until = Date().addingTimeInterval(70)
    while Date() < until {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(1))
    }

    check("the switch went out by itself", !session.isOn)
    checkEqual("remaining time is zero", Int(session.remaining), 0)
    checkEqual("THE SYSTEM NO LONGER LISTS any block of ours", ourRows().count, 0)

    print("")
    print("PASSED: \(passed), FAILED: \(failed)")
    exit(failed == 0 ? 0 : 1)
}

MainActor.assumeIsolated { run() }
