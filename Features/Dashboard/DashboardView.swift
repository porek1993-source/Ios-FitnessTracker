// DashboardView.swift
// Agilní Fitness Trenér — Hlavní obrazovka

import SwiftUI
import SwiftData

// MARK: - Dashboard ViewModel

@MainActor
final class DashboardViewModel: ObservableObject {

    // Readiness
    @Published var readinessScore: Double    = 0
    @Published var readinessLevel: String   = "green"
    @Published var readinessMessage: String = ""
    @Published var sleepHours: Double?
    @Published var hrv: Double?
    @Published var restingHR: Double?

    // Today's plan
    @Published var todayPlanLabel: String         = ""
    @Published var todayPlanSplit: String         = ""
    @Published var estimatedMinutes: Int          = 60
    @Published var exerciseCount: Int             = 0
    @Published var hasPlanToday: Bool             = false
    @Published var todayPlannedExercises: [PlannedExercise] = []
    
    // History
    @Published var sessionDates: [Date] = []

    // State
    @Published var isLoadingReadiness: Bool   = true
    @Published var greeting: String           = ""

    // Streak
    @Published var weeklyStreak: Int          = 0
    @Published var completedThisWeek: Int     = 0
    @Published var plannedThisWeek: Int       = 0
    @Published var weekDaysState: [DailyWorkoutState] = Array(repeating: .empty, count: 7)

    private var healthKit: HealthKitService?

    init() {
        self.greeting  = makeGreeting()
    }

    /// Injektuj sdílený HealthKitService (EnvironmentObject nelze předat v init @StateObject)
    func inject(healthKit: HealthKitService) {
        self.healthKit = healthKit
    }

    func load(profile: UserProfile) async {
        greeting  = makeGreeting()
        await loadReadiness(profile: profile)
        loadPlan(profile: profile)
        loadWeekStats(profile: profile)
    }

    // MARK: - Readiness

    private func loadReadiness(profile: UserProfile) async {
        isLoadingReadiness = true
        defer { isLoadingReadiness = false }

        guard let healthKit = healthKit,
              let summary = try? await healthKit.fetchDailySummary(for: .now) else {
            // Fallback — no HealthKit data
            readinessScore   = 65
            readinessLevel   = "orange"
            readinessMessage = "Připoj Apple Health pro přesnější analýzu."
            return
        }

        sleepHours = summary.sleepDurationHours
        hrv        = summary.hrv
        restingHR  = summary.restingHeartRate

        // ✅ FIX: Dashboard dříve počítal readiness s nulovými baseliny.
        // Nyní předáváme profil, aby ReadinessCalculator mohl použít historické průměry (HRV/RHR).
        let tempSnapshot = buildTempSnapshot(from: summary, profile: profile)
        let score: Double
        if let result = ReadinessCalculator.compute(snapshot: tempSnapshot) {
            score = result.score
        } else {
            score = 65
        }

        withAnimation(.spring(response: 0.8)) {
            readinessScore = score
        }

        switch score {
        case 80...:
            readinessLevel   = "green"
            readinessMessage = buildGreenMessage(summary: summary)
        case 55..<80:
            readinessLevel   = "orange"
            readinessMessage = buildOrangeMessage(summary: summary)
        default:
            readinessLevel   = "red"
            readinessMessage = buildRedMessage(summary: summary)
        }
    }

    /// Vytvoří dočasný snapshot z HKDailySummary pro použití s ReadinessCalculator.
    /// Snapshot není uložen do DB — slouží pouze pro výpočet skóre v reálném čase.
    private func buildTempSnapshot(from summary: HKDailySummary, profile: UserProfile) -> HealthMetricsSnapshot {
        let snap = HealthMetricsSnapshot(date: .now)
        snap.sleepDurationHours   = summary.sleepDurationHours
        snap.sleepEfficiencyPct   = summary.sleepEfficiencyPct
        snap.heartRateVariabilityMs = summary.hrv
        snap.restingHeartRate     = summary.restingHeartRate
        
        // Načteme baseliny z profilu (stejně jako v HealthBackgroundManager)
        let history = profile.healthMetricsHistory.sorted(by: { $0.date > $1.date })
        if let lastValid = history.first(where: { $0.hrvBaselineAvg != nil }) {
            snap.hrvBaselineAvg = lastValid.hrvBaselineAvg
            snap.restingHRBaseline = lastValid.restingHRBaseline
        }
        
        return snap
    }

    private func buildGreenMessage(summary: HKDailySummary) -> String {
        if let sleep = summary.sleepDurationHours, sleep >= 8 {
            return "Výborný spánek \(String(format: "%.0f", sleep))h. Dnes můžeš lámat rekordy!"
        }
        if let hrv = summary.hrv, hrv > 70 {
            return "HRV \(Int(hrv)) ms — tělo je plně zotavené. Trénuj naplno."
        }
        return "Všechny ukazatele jsou zelené. Skvělý den na výkon!"
    }

    private func buildOrangeMessage(summary: HKDailySummary) -> String {
        if let sleep = summary.sleepDurationHours, sleep < 7 {
            return "Spánek \(String(format: "%.1f", sleep))h byl kratší. Snížím objem o 20 %."
        }
        if let rhr = summary.restingHeartRate, rhr > 70 {
            return "Tep v klidu \(Int(rhr)) bpm — tělo se ještě zotavuje. Trénuj chytře."
        }
        return "Střední připravenost. Trénink upravím, abys to zvládl bez přepálení."
    }

    private func buildRedMessage(summary: HKDailySummary) -> String {
        if let sleep = summary.sleepDurationHours, sleep < 5 {
            return "Jen \(String(format: "%.0f", sleep))h spánku. Dnes doporučuji aktivní regeneraci."
        }
        return "Tělo potřebuje odpočinek. Navrhnu lehkou mobilitu nebo chůzi."
    }

    // MARK: - Plan

    private func loadPlan(profile: UserProfile) {
        guard let activePlan = profile.workoutPlans.first(where: { $0.isActive }) else {
            hasPlanToday = false; return
        }

        // Date.weekday extension vrací naši konvenci: 1=Pondělí … 7=Neděle
        let dayIndex = Date.now.weekday

        if let day = activePlan.scheduledDays.first(where: { $0.dayOfWeek == dayIndex && !$0.isRestDay }) {
            hasPlanToday              = true
            todayPlanLabel            = day.label
            exerciseCount             = day.plannedExercises.count
            estimatedMinutes          = profile.sessionDurationMinutes
            todayPlanSplit            = activePlan.splitType.displayName
            todayPlannedExercises     = day.plannedExercises.sorted { $0.order < $1.order }
        } else {
            hasPlanToday  = false
            todayPlanLabel = "Den odpočinku"
            todayPlannedExercises = []
        }
    }

    private func loadWeekStats(profile: UserProfile) {
        guard let plan = profile.workoutPlans.first(where: { $0.isActive }) else { return }

        // ✅ FIX: Calendar.mondayStart zajišťuje pondělní začátek týdne nezávisle na locale.
        // Calendar.mondayStart na všech zařízeních má firstWeekday=2 (pondělí).
        // což způsobovalo špatné zařazení session do týdnů a posunuté indexy stavů dnů.
        let startOfWeek = Calendar.mondayStart.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        // date.weekday = 1=Po..7=Ne → 0-based index do states[]: 0=Po..6=Ne
        let normalizedToday = Date.now.weekday - 1
        
        self.sessionDates = plan.sessions.filter { $0.status == .completed }.map { $0.startedAt }

        var states: [DailyWorkoutState] = Array(repeating: .empty, count: 7)

        // 1. Plánované dny
        for i in 0..<7 {
            // date.weekday extension: 1=Pondělí … 7=Neděle; states[i] = i+1 den
            let dayToFind = i + 1
            let isPlanned = plan.scheduledDays.contains(where: { $0.dayOfWeek == dayToFind && !$0.isRestDay })
            if isPlanned {
                states[i] = (i < normalizedToday) ? .missed : (i == normalizedToday ? .todayPlanned : .planned)
            } else {
                states[i] = (i == normalizedToday) ? .todayEmpty : .empty
            }
        }

        // 2. Hotové dny tento týden
        let completedThisWeekSessions = plan.sessions.filter {
            $0.startedAt >= startOfWeek && $0.status == .completed
        }
        
        for session in completedThisWeekSessions {
            // date.weekday = 1=Po..7=Ne → 0-based index do states[]
            let normCompDay = session.startedAt.weekday - 1
            if normCompDay >= 0 && normCompDay < 7 {
                states[normCompDay] = .completed
            }
        }

        self.weekDaysState = states
        plannedThisWeek   = profile.availableDaysPerWeek
        completedThisWeek = completedThisWeekSessions.count

        // Výpočet streaku pomocí dedikovaného StreakManageru
        let allCompleted = plan.sessions
            .filter { $0.status == .completed && $0.finishedAt != nil }
        
        weeklyStreak = StreakManager.calculateWeeklyStreak(completedSessions: allCompleted)
    }

    private func makeGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "Dobré ráno"
        case 12..<17: return "Dobré odpoledne"
        case 17..<22: return "Dobrý večer"
        default:      return "Ahoj"
        }
    }
}

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
    
    // Pro spuštění custom tréninku
    @State private var customSessionToStart: WorkoutSession? = nil // Proměnná pro zobrazení Custom Workout Builderu
    @State private var appearedOnce = false

    var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                DashboardBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── Top safe area spacer ──────────────────────
                        Color.clear.frame(height: 60)

                        // ── Greeting ─────────────────────────────────
                        if let p = profile {
                            greetingHeader(profile: p)
                                .padding(.horizontal, 22)
                                .padding(.bottom, 24)
                        }

                        // ── Readiness Card ────────────────────────────
                        ReadinessCardView(vm: vm)
                            .padding(.horizontal, 18)

                        // ── Weekly Progress ───────────────────────────
                        WeeklyCalendarView(
                            completedCount: vm.completedThisWeek,
                            plannedCount:   vm.plannedThisWeek,
                            weekDaysState:  vm.weekDaysState
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 16)

                        // ── Monthly Heatmap Calendar ─────────────────────
                        WorkoutCalendarView(workoutDates: vm.sessionDates, accentColor: .blue)
                            .padding(.horizontal, 18)
                            .padding(.top, 16)

                        // ── Body Map Preview ──────────────────────────
                        BodyMapPreviewCard(
                            heatmapVM: heatmapVM,
                            onTap:     { showHeatmap = true }
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        
                        // ── Analytika svalového objemu (7 Dní) ────────
                        MuscleVolumeChart()
                            .padding(.horizontal, 18)
                            .padding(.top, 16)
                            
                        // ── Sociální Feed (Aktivita přátel) ───────────
                        SocialFeedView()
                            .padding(.horizontal, 0) // Samo má padding
                            .padding(.top, 16)

                        // ── Today's Plan ──────────────────────────────
                        TodayPlanCard(
                            vm:          vm,
                            onStart:     { showWorkout = true }
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 120) // Extra padding so content doesn't hide behind sticky CTA
                    }
                }
            }
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
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
                                RoundedRectangle(cornerRadius: 18)
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
                            .frame(height: 56)
                        }
                        .buttonStyle(.plain)

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
                            .frame(height: 36)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(
                        LinearGradient(
                            colors: [AppColors.background, AppColors.background.opacity(0.95)],
                            startPoint: .bottom, endPoint: .top
                        )
                        .ignoresSafeArea()
                    )
                } else {
                    VStack(spacing: 10) {
                        // Rychlý trénink — podle partie nebo zdravotního problému
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showQuickPicker = true
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.orange)
                                Text("Rychlý trénink")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [.orange.opacity(0.2), .red.opacity(0.15)], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.35), lineWidth: 1))
                        }
                        .padding(.horizontal, 22)

                        // Sestavit ručně — výběr cviků z databáze
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showBuilder = true
                        }) {
                            Text("Sestavit ručně")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 4)
                        
                    }
                    .padding(.bottom, 24)
                    .background(
                        LinearGradient(
                            colors: [.clear, AppColors.background.opacity(0.9), AppColors.background.opacity(0.95)],
                            startPoint: .bottom, endPoint: .top
                        )
                        .ignoresSafeArea()
                    )
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
            
            // Spusť HealthKit autorizaci + foreground sync
            Task {
                try? await healthKit.requestAuthorization()
                await HealthBackgroundManager.shared.performForegroundSync(healthKit: healthKit)
            }
            
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
            Circle()
                .fill(AppColors.accentGradient)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                )
        }
    }
}

// MARK: - Dashboard Background

private struct DashboardBackground: View {
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            // Top atmospheric glow
            RadialGradient(
                colors: [AppColors.primaryAccent.opacity(0.20), .clear],
                center: .init(x: 0.75, y: 0.0),
                startRadius: 0, endRadius: 380
            )
            .ignoresSafeArea()
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
        .frame(maxWidth: .infinity)
        .frame(height: 156)
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
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(AppColors.border, lineWidth: 1))
        )
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
                            .frame(maxWidth: .infinity).frame(height: 52)
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
        
        try? modelContext.save()
        self.plannedDay = found
        self.session = newSession
        withAnimation(.easeInOut(duration: 0.3)) { isReady = true }
    }
}
