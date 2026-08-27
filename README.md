# Switch-Work

A tiny macOS menu bar switch that keeps your Mac awake for a set time, then turns
itself off.

Made for laptop work: you leave a long task running — a build, a sync, an agent — walk
away from the machine, and the Mac falls asleep a minute later and kills it. One click
on the menu bar icon and it does not, until the time you picked runs out.

- **Off** — a monochrome power outline that follows your menu bar colour.
- **On** — the same outline in black on a green circle.

## What it blocks

| Block | When | Effect |
|---|---|---|
| `PreventUserIdleSystemSleep` | always while on | the Mac will not sleep when idle |
| `PreventDiskIdle` | always while on | disks will not spin down or park |
| `PreventUserIdleDisplaySleep` | only with the menu option ticked | the display stays lit |

**The screen is allowed to go dark by default.** On battery it is the most expensive
thing to keep alive, and a background task does not need it. "Keep the screen on too"
sits in the menu and takes effect immediately, without resetting the countdown.

## It does not change your system settings

Switch-Work never touches System Settings or `pmset`. It takes an IOKit power assertion
(`IOPMAssertionCreateWithName` — the same mechanism `caffeinate` uses), and an assertion
is tied to the process that holds it.

That means there is nothing to restore: the block disappears when you turn the switch
off, when you quit the app, **and if the app ever crashes**. A tool that edited your
sleep settings could die halfway and leave your Mac unable to sleep at all.

## What it cannot stop

- **A closed lid.** Lid sleep is a different path from idle sleep and no power assertion
  holds it back (without external power and a display).
- **A critically low battery.** The system will sleep regardless.

## Menu

State line (`Switch-Work is off` / `Awake — 1 hr 47 min left`), then `Turn off now` while
running, three durations — **1 hour, 2 hours, my own time…** — the screen option, and
`Quit`. Picking a duration while already running moves the deadline instead of starting
over, which is why those items read "Set to…" then.

If macOS refuses a block, the app says so in an alert. A silent refusal would be the
worst outcome: a glowing icon over a Mac that sleeps anyway.

## Requirements

macOS 26.0 or newer. No network access, no analytics, no files written outside
`UserDefaults` (two keys: the screen option and the last custom duration).

## Build

```bash
xcodebuild -project Switch-Work.xcodeproj -scheme Switch-Work -configuration Release \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO build
```

`CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` is not decoration. Without it, `xcodebuild … build`
signs the app with `com.apple.security.get-task-allow` **even in Release** — the entitlement
that lets any process running as you attach a debugger to it and read its memory. Building
through `xcodebuild … archive` drops the entitlement on its own; plain `build` does not.
Check whichever way you build:

```bash
codesign -d --entitlements - Switch-Work.app
```

An empty `[Dict]` is what you want.

The project points `CODE_SIGN_IDENTITY` at a local self-signed certificate by its SHA-1,
which only exists on the author's machines. On any other Mac, sign ad-hoc instead:

```bash
xcodebuild -project Switch-Work.xcodeproj -scheme Switch-Work -configuration Release \
    CODE_SIGN_IDENTITY=- CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO build
```

Ad-hoc is enough to run the app yourself. It is not enough for anything that ties
permissions to a stable code signature.

## Checks

Headless, no Xcode and no window:

```bash
./Harness/run.sh                          # sleep blocks
./Harness/run.sh Harness/T2-status-icon.swift  # the toggle icon
```

T1 does not ask the app about its own state — it reads `pmset -g assertions` and filters
for a unique token, so it verifies what the system actually sees. T2 counts pixels of the
rendered icon. Both start with a control sample, so a zero means "not there" rather than
"the check is broken".

## Uninstalling

Move the app to the Trash. It creates no folders, no launch agent and no login item —
the only thing it leaves behind is its two settings, in one file:

```bash
defaults delete com.mikagosz.SwitchWork
```

That is the same as deleting `~/Library/Preferences/com.mikagosz.SwitchWork.plist`.
Any sleep block the app was holding is gone the moment it quits, so there is nothing
to undo in the system.

## Licence

The **source code** is MIT — see [LICENSE](LICENSE).

The **app icon is not**. `SwitchWork/Switch-Work.icon/` is Copyright (c) 2026
mikagosz, all rights reserved, and is excluded from the MIT grant — see [NOTICE](NOTICE).
It ships with the repository so the project builds as it is shipped; if you fork this
project, replace it with your own icon.

The menu bar toggle itself is not artwork — it is drawn at runtime from Apple's SF
Symbols, under Apple's terms.
