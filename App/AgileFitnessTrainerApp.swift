// AgileFitnessTrainerApp.swift
// Agilní Fitness Trenér — @main entry point (refaktorovaný)
//
// ✅ AppEnvironment jako jediný zdroj pravdy pro sdílené závislosti
// ✅ Startup sequence oddelegována do AppEnvironment.performStartup()
// ✅ GlobalErrorModifier aplikován na root view
// ✅ Žádné duplicitní instance služeb

import SwiftUI
import SwiftData

@main
struct AgileFitnessTrainerApp: App {

    /// Sdílený ModelContainer (App Group pro Widget Extension).
    static let container = SharedModelContainer.container

    /// Centrální DI kontejner — jeden pro celou aplikaci.
    /// @StateObject zajišťuje životní cyklus svázaný s App, ne s View.
    @StateObject private var appEnv = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(Self.container)
                // Předání závislostí do SwiftUI stromu
                .environmentObject(appEnv)
                .environmentObject(appEnv.healthKitService)
                // Globální error toast nad celou aplikací
                .modifier(GlobalErrorModifier(error: $appEnv.globalError))
                // Startup sequence — spustí se jednou, ne při každém renderu
                .task {
                    await appEnv.performStartup(
                        modelContext: Self.container.mainContext
                    )
                }
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: RootView — navigační root s onboarding/main větvením
// MARK: ═══════════════════════════════════════════════════════════════════════

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @State private var showChat = false

    var body: some View {
        ZStack {
            if profiles.isEmpty {
                if showChat {
                    OnboardingChatView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .opacity
                        ))
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

            // Debug overlay (triple-tap v levém horním rohu)
            DebugOverlayView()
        }
        .animation(.easeInOut(duration: 0.3), value: profiles.isEmpty)
        .animation(.easeInOut(duration: 0.3), value: showChat)
    }
}
