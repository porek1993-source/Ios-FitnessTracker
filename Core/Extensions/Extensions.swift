// Date+Helpers.swift

import Foundation

// MARK: - Calendar helper
//
// ✅ FIX: Calendar.current firstWeekday závisí na locale zařízení.
// Na US zařízeních (locale = en_US) začíná týden v NEDĚLI (firstWeekday=1).
// Česká aplikace počítá s pondělním začátkem týdne (firstWeekday=2).
//
// Použití Calendar.mondayStart namísto Calendar.current v jakékoliv logice,
// která pracuje s týdny (weekOfYear, dateInterval(.weekOfYear), apod.)
// zajišťuje konzistentní chování napříč všemi locales.
extension Calendar {
    /// Gregoriánský kalendář s pevně nastaveným pondělním začátkem týdne.
    /// Locale-independent — chová se stejně na US i EU zařízeních.
    static var mondayStart: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2   // 1=Sun, 2=Mon
        cal.locale = Locale.current
        return cal
    }
}

extension Date {
    /// Vrátí den týdne v naší konvenci: 1=Pondělí … 7=Neděle
    /// (Swift .weekday vrací 1=Neděle, proto konvertujeme)
    var weekday: Int {
        let swiftWeekday = Calendar.current.component(.weekday, from: self)
        // Swift: 1=Sun, 2=Mon … 7=Sat → naše: 1=Mon … 7=Sun
        return swiftWeekday == 1 ? 7 : swiftWeekday - 1
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Konec dne — DST-bezpečná implementace pomocí Calendar.
    /// ✅ FIX #16: addingTimeInterval(86_400) je špatné pro dny se změnou letního času (DST),
    /// kde má den 23 nebo 25 hodin. Calendar.date(byAdding:) respektuje DST správně.
    var endOfDay: Date {
        // Přidáme 1 den a vezmeme startOfDay — výsledek je přesně začátek zítřka = konec dneška
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86_400)
        return tomorrow
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

// Double+Formatting.swift

extension Double {

    var kgFormatted: String {
        self.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f kg", self)
            : String(format: "%.1f kg", self)
    }

    /// Formátuje objem (kg vs t) podle velikosti
    func formatVolume() -> String {
        if self < 1000 {
            return self.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f kg", self)
                : String(format: "%.1f kg", self)
        } else {
            let tonnes = self / 1000.0
            return String(format: "%.1f t", tonnes)
        }
    }

    /// Zaokrouhlí číslo na nejbližší násobek `toNearest`.
    /// Příklad: 102.3.rounded(toNearest: 2.5) → 102.5
    /// ✅ Přesunuto z WorkoutViewModel.swift do Extensions.swift — sdílená utility
    func rounded(toNearest value: Double) -> Double {
        (self / value).rounded() * value
    }
}

// Array+Safe.swift

extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
