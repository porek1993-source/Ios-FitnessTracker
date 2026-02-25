// SharedModelContainer.swift
// Sdílený ModelContainer pro hlavní aplikaci i Widget Extension.
// Oba cíle musí sdílet stejnou App Group, aby měly přístup ke stejným datům.

import SwiftData
import Foundation

enum SharedModelContainer {

    /// Identifikátor App Group sdílené mezi hlavní aplikací a Widget Extension.
    /// Musí odpovídat nastavení v Xcode → Signing & Capabilities → App Groups.
    static let appGroupID = "group.com.agilefitness.shared"

    /// Společné schéma pro všechny SwiftData modely.
    static let schema = Schema([
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
    /// Hlavní app i widget volají tuto property, takže obě čtou ze stejné SQLite DB.
    static let container: ModelContainer = {
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

        return try! ModelContainer(
            for: schema,
            configurations: config
        )
    }()
}
