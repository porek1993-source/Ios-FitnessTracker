// StartWorkoutIntent.swift
// App Intent pro Siri: "Siri, začni trénink"
// ✅ deepanal.pdf: "2–5 nejčastějších akcí jako předpřipravené App Shortcuts"

import AppIntents
import SwiftData

struct StartWorkoutIntent: AppIntent {
    
    static var title: LocalizedStringResource { "Začít trénink" }
    static var description: IntentDescription {
        IntentDescription(
            "Spustí dnešní trénink nebo otevře aplikaci na dashboardu.",
            categoryName: "Trénink"
        )
    }
    
    static var openAppWhenRun: Bool { true }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? context.fetch(descriptor).first else {
            return .result(dialog: "Nejdřív dokonči onboarding v aplikaci.")
        }
        
        guard let plan = profile.workoutPlans.first(where: \.isActive) else {
            return .result(dialog: "Nemáš aktivní plán. Otevři aplikaci a vygeneruj nový.")
        }
        
        let dayOfWeek = Date.now.weekday
        guard let todayDay = plan.scheduledDays.first(where: { $0.dayOfWeek == dayOfWeek && !$0.isRestDay }) else {
            return .result(dialog: "Dnes máš den volna. Odpočívej! 💪")
        }
        
        // Pošleme notifikaci pro spuštění tréninku
        NotificationCenter.default.post(
            name: NSNotification.Name("StartWorkoutFromSiri"),
            object: nil
        )
        
        let exercises = todayDay.sortedExercises.prefix(3).compactMap { $0.exercise?.name }.joined(separator: ", ")
        return .result(dialog: "Spouštím \(todayDay.label). Začínáš: \(exercises). Pojďme na to! 🔥")
    }
}
