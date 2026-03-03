// LogFatigueIntent.swift
// App Intent pro Siri: "Siri, log that my shoulders hurt"

import AppIntents
import SwiftData

struct LogFatigueIntent: AppIntent {

    static var title: LocalizedStringResource { "Zaznamenat únavu svalu" }
    static var description: IntentDescription {
        IntentDescription(
            "Zapíše únavu nebo bolest svalové skupiny do kontextu pro AI trenéra.",
            categoryName: "Trénink"
        )
    }

    /// Svalová skupina, kterou chce uživatel zaznamenat.
    @Parameter(title: "Svalová skupina", description: "Například: ramena, záda, nohy, kolena")
    var muscleGroup: String

    /// Úroveň závažnosti (1 = lehká, 5 = těžká).
    @Parameter(title: "Závažnost (1–5)", default: 3)
    var severity: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let clampedSeverity = max(1, min(5, severity))

        // Uložíme záznam přes FatigueStore (sdílený úložiště pro HeatmapView i Siri)
        let area = MuscleArea(
            id: muscleGroup.lowercased(),
            slug: muscleGroup.lowercased(),
            displayName: muscleGroup.capitalized,
            isFrontSide: true,
            relX: 0.5, relY: 0.5, relW: 0.1, relH: 0.1
        )
        let entry = FatigueEntry(areaSlug: area.slug, severity: clampedSeverity, isJointPain: clampedSeverity >= 4)
        FatigueStore.save([entry])

        let severityText = switch clampedSeverity {
        case 1...2: "lehká"
        case 3:     "střední"
        default:    "výrazná"
        }

        return .result(
            dialog: "Zaznamenáno! \(muscleGroup.capitalized) — \(severityText) únava (stupeň \(clampedSeverity)/5). Trenér iKorba to zohlední příště. 👍"
        )
    }
}

// MARK: - Siri Shortcuts Provider

struct AgileFitnessShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTodayWorkoutIntent(),
            phrases: [
                "Co mám dnes cvičit v \(.applicationName)?",
                "Jaký je můj trénink v \(.applicationName)?",
                "What is my workout today in \(.applicationName)?"
            ],
            shortTitle: "Dnešní trénink",
            systemImageName: "figure.strengthtraining.traditional"
        )
        AppShortcut(
            intent: LogFatigueIntent(),
            phrases: [
                "Zaznamenej únavu v \(.applicationName)",
                "Log fatigue in \(.applicationName)",
                "Bolí mě svaly v \(.applicationName)"
            ],
            shortTitle: "Zaznamenat únavu",
            systemImageName: "bandage"
        )
        // ✅ Nové Siri Shortcuts dle deepanal.pdf (body 13)
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Začni trénink v \(.applicationName)",
                "Spusť cvičení v \(.applicationName)",
                "Start workout in \(.applicationName)"
            ],
            shortTitle: "Začít trénink",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: WeeklyProgressIntent(),
            phrases: [
                "Kolik jsem tento týden cvičil v \(.applicationName)?",
                "Týdenní progres v \(.applicationName)",
                "Weekly progress in \(.applicationName)"
            ],
            shortTitle: "Týdenní progres",
            systemImageName: "chart.bar.fill"
        )
        AppShortcut(
            intent: ToggleDeloadIntent(),
            phrases: [
                "Přepni deload v \(.applicationName)",
                "Toggle deload in \(.applicationName)",
                "Zapni odpočinek v \(.applicationName)"
            ],
            shortTitle: "Přepnout deload",
            systemImageName: "leaf.fill"
        )
    }
}
