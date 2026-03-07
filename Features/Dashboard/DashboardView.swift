// DashboardView.swift
// Agilní Fitness Trenér — Hlavní obrazovka

import SwiftUI
import SwiftData

// MARK: - TrainerDashboardView

struct TrainerDashboardView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService

    @StateObject private var vm = DashboardViewModel()
    @StateObject private var heatmapVM = HeatmapViewModel()

    @State private var showHeatmap  = false
    @State private var showWorkout  = false
    @State private var showPreview  = false
    @State private var showBuilder  = false
    @State private var showQuickPicker = false
    
    // Hero animace — matched geometry namespace
    @Namespace private var heroNS

    // Pro spuštění custom tréninku
    @State private var customSessionToStart: WorkoutSession? = nil
    @State private var appearedOnce = false
    
    // UI state pro skrývání navigace
    @State private var tabBarVisible = true
    @State private var lastOffset: CGFloat = 0

    var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                // ✅ 2026 Design: Organicky animované MeshGradient pozadí
                MeshGradientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── Top safe area spacer ──────────────────────
                        Color.clear.frame(height: 60)

                        // ✅ iOS 18+: Auto-hide TabBar při scrollování dolů
                        if #available(iOS 18.0, *) {
                            Color.clear.frame(height: 0)
                                .onScrollGeometryChange(for: CGFloat.self) { geo in
                                    geo.contentOffset.y
                                } action: { oldValue, newValue in
                                    if newValue < 50 {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            tabBarVisible = true
                                        }
                                    } else if newValue > oldValue + 10, tabBarVisible {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            tabBarVisible = false
                                        }
                                    } else if newValue < oldValue - 10, !tabBarVisible {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            tabBarVisible = true
                                        }
                                    }
                                    lastOffset = newValue
                                }
                        }

                        // ── Greeting ─────────────────────────────────
                        if let p = profile {
                            greetingHeader(profile: p)
                                .padding(.horizontal, 22)
                                .padding(.bottom, 24)
                        }

                        // ── Readiness Card ─────────────────────────────
                        // ✅ Skeleton Screen: .redacted() na finální tvar místo šedých bloků
                        ReadinessCardView(vm: vm)
                            .redacted(reason: vm.isLoadingReadiness ? .placeholder : [])
                            .padding(.horizontal, 18)

                        // ── Weekly Progress (7 dní — relevantní pro "dnes") ────
                        WeeklyCalendarView(
                            completedCount: vm.completedThisWeek,
                            plannedCount:   vm.plannedThisWeek,
                            weekDaysState:  vm.weekDaysState
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 16)

                        // ── Body Map Preview ──────────────────────────
                        BodyMapPreviewCard(
                            heatmapVM: heatmapVM,
                            onTap:     { showHeatmap = true }
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 16)

                        // ── Today's Plan ──────────────────────────────
                        // ✅ Hero Animace: matchedGeometryEffect umožní plynulý fade
                        //    na budoucí WorkoutView přechod (namespace sdílen s launch tlačítkem)
                        TodayPlanCard(
                            vm:          vm,
                            onStart:     { showWorkout = true }
                        )
                        .matchedGeometryEffect(id: "workout-hero-card", in: heroNS, isSource: true)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)

                        // ── Sprint Goals ───────────────────────────────
                        if let activePlan = profile?.workoutPlans.first(where: \.isActive) {
                            SprintGoalsCard(sprintNumber: activePlan.sprintNumber)
                                .padding(.horizontal, 18)
                                .padding(.top, 16)
                                .padding(.bottom, 140)
                        } else {
                            Color.clear.frame(height: 140)
                        }
                    }
                }

                // ✅ Oblast 6: Streak Particle Emitter — padají plamínky při aktivním streaku
                StreakParticleView(streakCount: vm.weeklyStreak)
                    .allowsHitTesting(false)

            }
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
            .modifier(ToolbarVisibilityModifier(isVisible: tabBarVisible))
            // ── Sticky CTA buttons ─────────────────────────────────
            .safeAreaInset(edge: .bottom) {
                if vm.hasPlanToday {
                    VStack(spacing: 10) {
                        // Hlavní CTA — Začít trénink
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showWorkout = true
                        }) {
                            ZStack {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                AppColors.primaryAccent,
                                                AppColors.secondaryAccent
                                            ],
                                            startPoint: .topLeading,
                                            endPoint:   .bottomTrailing
                                        )
                                    )
                                    .shadow(color: AppColors.primaryAccent.opacity(0.45), radius: 18, y: 6)

                                HStack(spacing: 10) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Začít trénink")
                                        .font(.system(size: 17, weight: .bold))
                                }
                                .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Začít dnešní trénink")
                        .accessibilityHint("Klepnutím spustíte dnešní trénink z aktuálního plánu")

                        // Sekundární — Náhled plánu
                        Button(action: {
                            showPreview = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Zobrazit náhled plánu")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Zobrazit náhled plánu")
                        .accessibilityHint("Zobrazí seznam cviků dnešního tréninku pro rychlou kontrolu")
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .top) {
                        Divider().background(Color.white.opacity(0.08))
                    }
                } else {
                    // ✅ Oblast 4 — Explicitní tlačítka pro den odpočinku
                    HStack(spacing: 12) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showQuickPicker = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                Text("Rychlý trénink")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.primaryAccent, AppColors.secondaryAccent],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: AppColors.primaryAccent.opacity(0.35), radius: 10, y: 4)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Spustit rychlý trénink")

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showBuilder = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.pencil")
                                Text("Vlastní plán")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.14))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Sestavit vlastní plán")
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                    .padding(.top, 10)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .top) {
                        Divider().background(Color.white.opacity(0.08))
                    }
                }
            }
            .sheet(isPresented: $showHeatmap) {
                HeatmapView()
            }
            .sheet(isPresented: $showPreview) {
                WorkoutPreviewView(vm: vm)
            }
            .fullScreenCover(isPresented: $showWorkout) {
                TodayWorkoutLaunchWrapper(
                    profile: profile,
                    customSession: customSessionToStart,
                    onDismiss: { 
                        showWorkout = false 
                        customSessionToStart = nil
                    }
                )
            }
            .sheet(isPresented: $showBuilder) {
                CustomWorkoutBuilderView()
            }
            .sheet(isPresented: $showQuickPicker) {
                QuickWorkoutPickerView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .task {
            guard !appearedOnce, let p = profile else { return }
            appearedOnce = true

            // Injektuj sdílený HealthKitService do VM
            vm.inject(healthKit: healthKit)

            // ✅ VÝKON: Spusť HealthKit auth + vm.load
            // HealthKit requestAuthorization() může trvat sekundy (čeká na user dialog)
            try? await healthKit.requestAuthorization()
            await HealthBackgroundManager.shared.performForegroundSync(healthKit: healthKit)
            
            // ✅ FIX: Voláme sekvenčně, aby nedocházelo k Capture non-sendable UserProfile v child tasku
            await vm.load(profile: p)

            // Offline Sync
            _ = NetworkMonitor.shared // Inicializace monitoru
            await OfflineSyncManager.shared.syncUnsyncedWorkouts(context: modelContext)
        }
        .onChange(of: profiles.count) {
            Task {
                if let p = profiles.first { await vm.load(profile: p) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartCustomWorkout"))) { note in
            if let session = note.object as? WorkoutSession {
                customSessionToStart = session
                showWorkout = true
            }
        }
    }

    // MARK: - Greeting Header

    private func greetingHeader(profile: UserProfile) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.greeting + ",")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                Text(profile.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                // 🔥 Systém Streaků
                if vm.weeklyStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").foregroundStyle(.red)
                        Text("\(vm.weeklyStreak) \(vm.weeklyStreak == 1 ? "týden" : (vm.weeklyStreak < 5 ? "týdny" : "týdnů")) v kuse!")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(.top, 2)
                }
            }

            Spacer()

            // Quick settings avatar
            NavigationLink(destination: SettingsView()) {
                Circle()
                    .fill(AppColors.accentGradient)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(profile.name.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}


// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: - ReadinessCardView
// MARK: ─────────────────────────────────────────────────────────────────────

struct ReadinessCardView: View {
    @ObservedObject var vm: DashboardViewModel

    private var levelColor: Color {
        switch vm.readinessLevel {
        case "green":  return AppColors.success
        case "orange": return AppColors.warning
        default:       return AppColors.error
        }
    }

    private var levelLabel: String {
        switch vm.readinessLevel {
        case "green":  return "Připraven na výkon"
        case "orange": return "Střední připravenost"
        default:       return "Regenerace"
        }
    }

    var body: some View {
        ZStack {
            // Card background with gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            levelColor.opacity(0.18),
                            AppColors.secondaryBg
                        ],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(levelColor.opacity(0.25), lineWidth: 1)
                )

            if vm.isLoadingReadiness {
                loadingShimmer
            } else {
                cardContent
            }
        }
        .frame(height: 156)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Připravenost: \(Int(vm.readinessScore)) procent. \(levelLabel). \(vm.readinessMessage)")
    }

    // MARK: Loading

    private var loadingShimmer: some View {
        HStack(spacing: 20) {
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 10) {
                ForEach([CGFloat(0.6), 0.8, 0.5], id: \.self) { w in
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.07))
                            .frame(width: geo.size.width * w, height: 12)
                    }
                    .frame(height: 12)
                }
            }
        }
        .padding(24)
        .redacted(reason: .placeholder)
    }

    // MARK: Content

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 20) {
            // Readiness ring
            ReadinessRingLarge(
                score:  vm.readinessScore,
                color:  levelColor
            )
            .frame(width: 92, height: 92)

            // Text info
            VStack(alignment: .leading, spacing: 6) {
                // Level badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(levelColor)
                        .frame(width: 7, height: 7)
                    Text(levelLabel.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(levelColor)
                        .kerning(0.8)
                }

                Text(vm.readinessMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Metric pills
                HStack(spacing: 8) {
                    if let sleep = vm.sleepHours {
                        MiniMetricPill(icon: "moon.fill",
                                       value: String(format: "%.0fh", sleep),
                                       color: .blue)
                    }
                    if let hrv = vm.hrv {
                        MiniMetricPill(icon: "waveform.path.ecg",
                                       value: "\(Int(hrv)) ms",
                                       color: .green)
                    }
                    if let rhr = vm.restingHR {
                        MiniMetricPill(icon: "heart.fill",
                                       value: "\(Int(rhr)) bpm",
                                       color: .red)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

// MARK: - Readiness Ring (large version for card)

private struct ReadinessRingLarge: View {
    let score: Double
    let color: Color

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(color.opacity(0.12), lineWidth: 7)

            // Progress arc
            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.6), color],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.75), value: score)
                .shadow(color: color.opacity(0.55), radius: 10, x: 0, y: 0)

            // Inner glow
            Circle()
                .fill(color.opacity(0.08))
                .padding(10)

            // Score text
            VStack(spacing: 0) {
                Text("\(Int(score))")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Mini Metric Pill

private struct MiniMetricPill: View {
    let icon:  String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: - Body Map Preview Card (entry point to HeatmapView)
// MARK: ─────────────────────────────────────────────────────────────────────

private struct BodyMapPreviewCard: View {
    @ObservedObject var heatmapVM: HeatmapViewModel
    let onTap: () -> Void

    private var fatigueCount: Int { heatmapVM.affectedAreas.count }
    private var hasFatigue: Bool  { fatigueCount > 0 }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.secondaryBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(AppColors.border, lineWidth: 1)
                    )

                HStack(spacing: 0) {
                    // Mini body canvas
                    MiniBodyCanvas(vm: heatmapVM)
                        .frame(width: 90, height: 120)
                        .padding(.leading, 16)
                        .padding(.vertical, 16)

                    // Text content
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: hasFatigue ? "exclamationmark.triangle.fill" : "figure.stand")
                                .font(.system(size: 14))
                                .foregroundStyle(hasFatigue ? .orange : .blue)

                            Text("Svalová mapa")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        if hasFatigue {
                            Text("\(fatigueCount) \(fatigueCount == 1 ? "omezení" : fatigueCount < 5 ? "omezení" : "omezení")")
                                .font(.system(size: 13))
                                .foregroundStyle(.orange.opacity(0.9))

                            // Affected area tags
                            FlowLayout(spacing: 5) {
                                ForEach(heatmapVM.affectedAreas.prefix(3)) { entry in
                                    Text(entry.area?.displayName ?? "Neznámý sval")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(entry.isJointPain ? .red : .orange)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(entry.isJointPain
                                                      ? Color.red.opacity(0.15)
                                                      : Color.orange.opacity(0.12))
                                        )
                                }
                            }
                        } else {
                            Text("Označ oblast, která tě omezuje")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.45))

                            Text("iKorba přizpůsobí trénink")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 20)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.trailing, 16)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Svalová mapa: \(hasFatigue ? "\(fatigueCount) zaznamenaných omezení" : "Žádné omezení. Označ oblast, která tě omezuje")")
        .accessibilityHint("Otevře interaktivní mapu svalů pro nastavení únavy a bolesti.")
    }
}

// MARK: - Mini Body Canvas (thumbnail of heatmap)

private struct MiniBodyCanvas: View {
    @ObservedObject var vm: HeatmapViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Čistá obrysová silueta
                CleanMiniSilhouette()
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)

                // Barevné zóny únavy
                Canvas { ctx, size in
                    for entry in vm.affectedAreas {
                        guard let area = entry.area, area.isFrontSide else { continue }
                        let r = area.relativeRect(in: size)
                        let color = entry.isJointPain
                            ? Color.red.opacity(0.60)
                            : Color.orange.opacity(0.50)
                        ctx.fill(
                            Path(ellipseIn: r),
                            with: .color(color)
                        )
                    }
                }
            }
        }
    }
}

// Mini silueta s čistými organickými liniemi pro dashboard kartu
private struct CleanMiniSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cx = w * 0.5

        // Hlava
        p.addEllipse(in: CGRect(x: cx - w*0.145, y: h*0.005, width: w*0.290, height: h*0.120))

        // Torso — organický tvar
        var torso = Path()
        torso.move(to: CGPoint(x: w*0.18, y: h*0.160))
        torso.addCurve(to: CGPoint(x: w*0.82, y: h*0.160),
                       control1: CGPoint(x: w*0.295, y: h*0.145), control2: CGPoint(x: w*0.705, y: h*0.145))
        torso.addCurve(to: CGPoint(x: w*0.775, y: h*0.450),
                       control1: CGPoint(x: w*0.858, y: h*0.212), control2: CGPoint(x: w*0.808, y: h*0.375))
        torso.addCurve(to: CGPoint(x: w*0.225, y: h*0.450),
                       control1: CGPoint(x: w*0.702, y: h*0.468), control2: CGPoint(x: w*0.298, y: h*0.468))
        torso.addCurve(to: CGPoint(x: w*0.18, y: h*0.160),
                       control1: CGPoint(x: w*0.192, y: h*0.375), control2: CGPoint(x: w*0.142, y: h*0.212))
        torso.closeSubpath()
        p.addPath(torso)

        // Ramena
        p.addEllipse(in: CGRect(x: w*0.060, y: h*0.172, width: w*0.105, height: h*0.078))
        p.addEllipse(in: CGRect(x: w*0.835, y: h*0.172, width: w*0.105, height: h*0.078))

        // Paže
        addR(&p, cx: w*0.072, cy: h*0.290, hw: w*0.058, hh: h*0.100)
        addR(&p, cx: w*0.928, cy: h*0.290, hw: w*0.058, hh: h*0.100)

        // Předloktí
        addR(&p, cx: w*0.065, cy: h*0.425, hw: w*0.048, hh: h*0.082)
        addR(&p, cx: w*0.935, cy: h*0.425, hw: w*0.048, hh: h*0.082)

        // Pánev
        p.addRoundedRect(
            in: CGRect(x: w*0.218, y: h*0.450, width: w*0.564, height: h*0.065),
            cornerSize: CGSize(width: 14, height: 14), style: .continuous
        )

        // Stehna
        addR(&p, cx: w*0.316, cy: h*0.600, hw: w*0.092, hh: h*0.105)
        addR(&p, cx: w*0.684, cy: h*0.600, hw: w*0.092, hh: h*0.105)

        // Lýtka
        addR(&p, cx: w*0.316, cy: h*0.820, hw: w*0.068, hh: h*0.085)
        addR(&p, cx: w*0.684, cy: h*0.820, hw: w*0.068, hh: h*0.085)

        // Chodidla
        p.addRoundedRect(
            in: CGRect(x: w*0.220, y: h*0.918, width: w*0.195, height: h*0.045),
            cornerSize: CGSize(width: 8, height: 8), style: .continuous
        )
        p.addRoundedRect(
            in: CGRect(x: w*0.585, y: h*0.918, width: w*0.195, height: h*0.045),
            cornerSize: CGSize(width: 8, height: 8), style: .continuous
        )

        return p
    }

    private func addR(_ p: inout Path, cx: CGFloat, cy: CGFloat, hw: CGFloat, hh: CGFloat) {
        let r = min(hw, hh)
        p.addRoundedRect(
            in: CGRect(x: cx - hw, y: cy - hh, width: hw * 2, height: hh * 2),
            cornerSize: CGSize(width: r, height: r), style: .continuous
        )
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: - TodayPlanCard
// MARK: ─────────────────────────────────────────────────────────────────────

private struct TodayPlanCard: View {
    @ObservedObject var vm: DashboardViewModel
    let onStart: () -> Void

    @State private var buttonPressed = false

    var body: some View {
        if vm.hasPlanToday {
            workoutCard
        } else {
            restDayCard
        }
    }

    private var workoutCard: some View {
        ZStack {
            // Layered background
            RoundedRectangle(cornerRadius: 24)
                .fill(AppColors.secondaryBg)

            RoundedRectangle(cornerRadius: 24)
                .stroke(AppColors.border, lineWidth: 1)

            // Accent glow at top-left
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [AppColors.primaryAccent.opacity(0.15), .clear],
                        startPoint: .topLeading,
                        endPoint:   .center
                    )
                )

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DNEŠNÍ TRÉNINK")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white.opacity(0.35))
                            .kerning(1.2)

                        Text(vm.todayPlanLabel)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(vm.todayPlanSplit)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer()

                    // Difficulty indicator
                    ReadinessInfluenceBadge(level: vm.readinessLevel)
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)

                // Stats row
                HStack(spacing: 0) {
                    PlanStatItem(
                        icon: "timer",
                        value: "\(vm.estimatedMinutes)",
                        unit: "min",
                        color: .blue
                    )
                    Divider()
                        .frame(height: 28)
                        .background(Color.white.opacity(0.1))

                    PlanStatItem(
                        icon: "scalemass.fill",
                        value: "\(vm.exerciseCount)",
                        unit: "cviků",
                        color: .purple
                    )
                    Divider()
                        .frame(height: 28)
                        .background(Color.white.opacity(0.1))

                    PlanStatItem(
                        icon: "flame.fill",
                        value: estimatedCalories,
                        unit: "kcal",
                        color: .orange
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 22)

                // CTA odstraněno z karty → přesunuto do sticky overlay v DashboardView
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dnešní trénink: \(vm.todayPlanLabel), zaměřeno na \(vm.todayPlanSplit). Odhadem \(vm.estimatedMinutes) minut a \(vm.exerciseCount) cviků.")
    }

    private var restDayCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 52, height: 52)
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.55, green: 0.40, blue: 0.90))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Den odpočinku")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Text("Záda potřebují čas na růst. Zítra makáme!")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.secondaryBg)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dnes je den odpočinku. Záda potřebují čas na růst. Zítra makáme!")
    }

    private var estimatedCalories: String {
        let kcal = Int(Double(vm.estimatedMinutes) * 5.0)  // ~5 kcal/min pro silový trénink (WHO reference)
        return "\(kcal)"
    }
}

// MARK: - Plan Stat Item

private struct PlanStatItem: View {
    let icon:  String
    let value: String
    let unit:  String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Readiness Influence Badge

private struct ReadinessInfluenceBadge: View {
    let level: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(badgeText)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(dotColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(dotColor.opacity(0.12)))
    }

    private var dotColor: Color {
        switch level {
        case "green":  return AppColors.success
        case "orange": return AppColors.warning
        default:       return AppColors.error
        }
    }

    private var badgeText: String {
        switch level {
        case "green":  return "PLNÝ VÝKON"
        case "orange": return "−20 % OBJEM"
        default:       return "REGENERACE"
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: - FlowLayout (for fatigue tags)
// MARK: ─────────────────────────────────────────────────────────────────────

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 200
        var x: CGFloat = 0, y: CGFloat = 0, maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0; y += maxHeight + spacing; maxHeight = 0
            }
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, maxHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX; y += maxHeight + spacing; maxHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
        }
    }
}

// MARK: - Preview

#Preview {
    TrainerDashboardView()
        .modelContainer(for: [UserProfile.self, WorkoutPlan.self,
                               PlannedWorkoutDay.self, PlannedExercise.self,
                               Exercise.self, WorkoutSession.self,
                               HealthMetricsSnapshot.self], inMemory: true)
        .environmentObject(HealthKitService())
}


// MARK: - TodayWorkoutLaunchWrapper
struct TodayWorkoutLaunchWrapper: View {
    let profile: UserProfile?
    let customSession: WorkoutSession?
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @State private var session: WorkoutSession?
    @State private var plannedDay: PlannedWorkoutDay?
    @State private var isReady = false
    @State private var errorMessage: String?
    @State private var todayWeekDay: WeekDay? = nil

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            if let errorMessage {
                VStack(spacing: 24) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue.opacity(0.7))
                    Text("Dnes máš volno")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                    Text(errorMessage)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button(action: onDismiss) {
                        Text("Zpět")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(minHeight: 52)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.12)))
                            .padding(.horizontal, 40)
                    }
                    .buttonStyle(.plain)
                }
                .preferredColorScheme(.dark)
            } else if isReady, let session, let plannedDay, let profile {
                WorkoutViewWithAI(session: session, plannedDay: plannedDay, profile: profile)
            } else {
                VStack(spacing: 20) {
                    ProgressView().tint(.blue).scaleEffect(1.4)
                    Text("Připravuji trénink…")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .onAppear { prepareWorkout() }
        .preferredColorScheme(.dark)
    }

    private func prepareWorkout() {
        if let customSession {
            self.session = customSession
            self.plannedDay = customSession.plannedDay
            self.isReady = true
            return
        }
        
        guard let profile else { errorMessage = "Profil nenalezen."; return }
        guard let plan = profile.workoutPlans.first(where: { $0.isActive }) else {
            errorMessage = "Nemáš aktivní tréninkový plán."
            return
        }
        // Date.weekday extension vrací naši konvenci: 1=Pondělí … 7=Neděle
        let dayIndex = Date.now.weekday
        guard let found = plan.scheduledDays.first(where: { $0.dayOfWeek == dayIndex && !$0.isRestDay }) else {
            errorMessage = "Dnešek je odpočinkový den. Odpočinek je součástí plánu — tělo roste při zotavení! 💪"
            return
        }
        let newSession = WorkoutSession(plan: plan, plannedDay: found)
        modelContext.insert(newSession)
        
        // ✅ FIX: Populate SessionExercise from PlannedExercise
        for pev in found.plannedExercises.sorted(by: { $0.order < $1.order }) {
            let sessionEx = SessionExercise(
                order: pev.order,
                exercise: pev.exercise,
                session: newSession
            )
            modelContext.insert(sessionEx)
        }
        
        try? modelContext.save()  // Session init — SwiftData automaticky rollbackuje při chybě
        self.plannedDay = found
        self.session = newSession
        withAnimation(.easeInOut(duration: 0.3)) { isReady = true }
    }
}

// MARK: - Compatibility Extensions

struct ToolbarVisibilityModifier: ViewModifier {
    let isVisible: Bool
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.toolbarVisibility(isVisible ? .visible : .hidden, for: .tabBar)
        } else {
            content
        }
    }
}

extension View {
    @ViewBuilder
    func ifIOS18<Content: View>(@ViewBuilder content: @escaping (Self) -> Content) -> some View {
        if #available(iOS 18.0, *) {
            content(self)
        } else {
            self
        }
    }
}
