// AgileFitnessTrainerApp.swift
// Agilní Fitness Trenér — @main entry point (v2.1)
//
// OPRAVY v2.1:
//  ✅ AppEnvironment jako jediný zdroj pravdy pro sdílené závislosti
//  ✅ isStartupComplete flag → skeleon loading místo okamžitého render
//  ✅ GlobalErrorModifier aplikován na root view
//  ✅ Žádné duplicitní instance služeb
//  ✅ RootView oddělena pro čistší lifecycle správu
//  ✅ DebugOverlayView podmíněna #if DEBUG

import SwiftUI
import SwiftData

@main
struct AgileFitnessTrainerApp: App {

    /// Sdílený ModelContainer (App Group pro Widget Extension)
    static let container = SharedModelContainer.container

    /// Centrální DI kontejner — životní cyklus svázaný s App, ne s View
    @StateObject private var appEnv = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(Self.container)
                // Předání závislostí do celého SwiftUI stromu
                .environmentObject(appEnv)
                .environmentObject(appEnv.healthKitService)
                // Globální error toast nad celou aplikací
                .modifier(GlobalErrorModifier(error: $appEnv.globalError))
                // Startup sequence — jednou, ne při každém renderu View
                .task {
                    await appEnv.performStartup(
                        modelContext: Self.container.mainContext
                    )
                }
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: RootView — navigační root s onboarding / main větvením
// MARK: ═══════════════════════════════════════════════════════════════════════

struct RootView: View {

    @Query private var profiles: [UserProfile]
    @EnvironmentObject private var appEnv: AppEnvironment

    @State private var showChat = false

    var body: some View {
        ZStack {

            // ── Startup loading (skeleton) ────────────────────────────────────
            if !appEnv.isStartupComplete {
                AppStartupView()
                    .transition(.opacity)

            // ── Onboarding ────────────────────────────────────────────────────
            } else if profiles.isEmpty {
                onboardingFlow
                    .transition(.opacity)

            // ── Hlavní aplikace ───────────────────────────────────────────────
            } else {
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal:   .opacity
                    ))
            }

            // Debug overlay (triple-tap v levém horním rohu — jen v DEBUG buildech)
            #if DEBUG
            DebugOverlayView()
            #endif
        }
        .animation(.easeInOut(duration: 0.30), value: appEnv.isStartupComplete)
        .animation(.easeInOut(duration: 0.30), value: profiles.isEmpty)
        .animation(.easeInOut(duration: 0.28), value: showChat)
        .preferredColorScheme(.dark)
    }

    // MARK: Onboarding větev

    @ViewBuilder
    private var onboardingFlow: some View {
        if showChat {
            OnboardingChatView()
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal:   .opacity
                ))
        } else {
            WelcomeView(onStart: {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.80)) {
                    showChat = true
                }
            })
            .transition(.opacity)
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: AppStartupView — loading screen při startu
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct AppStartupView: View {

    @State private var pulse = false

    var body: some View {
        ZStack {
            Color(hue: 0.62, saturation: 0.22, brightness: 0.07).ignoresSafeArea()

            VStack(spacing: 20) {
                // Logo / ikona
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 80, height: 80)
                        .blur(radius: pulse ? 18 : 10)
                        .scaleEffect(pulse ? 1.25 : 0.90)

                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color.blue.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                Text("Agilní Trenér")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                Text("Připravuji tvůj plán…")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
