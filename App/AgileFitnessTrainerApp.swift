// AgileFitnessTrainerApp.swift
// Agilní Fitness Trenér — @main entry point

import SwiftUI
import SwiftData
import UserNotifications

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
                .onAppear {
                    HealthBackgroundManager.shared.registerBackgroundTasks()
                    HealthBackgroundManager.shared.scheduleNextSync()
                    WeeklyReportService.scheduleWeeklyNotificationIfNeeded()
                    // Seeduj databázi cviků z JSON (pouze při prvním spuštění)
                    let context = Self.container.mainContext
                    ExerciseDatabaseLoader.seedIfNeeded(context: context)
                    // Požádej o oprávnění pro notifikace
                    Task {
                        _ = await NotificationService.shared.requestPermission()
                        NotificationService.shared.scheduleWorkoutReminder(hour: 8, minute: 30)
                    }
                    // HealthKit: autorizace + okamžitý sync dat
                    Task {
                        try? await healthKitService.requestAuthorization()
                        await HealthBackgroundManager.shared.performForegroundSync(healthKit: healthKitService)
                    }
                }
        }
    }
}

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @State private var showChat = false

    var body: some View {
        ZStack {
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
                MainTabView()
                    .transition(.opacity)
            }
            
            // Floating Debug Console (Triple tap top-left corner to toggle)
            DebugOverlayView()
        }
    }
}
