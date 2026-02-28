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

    // ✅ FIX #17: scenePhase sledujeme pro clearBadge() při přechodu do popředí
    @Environment(\.scenePhase) private var scenePhase

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
        // ✅ FIX #17: Vynuluj badge při každém přechodu aplikace do popředí.
        // Bez toho zůstával badge na ikoně navždy po doručení notifikace.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                NotificationService.shared.clearBadge()
            }
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: RootView — navigační root s onboarding / main větvením
// MARK: ═══════════════════════════════════════════════════════════════════════

struct RootView: View {

    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
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
            WelcomeView(
                onStart: {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.80)) {
                        showChat = true
                    }
                },
                onSkip: {
                    injectMockProfile()
                }
            )
            .transition(.opacity)
        }
    }
    
    // MARK: - Mock Bypassing (Testování)
    private func injectMockProfile() {
        let calendar = Calendar(identifier: .gregorian)
        var dateComponents = DateComponents()
        // 32 let starý uživatel (cca 1994)
        dateComponents.year = calendar.component(.year, from: .now) - 32
        let birthDate = calendar.date(from: dateComponents) ?? .now

        let mockProfile = UserProfile(
            name: "Tester",
            dateOfBirth: birthDate,
            gender: .male,
            heightCm: 177.0,
            weightKg: 70.0,
            primaryGoal: .hypertrophy,
            fitnessLevel: .advanced,
            availableDaysPerWeek: 4,
            preferredSplitType: .upperLower, // or PPL/FullBody
            sessionDurationMinutes: 60
        )
        
        // Okamžitě vložíme do SwiftData. Aplikace díky @Query[UserProfile] automaticky pochopí,
        // že profiles.isEmpty == false a zobrazí MainTabView s vynecháním AI onboarding.
        modelContext.insert(mockProfile)
        
        // KRITICKÉ: Musíme vygenerovat plán, jinak bude aplikace prázdná
        WorkoutPlanGenerator.generate(for: mockProfile, in: modelContext)
        
        try? modelContext.save()
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
