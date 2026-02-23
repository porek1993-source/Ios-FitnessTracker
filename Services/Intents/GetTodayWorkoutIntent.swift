// GetTodayWorkoutIntent.swift
// App Intent pro Siri: "Siri, what is my workout today?"

import AppIntents
import SwiftData

struct GetTodayWorkoutIntent: AppIntent {

    static var title: LocalizedStringResource = "Co mám dnes cvičit?"
    static var description = IntentDescription(
        "Zjistí, jaký trénink máš dnes naplánovaný.",
        categoryName: "Trénink"
    )

    /// Siri přečte toto shrnutí nahlas.
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext

        // Načteme profil
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? context.fetch(descriptor).first else {
            return .result(dialog: "Zatím nemám tvůj profil. Otevři aplikaci a dokonči onboarding.")
        }

        // Najdeme aktivní plán
        guard let plan = profile.workoutPlans.first(where: \.isActive) else {
            return .result(dialog: "Nemáš aktivní tréninkový plán. Otevři aplikaci a vygeneruj si nový.")
        }

        // Najdeme dnešní den
        let today = Date.now
        let weekday = Calendar.current.component(.weekday, from: today) // 1=Sun, 2=Mon...
        let projectDayOfWeek = ((weekday - 2) + 7) % 7 + 1 // 1=Po, ..., 7=Ne

        guard let todayDay = plan.scheduledDays.first(where: { $0.dayOfWeek == projectDayOfWeek }) else {
            return .result(dialog: "Na dnešek nemáš naplánovaný žádný trénink. Odpočívej! 💪")
        }

        // Sestavíme textové shrnutí
        let exerciseNames = todayDay.plannedExercises.prefix(4).compactMap { $0.exercise?.name }.joined(separator: ", ")
        let summary: String

        if todayDay.plannedExercises.isEmpty {
            summary = "Dnes máš \(todayDay.label), ale zatím nemáš naplánované žádné cviky."
        } else {
            summary = "Dnes máš \(todayDay.label). Začínáš cviky: \(exerciseNames)."
        }

        return .result(dialog: "\(summary)")
    }
}
