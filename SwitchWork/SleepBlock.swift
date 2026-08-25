//
//  SleepBlock.swift
//  Switch-Work
//
//  The core of the app: telling macOS not to fall asleep.
//

import Foundation
import IOKit.pwr_mgt

/// The kinds of block macOS uses to steer sleep.
///
/// The raw values are the literals from `<IOKit/pwr_mgt/IOPMLib.h>` — the exact names
/// `pmset -g assertions` prints. They are spelled out here rather than taken from the
/// header constants because `kIOPMAssertPreventDiskIdle` is not bridged into Swift
/// (the other two are; all three are written the same way for consistency).
enum BlockKind: String, CaseIterable {
    /// The Mac will not fall asleep when idle. Without this one the rest is pointless.
    case system = "PreventUserIdleSystemSleep"
    /// Disks will not spin down or park when idle.
    case disk = "PreventDiskIdle"
    /// The display stays lit. The most expensive one on battery, so it is off by default.
    case display = "PreventUserIdleDisplaySleep"
}

/// Holds the handles to the system blocks and keeps the state in the system in sync
/// with what was asked for.
///
/// It deliberately does **not** touch the user's own settings (`pmset`): a block is tied
/// to this process, so it disappears on its own — when the switch is turned off, when the
/// app quits, and when the app crashes. There is nothing to "restore to the previous
/// state", because nothing was changed.
final class SleepBlock {

    private var handles: [BlockKind: IOPMAssertionID] = [:]

    /// The blocks that are really held in the system right now.
    var active: Set<BlockKind> { Set(handles.keys) }

    /// Brings the system to the requested set of blocks — adds what is missing, drops
    /// what is no longer wanted.
    ///
    /// - Returns: the blocks the system **refused**. An empty array means all is well.
    @discardableResult
    func apply(_ wanted: Set<BlockKind>, reason: String) -> [BlockKind] {
        var refused: [BlockKind] = []

        for kind in BlockKind.allCases where wanted.contains(kind) && handles[kind] == nil {
            if !acquire(kind, reason: reason) { refused.append(kind) }
        }
        for kind in BlockKind.allCases where !wanted.contains(kind) {
            release(kind)
        }
        return refused
    }

    /// Drops everything — the system goes back to its usual sleep settings.
    func releaseAll() {
        _ = apply([], reason: "")
    }

    private func acquire(_ kind: BlockKind, reason: String) -> Bool {
        var handle: IOPMAssertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kind.rawValue as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &handle
        )
        guard result == kIOReturnSuccess else { return false }
        handles[kind] = handle
        return true
    }

    private func release(_ kind: BlockKind) {
        guard let handle = handles.removeValue(forKey: kind) else { return }
        IOPMAssertionRelease(handle)
    }

    deinit {
        for (_, handle) in handles { IOPMAssertionRelease(handle) }
    }
}
