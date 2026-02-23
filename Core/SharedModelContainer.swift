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
        HealthMetricsSnapshot.self
    ])

    /// Sdílený `ModelContainer` — uložiště dat v App Group kontejneru.
    /// Hlavní app i widget volají tuto property, takže obě čtou ze stejné SQLite DB.
    static let container: ModelContainer = {
        guard let storeURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "AgileFitness.store")
        else {
            fatalError("App Group \(appGroupID) není nakonfigurována. Přidej ji do Signing & Capabilities.")
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
