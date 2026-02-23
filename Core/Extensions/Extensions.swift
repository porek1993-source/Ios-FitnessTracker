// Date+Helpers.swift

import Foundation

extension Date {
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
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
    func rounded(toNearest step: Double) -> Double {
        (self / step).rounded() * step
    }

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
