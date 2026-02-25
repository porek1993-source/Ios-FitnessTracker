// WeeklyReportService.swift

import Foundation
import SwiftData

/// Výsledek týdenní analýzy od AI
struct WeeklyReportResult: Codable, Hashable {
    let summary: String
    let praise: String
    let mistakes: String
    let motivation: String
    let createdAt: Date
}

@MainActor
final class WeeklyReportService {
    
    // Klíč může být zapsán v Constants, prozatím použijeme stub z appky
    private let geminiClient = GeminiAPIClient(apiKey: "API_KEY_PLACEHOLDER")
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Spustí generování týdenního hodnocení za posledních 7 dní
    func generateWeeklyReport(for profile: UserProfile) async throws -> WeeklyReportResult {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        
        // 1. Získáme odjeté tréninky
        let sessionsDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.startedAt >= startDate && $0.startedAt <= endDate }
        )
        let sessions = try modelContext.fetch(sessionsDescriptor)
        
        // 2. Získáme zdravotní data
        let healthDescriptor = FetchDescriptor<HealthMetricsSnapshot>(
            predicate: #Predicate { $0.date >= startDate && $0.date <= endDate }
        )
        let healthSnapshots = try modelContext.fetch(healthDescriptor)
        
        // 3. Zpracování dat pro prompt
        let workoutsSummary = buildWorkoutsSummary(sessions: sessions)
        let healthSummary = buildHealthSummary(snapshots: healthSnapshots)
        
        // 4. Prompt
        let systemPrompt = """
        Jsi Jakub, elitní a empatický silový trenér (Agilní Fitness Trenér).
        Tvým úkolem je zhodnotit posledních 7 dní cvičence a poskytnout mu týdenní report.
        Mluv česky. Buď profesionální, povzbudivý, ale upřímný, pokud vidíš chyby (např. málo spánku, vynechané tréninky).
        
        Vypiš data ve formátu JSON:
        {
          "summary": "Celkové krátké shrnutí týdne do 2 vět.",
          "praise": "Pochvala za to, co se povedlo (např. konzistence, rekordy).",
          "mistakes": "Konstruktivní kritika, kde je prostor pro zlepšení (např. spánek, HRV pokles, nedodržení RIR).",
          "motivation": "Krátké namotivování do dalšího týdne."
        }
        """
        
        let userMessage = """
        Zhodnoť můj uplynulý týden.
        
        Profil: \(profile.name), Cíl: \(profile.primaryGoal.displayName), Úroveň: \(profile.fitnessLevel.displayName)
        
        \(workoutsSummary)
        
        \(healthSummary)
        """
        
        // Definice Otevřeného JSON schématu pro Gemini (dle dokumentace APIClienta to bere dictionary)
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "summary": ["type": "STRING"],
                "praise": ["type": "STRING"],
                "mistakes": ["type": "STRING"],
                "motivation": ["type": "STRING"]
            ],
            "required": ["summary", "praise", "mistakes", "motivation"]
        ]
        
        // 5. Odeslání požadavku
        let responseString = try await geminiClient.generate(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            responseSchema: schema
        )
        
        // 6. Parsování výsledku
        guard let data = responseString.data(using: .utf8) else {
            throw AppError.unknown // nebo vlastní error
        }
        
        let decoder = JSONDecoder()
        var report = try decoder.decode(WeeklyReportResult.self, from: data)
        report = WeeklyReportResult(
            summary: report.summary,
            praise: report.praise,
            mistakes: report.mistakes,
            motivation: report.motivation,
            createdAt: Date()
        )
        
        return report
    }
    
    // MARK: - Pomocné metody pro sestavení kontextu
    
    private func buildWorkoutsSummary(sessions: [WorkoutSession]) -> String {
        guard !sessions.isEmpty else {
            return "Tréninky: Tento týden nebyl zaznamenán žádný trénink."
        }
        var text = "Odcvičené tréninky (" + String(sessions.count) + "x):\n"
        for session in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            text += "- \(session.plannedDayName) (Délka: \(session.durationMinutes) min)\n"
            text += "  Cviky: " + session.exercises.map { $0.exerciseName }.joined(separator: ", ") + "\n"
            // Zde můžeme přidat i analýzu PRs z ProgressiveOverloadUseCase, nebo např celkovou tonáž
        }
        return text
    }
    
    private func buildHealthSummary(snapshots: [HealthMetricsSnapshot]) -> String {
        guard !snapshots.isEmpty else {
            return "Zdraví: Nebyla synchronizována žádná HealthKit data."
        }
        
        let sleepAvg = snapshots.compactMap { $0.sleepDurationHours }.reduce(0, +) / Double(snapshots.count)
        let hrvAvg = snapshots.compactMap { $0.heartRateVariabilityMs }.reduce(0, +) / Double(snapshots.count)
        let readinessAvg = snapshots.compactMap { $0.readinessScore }.reduce(0, +) / Double(snapshots.count)
        
        var text = "Průměrné zdravotní metriky za týden:\n"
        text += String(format: "- Průměrný spánek: %.1f hodin\n", sleepAvg)
        text += String(format: "- Průměrné HRV: %.0f ms\n", hrvAvg)
        text += String(format: "- Průměrné skóre připravenosti (Readiness): %.0f/100\n", readinessAvg)
        
        text += "\nAktivity mimo fitko (Kardio/Sport):\n"
        let acts = snapshots.flatMap { $0.externalActivities }
        if acts.isEmpty {
            text += "Žádné zaznamenané."
        } else {
            for act in acts {
                text += "- \(act.type): \(act.durationMinutes) min (\(act.energyKcal) kcal)\n"
            }
        }
        return text
    }
}

// Chlazení pro kód v SwiftDate extensions nebo Error handlingu:
extension WeeklyReportResult {
    // Pro zpětnou kompatibilitu do modelu, pokud bychom chtěli ukládat
}

// MARK: - Push Notification Scheduling

import UserNotifications

extension WeeklyReportService {

    /// Naplánuje týdenní push notifikaci (každou neděli v 19:00)
    static func scheduleWeeklyNotificationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            WeeklyReportService.scheduleWeeklyTrigger()
        }
    }

    private static func scheduleWeeklyTrigger() {
        let center = UNUserNotificationCenter.current()

        // Odstraň starou notifikaci, aby se neduplíkovala
        center.removePendingNotificationRequests(withIdentifiers: ["weekly_report"])

        let content = UNMutableNotificationContent()
        content.title = "Tvůj týdenní report 📊"
        content.body  = "Jakub má pro tebe shrnutí minulého týdne. Podívej se, jak ses zlepšil!"
        content.sound = .default

        // Každou neděli v 19:00
        var dateComponents = DateComponents()
        dateComponents.weekday = 1   // 1 = Sunday (UNCalendarNotificationTrigger)
        dateComponents.hour    = 19
        dateComponents.minute  = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_report", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                AppLogger.shared.log("WeeklyReportService: Notifikace se nepodařilo naplánovat: \(error)", type: .error)
            } else {
                AppLogger.shared.log("WeeklyReportService: Týdenní notifikace naplánována.", type: .success)
            }
        }
    }

    /// Okamžitá notifikace po dokončení tréninku (streak / pochvala)
    static func sendWorkoutCompletionNotification(streakDays: Int, sessionLabel: String) {
        let content = UNMutableNotificationContent()

        if streakDays >= 7 {
            content.title = "🔥 \(streakDays) dní v řadě!"
            content.body  = "Tohle je \(sessionLabel). Tvoje konzistence je na jiné úrovni!"
        } else if streakDays >= 3 {
            content.title = "💪 \(streakDays) tréninky za sebou!"
            content.body  = "\(sessionLabel) dokončeno. Tak se budujou svaly."
        } else {
            content.title = "✅ Trénink hotov!"
            content.body  = "\(sessionLabel) splněno. Jakub je hrdý."
        }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "workout_done_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
