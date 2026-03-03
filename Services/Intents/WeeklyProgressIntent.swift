// WeeklyProgressIntent.swift
// App Intent pro Siri: "Siri, kolik jsem tento týden odcvičil?"
// ✅ deepanal.pdf: "2–5 nejčastějších akcí jako předpřipravené App Shortcuts"

import AppIntents
import SwiftData

struct WeeklyProgressIntent: AppIntent {
    
    static var title: LocalizedStringResource { "Týdenní progres" }
    static var description: IntentDescription {
        IntentDescription(
            "Zjistí, kolik tréninků jsi tento týden splnil.",
            categoryName: "Trénink"
        )
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? context.fetch(descriptor).first else {
            return .result(dialog: "Zatím nemám tvůj profil.")
        }
        
        guard let plan = profile.workoutPlans.first(where: \.isActive) else {
            return .result(dialog: "Nemáš aktivní plán.")
        }
        
        // Spočítáme splněné tréninky tento týden
        let startOfWeek = Calendar.mondayStart.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let completedThisWeek = plan.sessions.filter {
            $0.startedAt >= startOfWeek && $0.status == .completed
        }.count
        
        let plannedDays = plan.scheduledDays.filter { !$0.isRestDay }.count
        let remaining = max(0, plannedDays - completedThisWeek)
        
        if completedThisWeek == 0 {
            return .result(dialog: "Tento týden jsi zatím netrénoval. Plán je \(plannedDays) tréninků — začni dnes! 💪")
        }
        
        if remaining == 0 {
            return .result(dialog: "Skvěle! Splnil jsi všech \(completedThisWeek) tréninků tento týden. 🏆 Odpočívej a nabírej sílu!")
        }
        
        return .result(dialog: "Tento týden: \(completedThisWeek) z \(plannedDays) tréninků splněno. Zbývá ti \(remaining). Drž to! 🔥")
    }
}
