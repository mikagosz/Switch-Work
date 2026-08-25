#!/bin/bash
# Uruchamia sprawdzian headless (bez okna, bez Xcode).
#
#   ./Harness/uruchom.sh                          # T1 — blokady uspienia
#   ./Harness/uruchom.sh Harness/T2-test-ikony.swift  # ikona przelacznika
#
# swiftc przyjmuje kod na najwyzszym poziomie wylacznie w pliku "main.swift",
# dlatego wybrany sprawdzian trafia pod ta nazwa do katalogu roboczego obok.
set -euo pipefail

katalog="$(cd "$(dirname "$0")" && pwd)"
projekt="$(dirname "$katalog")"
plik="${1:-$katalog/T1-test-blokad.swift}"
robocze="$katalog/.build"

mkdir -p "$robocze"
cp "$plik" "$robocze/main.swift"

swiftc -O -o "$robocze/sprawdzian" \
    "$robocze/main.swift" \
    "$projekt/SwitchWork/BlokadaUspienia.swift" \
    "$projekt/SwitchWork/Czas.swift" \
    "$projekt/SwitchWork/Ikona.swift"

echo "--- $(basename "$plik") ---"
"$robocze/sprawdzian"
