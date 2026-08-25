//
//  WakeSession.swift
//  Switch-Work
//
//  The state of the switch: whether we are keeping the Mac awake, until when,
//  and what exactly is blocked.
//

import AppKit

@MainActor
final class WakeSession {

    static let shared = WakeSession()

    /// The text shown next to our entry in `pmset -g assertions`.
    private static let reason = "Switch-Work keeps this Mac awake"

    private let block = SleepBlock()
    private var deadlineTimer: Timer?

    /// When the session ends. `nil` means the switch is off.
    private(set) var endsAt: Date?

    /// Called after every state change — the icon and the menu refresh from this one place.
    var onChange: (() -> Void)?

    var isOn: Bool { endsAt != nil }

    var remaining: TimeInterval {
        guard let endsAt else { return 0 }
        return max(0, endsAt.timeIntervalSinceNow)
    }

    /// Whether the screen is kept awake along with the system. Survives a restart.
    var keepScreenOn: Bool {
        get { UserDefaults.standard.bool(forKey: Defaults.keepScreenOn) }
        set {
            UserDefaults.standard.set(newValue, forKey: Defaults.keepScreenOn)
            // Changed on the fly: while a session runs, the screen block is added or
            // removed without resetting the countdown.
            if isOn { _ = block.apply(wantedBlocks, reason: Self.reason) }
            onChange?()
        }
    }

    private init() {
        // Timers do not fire while the Mac sleeps. If it slept anyway despite the blocks
        // (a closed lid), the deadline has to be checked against the date after waking
        // rather than waited for.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(afterWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    /// Starts a session for the given number of minutes (or moves the deadline when one
    /// is already running).
    ///
    /// - Returns: the blocks the system **refused**. Empty means all is well. When the
    ///   system block is refused the switch falls back to OFF — without it nothing would
    ///   be protected and a green icon would be a lie.
    @discardableResult
    func turnOn(minutes: Int) -> [BlockKind] {
        endsAt = Date().addingTimeInterval(TimeInterval(minutes) * 60)
        let refused = block.apply(wantedBlocks, reason: Self.reason)

        if refused.contains(.system) {
            turnOff()
            return refused
        }

        scheduleDeadline()
        onChange?()
        return refused
    }

    /// Ends the session and drops every block — the system goes back to its own settings.
    func turnOff() {
        endsAt = nil
        deadlineTimer?.invalidate()
        deadlineTimer = nil
        block.releaseAll()
        onChange?()
    }

    /// The blocks that should be held in the system with the current settings.
    private var wantedBlocks: Set<BlockKind> {
        guard isOn else { return [] }
        var wanted: Set<BlockKind> = [.system, .disk]
        if keepScreenOn { wanted.insert(.display) }
        return wanted
    }

    private func scheduleDeadline() {
        deadlineTimer?.invalidate()
        guard let endsAt else { return }
        // A second of slack, so the timer does not fire just before the deadline and
        // bounce off `checkDeadline` in a loop.
        let timer = Timer(
            fireAt: endsAt.addingTimeInterval(1),
            interval: 0,
            target: self,
            selector: #selector(checkDeadline),
            userInfo: nil,
            repeats: false
        )
        // .common — otherwise the timer stays silent while the menu bar menu is open.
        RunLoop.main.add(timer, forMode: .common)
        deadlineTimer = timer
    }

    @objc private func checkDeadline() {
        guard isOn else { return }
        if remaining <= 0 { turnOff() } else { scheduleDeadline() }
    }

    @objc private func afterWake() {
        checkDeadline()
    }
}
