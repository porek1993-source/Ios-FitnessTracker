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
    @State private var showChat = false

    var body: some View {
        if profiles.isEmpty {
            if showChat {
                OnboardingChatView()
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            } else {
                WelcomeView(onStart: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        showChat = true
                    }
                })
                .transition(.opacity)
            }
        } else {
            TrainerDashboardView()
                .transition(.opacity)
        }
    }
}
