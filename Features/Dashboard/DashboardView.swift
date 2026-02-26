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
    @Published var todayPlanLabel: String     = ""
    @Published var todayPlanSplit: String     = ""
    @Published var estimatedMinutes: Int      = 60
    @Published var exerciseCount: Int         = 0
    @Published var hasPlanToday: Bool         = false

    // State
    @Published var isLoadingReadiness: Bool   = true
    @Published var greeting: String           = ""

    // Streak
    @Published var weeklyStreak: Int          = 0
    @Published var completedThisWeek: Int     = 0
    @Published var plannedThisWeek: Int       = 0

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
        await loadReadiness()
        loadPlan(profile: profile)
        loadWeekStats(profile: profile)
    }

    // MARK: - Readiness

    private func loadReadiness() async {
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

        let score = calculateReadiness(summary: summary)
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

    private func calculateReadiness(summary: HKDailySummary) -> Double {
        var score = 70.0

        // Sleep contribution (max ±20)
        if let sleep = summary.sleepDurationHours {
            if sleep >= 8   { score += 15 }
            else if sleep >= 7 { score += 8 }
            else if sleep >= 6 { score += 0 }
            else if sleep >= 5 { score -= 15 }
            else               { score -= 25 }
        }

        // HRV contribution (max ±15)
        if let hrv = summary.hrv {
            if hrv > 70      { score += 12 }
            else if hrv > 50 { score += 5 }
            else if hrv > 30 { score -= 5 }
            else             { score -= 12 }
        }

        // Resting HR contribution (max ±10)
        if let rhr = summary.restingHeartRate {
            if rhr < 55      { score += 8 }
            else if rhr < 65 { score += 4 }
            else if rhr > 75 { score -= 6 }
            else if rhr > 85 { score -= 10 }
        }

        return max(10, min(99, score))
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

        let todayWeekday = Calendar.current.component(.weekday, from: .now)
        // Convert: Swift weekday (1=Sun) → our convention (1=Mon)
        let dayIndex = todayWeekday == 1 ? 7 : todayWeekday - 1

        if let day = activePlan.scheduledDays.first(where: { $0.dayOfWeek == dayIndex && !$0.isRestDay }) {
            hasPlanToday        = true
            todayPlanLabel      = day.label
            exerciseCount       = day.plannedExercises.count
            estimatedMinutes    = profile.sessionDurationMinutes
            todayPlanSplit      = activePlan.splitType.displayName
        } else {
            hasPlanToday  = false
            todayPlanLabel = "Den odpočinku"
        }
    }

    private func loadWeekStats(profile: UserProfile) {
        guard let plan = profile.workoutPlans.first(where: { $0.isActive }) else { return }

        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now

        let completedSessions = plan.sessions.filter {
            $0.startedAt >= startOfWeek && $0.status == .completed
        }.count

        plannedThisWeek   = profile.availableDaysPerWeek
        completedThisWeek = completedSessions

        // Výpočet streaku: počet po sobě jdoucích týdnů s alespoň jedním tréninkem.
        // Pokud aktuální týden ještě nemá trénink, přeskočí ho a počítá od minulého.
        let allCompleted = plan.sessions
            .filter { $0.status == .completed && $0.finishedAt != nil }
        
        var streak = 0
        var checkWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        var skippedCurrentWeek = false
        
        for _ in 0..<52 {  // max 52 týdnů zpět
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: checkWeek) ?? checkWeek
            let hasWorkout = allCompleted.contains { $0.startedAt >= checkWeek && $0.startedAt < weekEnd }
            if hasWorkout {
                streak += 1
                checkWeek = calendar.date(byAdding: .day, value: -7, to: checkWeek) ?? checkWeek
            } else if !skippedCurrentWeek && streak == 0 {
                // Aktuální týden ještě nemá trénink — přeskoč ho a zkus minulý
                skippedCurrentWeek = true
                checkWeek = calendar.date(byAdding: .day, value: -7, to: checkWeek) ?? checkWeek
            } else {
                break
            }
        }
        
        weeklyStreak = streak
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
                        WeeklyProgressBar(
                            completed: vm.completedThisWeek,
                            planned:   vm.plannedThisWeek
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
                        TodayPlanCard(
                            vm:          vm,
                            onStart:     { showWorkout = true }
                        )
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 36)
                    }
                }
            }
            .ignoresSafeArea()
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
            .sheet(isPresented: $showHeatmap) {
                HeatmapView()
            }
            .fullScreenCover(isPresented: $showWorkout) {
                TodayWorkoutLaunchWrapper(
                    profile: profile,
                    onDismiss: { showWorkout = false }
                )
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
        }
        .onChange(of: profiles.count) {
            Task {
                if let p = profiles.first { await vm.load(profile: p) }
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
            }

            Spacer()

            // Quick settings avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red:0.25, green:0.55, blue:1.0),
                                 Color(red:0.10, green:0.38, blue:0.88)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
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
            Color(red: 0.055, green: 0.055, blue: 0.08)
                .ignoresSafeArea()

            // Top atmospheric glow
            RadialGradient(
                colors: [Color(red:0.12, green:0.28, blue:0.65).opacity(0.30), .clear],
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
        case "green":  return Color(red: 0.15, green: 0.85, blue: 0.45)
        case "orange": return Color(red: 0.95, green: 0.60, blue: 0.10)
        default:       return Color(red: 0.95, green: 0.25, blue: 0.30)
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
                            Color(red:0.10, green:0.10, blue:0.16)
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
// MARK: - Weekly Progress Bar
// MARK: ─────────────────────────────────────────────────────────────────────

private struct WeeklyProgressBar: View {
    let completed: Int
    let planned:   Int

    private let days = ["Po", "Út", "St", "Čt", "Pá", "So", "Ne"]
    private var todayIndex: Int {
        // weekday: 1=Sun → index 6, 2=Mon → index 0, etc.
        let wd = Calendar.current.component(.weekday, from: .now)
        return wd == 1 ? 6 : wd - 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TENTO TÝDEN")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white.opacity(0.3))
                    .kerning(1.2)

                Spacer()

                Text("\(completed) / \(planned) tréninků")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }

            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    DayDot(
                        label:       days[i],
                        state:       dayState(index: i),
                        isToday:     i == todayIndex
                    )
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func dayState(index: Int) -> DayDotState {
        // Hotové dny jsou jen ty v minulosti (index < todayIndex) kde počítáme dokončené tréninky
        let completedUpToToday = min(completed, todayIndex)
        if index < completedUpToToday   { return .done }
        if index == todayIndex          { return .today }
        if index == todayIndex + 1      { return .upcoming }
        return .future
    }
}

private enum DayDotState { case done, today, upcoming, future }

private struct DayDot: View {
    let label:  String
    let state:  DayDotState
    let isToday:Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: 32, height: 32)

                if isToday {
                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                }

                if state == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                } else if state == .today {
                    Circle()
                        .fill(.white)
                        .frame(width: 7, height: 7)
                }
            }

            Text(label)
                .font(.system(size: 9, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? .white : .white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }

    private var fillColor: Color {
        switch state {
        case .done:     return Color(red: 0.15, green: 0.80, blue: 0.45)
        case .today:    return Color(red: 0.25, green: 0.55, blue: 1.0)
        case .upcoming: return Color.white.opacity(0.10)
        case .future:   return Color.white.opacity(0.05)
        }
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
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
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
                                    Text(entry.area.displayName)
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

                            Text("Jakub přizpůsobí trénink")
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
        Canvas { ctx, size in
            let w = size.width, h = size.height

            // Silhouette
            drawSilhouette(ctx: ctx, w: w, h: h)

            // Fatigue zones
            for entry in vm.affectedAreas {
                let area = entry.area
                guard area.isFrontSide else { continue }
                let r = area.relativeRect(in: size)
                let color = entry.isJointPain
                    ? Color.red.opacity(0.65)
                    : Color.orange.opacity(0.55)
                ctx.fill(
                    Path(roundedRect: r, cornerRadius: area.cornerRadius * 0.6),
                    with: .color(color)
                )
            }
        }
    }

    private func drawSilhouette(ctx: GraphicsContext, w: CGFloat, h: CGFloat) {
        // Head
        ctx.fill(
            Path(ellipseIn: CGRect(x: w*0.35, y: h*0.00, width: w*0.30, height: h*0.12)),
            with: .color(.white.opacity(0.08))
        )
        // Torso
        ctx.fill(
            Path(roundedRect: CGRect(x: w*0.22, y: h*0.13, width: w*0.56, height: h*0.32), cornerRadius: 4),
            with: .color(.white.opacity(0.08))
        )
        // Left arm
        ctx.fill(
            Path(roundedRect: CGRect(x: w*0.03, y: h*0.13, width: w*0.17, height: h*0.28), cornerRadius: 3),
            with: .color(.white.opacity(0.06))
        )
        // Right arm
        ctx.fill(
            Path(roundedRect: CGRect(x: w*0.80, y: h*0.13, width: w*0.17, height: h*0.28), cornerRadius: 3),
            with: .color(.white.opacity(0.06))
        )
        // Left leg
        ctx.fill(
            Path(roundedRect: CGRect(x: w*0.22, y: h*0.48, width: w*0.24, height: h*0.36), cornerRadius: 4),
            with: .color(.white.opacity(0.07))
        )
        // Right leg
        ctx.fill(
            Path(roundedRect: CGRect(x: w*0.54, y: h*0.48, width: w*0.24, height: h*0.36), cornerRadius: 4),
            with: .color(.white.opacity(0.07))
        )
        // Left calf
        ctx.fill(
            Path(roundedRect: CGRect(x: w*0.23, y: h*0.85, width: w*0.22, height: h*0.14), cornerRadius: 4),
            with: .color(.white.opacity(0.06))
        )
        // Right calf
        ctx.fill(
            Path(roundedRect: CGRect(x: w*0.55, y: h*0.85, width: w*0.22, height: h*0.14), cornerRadius: 4),
            with: .color(.white.opacity(0.06))
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
                .fill(Color(red: 0.10, green: 0.10, blue: 0.15))

            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)

            // Accent glow at top-left
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(red:0.15, green:0.45, blue:1.0).opacity(0.15), .clear],
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
                        icon: "dumbbell.fill",
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

                // CTA Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStart()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.20, green: 0.52, blue: 1.0),
                                        Color(red: 0.08, green: 0.35, blue: 0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint:   .bottomTrailing
                                )
                            )
                            .shadow(color: Color.blue.opacity(0.45), radius: 18, y: 6)

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
                .scaleEffect(buttonPressed ? 0.97 : 1.0)
                .animation(.spring(response: 0.2), value: buttonPressed)
                .simultaneousGesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in withAnimation(.spring(response: 0.15)) { buttonPressed = true } }
                    .onEnded { _ in withAnimation(.spring(response: 0.15)) { buttonPressed = false } }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
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
                .fill(Color(red: 0.10, green: 0.10, blue: 0.15))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1))
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
        case "green":  return Color(red: 0.15, green: 0.85, blue: 0.45)
        case "orange": return Color(red: 0.95, green: 0.60, blue: 0.10)
        default:       return Color(red: 0.95, green: 0.25, blue: 0.30)
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

private struct FlowLayout: Layout {
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
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
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
        guard let profile else { errorMessage = "Profil nenalezen."; return }
        guard let plan = profile.workoutPlans.first(where: { $0.isActive }) else {
            errorMessage = "Nemáš aktivní tréninkový plán."
            return
        }
        let todayWeekday = Calendar.current.component(.weekday, from: .now)
        let dayIndex = todayWeekday == 1 ? 7 : todayWeekday - 1
        guard let found = plan.scheduledDays.first(where: { $0.dayOfWeek == dayIndex && !$0.isRestDay }) else {
            errorMessage = "Dnešek je odpočinkový den. Odpočinek je součástí plánu — tělo roste při zotavení! 💪"
            return
        }
        let newSession = WorkoutSession(plan: plan, plannedDay: found)
        modelContext.insert(newSession)
        try? modelContext.save()
        self.plannedDay = found
        self.session = newSession
        withAnimation(.easeInOut(duration: 0.3)) { isReady = true }
    }
}
