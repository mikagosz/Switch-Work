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
xcodebuild -project Switch-Work.xcodeproj -scheme Switch-Work -configuration Release build
```

The project points `CODE_SIGN_IDENTITY` at a local self-signed certificate by its SHA-1,
which only exists on the author's machines. On any other Mac, sign ad-hoc instead:

```bash
xcodebuild -project Switch-Work.xcodeproj -scheme Switch-Work -configuration Release \
    CODE_SIGN_IDENTITY=- build
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

## Licence

MIT — see [LICENSE](LICENSE).
