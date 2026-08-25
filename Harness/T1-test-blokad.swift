import Foundation

// Harness T1 — czy blokada uspienia naprawde siedzi w systemie.
//
// Sedno programu: klikniecie w ikone ma sprawic, ze macOS nie zasnie. Kod, ktory
// tworzy blokade i nie sprawdza wyniku, wyglada identycznie jak dzialajacy —
// dlatego ten sprawdzian nie pyta naszego obiektu o jego wlasny stan, tylko czyta
// `pmset -g assertions`, czyli to, co widzi system.

var passed = 0
var failed = 0

func check(_ label: String, _ condition: Bool) {
    if condition { passed += 1 } else { failed += 1; print("  CZERWONE: \(label)") }
}

func checkEqual<T: Equatable>(_ label: String, _ lhs: T, _ rhs: T) {
    if lhs == rhs { passed += 1 } else { failed += 1; print("  CZERWONE: \(label) — jest \(lhs), ma byc \(rhs)") }
}

/// Surowy odczyt z systemu — nie z naszego obiektu.
func pmset() -> String {
    let proces = Process()
    proces.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    proces.arguments = ["-g", "assertions"]
    let rura = Pipe()
    proces.standardOutput = rura
    try? proces.run()
    let dane = rura.fileHandleForReading.readDataToEndOfFile()
    proces.waitUntilExit()
    return String(data: dane, encoding: .utf8) ?? ""
}

// Token wpisywany jako powod blokady. Wystarczajaco dziwny, zeby nie trafil sie
// przypadkiem u innego programu.
let token = "SwitchWork-harness-T1-4f2a"

func systemWidzi(_ igla: String) -> Bool { pmset().contains(igla) }

let blokada = BlokadaUspienia()

// --- PROBKA KONTROLNA -------------------------------------------------------
// Bez tego "system widzi nasza blokade" nie znaczyloby nic: gdyby pmset zwracal
// pusty tekst, kazde sprawdzenie "nie ma" przechodzilo by na zielono.
let przedStartem = pmset()
print("PROBKA KONTROLNA: pmset zwrocil \(przedStartem.count) znakow")
check("pmset w ogole cos zwraca", przedStartem.count > 100)
check("pmset zna typ PreventUserIdleSystemSleep", przedStartem.contains("PreventUserIdleSystemSleep"))
check("naszego tokenu jeszcze nie ma", !przedStartem.contains(token))
checkEqual("obiekt startuje bez blokad", blokada.aktywne.count, 0)

// --- WLACZENIE: system + dyski, bez ekranu ----------------------------------
let odmowione1 = blokada.ustaw([.system, .dyski], powod: token)
checkEqual("system przyjal obie blokady", odmowione1.count, 0)
checkEqual("obiekt trzyma dwa uchwyty", blokada.aktywne.count, 2)
check("SYSTEM WIDZI nasza blokade po powodzie", systemWidzi(token))

/// Wiersze wykazu "Listed by owning process", ktore niosa nasz token — czyli
/// dokladnie te blokady, ktore zalozyl ten proces, a nie ktokolwiek inny w systemie.
func naszeWiersze() -> [String] {
    pmset().split(separator: "\n").map(String.init).filter { $0.contains(token) }
}

let wiersze2 = naszeWiersze()
for wiersz in wiersze2 { print("  wykaz: \(wiersz.trimmingCharacters(in: .whitespaces))") }
checkEqual("system wykazuje dokladnie dwie NASZE blokady", wiersze2.count, 2)
check("jedna z nich to PreventUserIdleSystemSleep",
      wiersze2.contains { $0.contains("PreventUserIdleSystemSleep") })
check("druga to PreventDiskIdle", wiersze2.contains { $0.contains("PreventDiskIdle") })
check("ekranu jeszcze nie blokujemy",
      !wiersze2.contains { $0.contains("PreventUserIdleDisplaySleep") })

// Kontrola dodatnia dla licznika zbiorczego u gory wykazu: przy naszym typie
// ma stac liczba, i to co najmniej jeden.
func licznik(_ typ: String) -> Int? {
    for linia in pmset().split(separator: "\n") {
        let pola = linia.split(separator: " ")
        if pola.count == 2, pola[0] == typ, let liczba = Int(pola[1]) { return liczba }
    }
    return nil
}
let ile = licznik("PreventUserIdleSystemSleep")
print("  licznik zbiorczy PreventUserIdleSystemSleep: \(ile.map(String.init) ?? "brak wiersza")")
check("licznik zbiorczy istnieje i nie stoi na zerze", (ile ?? 0) >= 1)

// --- DOLOZENIE EKRANU W LOCIE -----------------------------------------------
let odmowione2 = blokada.ustaw([.system, .dyski, .ekran], powod: token)
checkEqual("ekran tez przyjety", odmowione2.count, 0)
checkEqual("trzy uchwyty", blokada.aktywne.count, 3)
let wiersze3 = naszeWiersze()
checkEqual("system wykazuje trzy NASZE blokady", wiersze3.count, 3)
check("SYSTEM WIDZI nasza blokade ekranu",
      wiersze3.contains { $0.contains("PreventUserIdleDisplaySleep") })

// --- ZDJECIE SAMEGO EKRANU --------------------------------------------------
_ = blokada.ustaw([.system, .dyski], powod: token)
checkEqual("wrocilismy do dwoch uchwytow", blokada.aktywne.count, 2)
let wiersze4 = naszeWiersze()
checkEqual("znowu dwie NASZE blokady", wiersze4.count, 2)
check("blokada ekranu znikla", !wiersze4.contains { $0.contains("PreventUserIdleDisplaySleep") })
check("blokada systemu nadal stoi", wiersze4.contains { $0.contains("PreventUserIdleSystemSleep") })

// --- WYLACZENIE -------------------------------------------------------------
blokada.zdejmijWszystkie()
checkEqual("obiekt nie trzyma nic", blokada.aktywne.count, 0)
check("SYSTEM JUZ NIE WIDZI naszej blokady", !systemWidzi(token))

// --- CZAS: opis i sito na wpisany tekst -------------------------------------
check("ponizej minuty ma wlasny opis", Czas.opis(30).contains("minute") || Czas.opis(30).contains("minuta"))
check("godzina opisana niepusto", !Czas.opis(3600).isEmpty)
check("1 h 47 min zawiera 47", Czas.opis(3600 + 47 * 60).contains("47"))

checkEqual("60 minut przechodzi", Czas.minuty(zTekstu: "60"), 60)
checkEqual("spacje wokol liczby nie przeszkadzaja", Czas.minuty(zTekstu: "  90 "), 90)
check("zero odrzucone", Czas.minuty(zTekstu: "0") == nil)
check("liczba ujemna odrzucona", Czas.minuty(zTekstu: "-5") == nil)
check("tekst odrzucony", Czas.minuty(zTekstu: "godzina") == nil)
check("pusty odrzucony", Czas.minuty(zTekstu: "") == nil)
check("liczba ponad tydzien odrzucona", Czas.minuty(zTekstu: "999999") == nil)
checkEqual("dokladnie tydzien przechodzi", Czas.minuty(zTekstu: "\(Czas.maksMinuty)"), Czas.maksMinuty)

print("")
print("ZIELONE: \(passed), CZERWONE: \(failed)")
exit(failed == 0 ? 0 : 1)
