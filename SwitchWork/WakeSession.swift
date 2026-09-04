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

    /// How long the running session was set for, in seconds.
    ///
    /// Needed for the icon's shrinking fill: `remaining` alone says how much is left, but
    /// not how much that is *out of*. Set again on every `turnOn`, because turning on
    /// while a session runs moves the deadline — from the user's point of view that is a
    /// new stretch of time, and the fill should start over full rather than jump.
    private(set) var totalDuration: TimeInterval = 0

    /// Called after every state change — the icon and the menu refresh from this one place.
    var onChange: (() -> Void)?

    var isOn: Bool { endsAt != nil }

    var remaining: TimeInterval {
        guard let endsAt else { return 0 }
        return max(0, endsAt.timeIntervalSinceNow)
    }

    /// Share of the session still ahead, `0…1`. Zero when the switch is off.
    ///
    /// Clamped on both ends: the deadline timer has a second of slack, so `remaining`
    /// can briefly exceed the total after a change, and a fill drawn past full would
    /// wrap around to an empty disc — the exact opposite of what it means.
    var progress: Double {
        guard isOn, totalDuration > 0 else { return 0 }
        return min(1, max(0, remaining / totalDuration))
    }

    /// Whether the screen is kept awake along with the system. Survives a restart.
    var keepScreenOn: Bool { UserDefaults.standard.bool(forKey: Defaults.keepScreenOn) }

    /// Turns the screen block on or off. Changed on the fly: while a session runs, the
    /// block is added or removed without resetting the countdown.
    ///
    /// - Returns: the blocks the system **refused**. Empty means all is well. On a refusal
    ///   the setting goes back to where it was — a tick in the menu next to a block the
    ///   system is not holding would be the same silent lie as a glowing icon over a Mac
    ///   that sleeps anyway.
    @discardableResult
    func setKeepScreenOn(_ newValue: Bool) -> [BlockKind] {
        UserDefaults.standard.set(newValue, forKey: Defaults.keepScreenOn)

        var refused: [BlockKind] = []
        if isOn { refused = block.apply(wantedBlocks, reason: Self.reason) }

        if !refused.isEmpty {
            UserDefaults.standard.set(!newValue, forKey: Defaults.keepScreenOn)
            if isOn { _ = block.apply(wantedBlocks, reason: Self.reason) }
        }

        onChange?()
        return refused
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
        totalDuration = TimeInterval(minutes) * 60
        endsAt = Date().addingTimeInterval(totalDuration)
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
        totalDuration = 0
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
