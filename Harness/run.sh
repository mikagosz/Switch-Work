#!/bin/bash
# Runs a headless check (no window, no Xcode).
#
#   ./Harness/run.sh                          # T1 — sleep blocks
#   ./Harness/run.sh Harness/T2-status-icon.swift  # the toggle icon
#
# swiftc only accepts top-level code in a file called "main.swift", which is why the
# chosen check is copied under that name into the working directory next to it.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
project="$(dirname "$here")"
file="${1:-$here/T1-sleep-block.swift}"
work="$here/.build"

mkdir -p "$work"
cp "$file" "$work/main.swift"

swiftc -O -o "$work/check" \
    "$work/main.swift" \
    "$project/SwitchWork/SleepBlock.swift" \
    "$project/SwitchWork/TimeFormat.swift" \
    "$project/SwitchWork/StatusIcon.swift"

echo "--- $(basename "$file") ---"
"$work/check"
