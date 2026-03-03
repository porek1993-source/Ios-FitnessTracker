// ToggleDeloadIntent.swift
// App Intent pro Siri: "Siri, přepni na deload"
// ✅ deepanal.pdf: "2–5 nejčastějších akcí jako předpřipravené App Shortcuts"

import AppIntents
import SwiftData

struct ToggleDeloadIntent: AppIntent {
    
    static var title: LocalizedStringResource { "Přepnout deload" }
    static var description: IntentDescription {
        IntentDescription(
            "Zapne nebo vypne deload režim (snížený objem tréninku).",
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
        
        // Toggle deload
        profile.isDeloadRecommended.toggle()
        try? context.save()
        
        if profile.isDeloadRecommended {
            return .result(dialog: "Deload zapnut 🧘 Tréninky budou mít snížený objem a intenzitu. Tvoje tělo ti poděkuje!")
        } else {
            return .result(dialog: "Deload vypnut 🔥 Vracíme se k plné intenzitě!")
        }
    }
}
