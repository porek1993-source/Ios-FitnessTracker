// AgileFitnessTrainerApp.swift
// Agilní Fitness Trenér — @main entry point

import SwiftUI
import SwiftData

@main
struct AgileFitnessTrainerApp: App {

    /// Sdílený ModelContainer pro hlavní app i Widget Extension (App Groups).
    /// Definice viz `SharedModelContainer.swift`.
    static let container = SharedModelContainer.container

    @StateObject private var healthKitService = HealthKitService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(Self.container)
                .environmentObject(healthKitService)
        }
    }
}

struct RootView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if profiles.isEmpty {
            OnboardingView()
        } else {
            TrainerDashboardView()
        }
    }
}
