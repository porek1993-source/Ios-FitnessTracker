// Date+Helpers.swift

import Foundation

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

    var endOfDay: Date {
        startOfDay.addingTimeInterval(86_400)
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
}

// Array+Safe.swift

extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
