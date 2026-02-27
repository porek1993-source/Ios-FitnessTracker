// SharedModelContainer.swift
// Sdílený ModelContainer pro hlavní aplikaci i Widget Extension.
// Oba cíle musí sdílet stejnou App Group, aby měly přístup ke stejným datům.

@preconcurrency import SwiftData
import Foundation
import SwiftUI  // Pro AppLogger (je v Core/Utilities)

enum SharedModelContainer {

    /// Identifikátor App Group sdílené mezi hlavní aplikací a Widget Extension.
    /// Musí odpovídat nastavení v Xcode → Signing & Capabilities → App Groups.
    static let appGroupID = "group.com.agilefitness.shared"

    /// Společné schéma pro všechny SwiftData modely.
    nonisolated(unsafe) static let schema = Schema([
        UserProfile.self,
        WorkoutPlan.self,
        PlannedWorkoutDay.self,
        PlannedExercise.self,
        Exercise.self,
        WeightEntry.self,
        WorkoutSession.self,
        SessionExercise.self,
        CompletedSet.self,
        HealthMetricsSnapshot.self,
        MuscleXPRecord.self
    ])

    /// Sdílený `ModelContainer` — uložiště dat v App Group kontejneru.
    /// Hlavní app i widget volají tuto property. ModelContainer je thread-safe (Sendable),
    /// ale Swift 6 vyžaduje explicitní označení pro globální statické proměnné.
    nonisolated(unsafe) static let container: ModelContainer = {
        let storeURL: URL
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            storeURL = groupURL.appending(path: "AgileFitness.store")
        } else {
            // Fallback pro simulátor/testy, kde App Group není dostupná
            storeURL = URL.documentsDirectory.appending(path: "AgileFitness.store")
        }

        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Pokud se DB nepodaří otevřít (corruption), pokus se ji smazat a znovu vytvořit
            AppLogger.error("SharedModelContainer: Nepodařilo se otevřít DB: \(error). Pokus o reset...")
            try? FileManager.default.removeItem(at: storeURL)
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                // Absolutní fallback - in-memory DB (ztráta dat, ale app nespadne)
                AppLogger.error("SharedModelContainer: Reset selhal: \(error). Používám in-memory DB.")
                let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try! ModelContainer(for: schema, configurations: fallbackConfig)
            }
        }
    }()
}
