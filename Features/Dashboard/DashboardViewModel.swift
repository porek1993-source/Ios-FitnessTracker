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

        // ✅ BEZPEČNOST: 8s timeout chrání UI před zamrznutím pokud HealthKit nereaguje.
        // fetchDailySummary() může blokovat indefinitně pokud je store nedostupný.
        let summary: HKDailySummary? = await withTaskGroup(of: HKDailySummary?.self) { group in
            group.addTask { [weak self] in
                guard let self = self else { return nil }
                // Access healthKit safely on the main actor
                guard let hk = await self.healthKit else { return nil }
                return try? await hk.fetchDailySummary(for: .now)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                return nil   // Timeout
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }

        guard let summary else {
            // Fallback — no HealthKit data nebo timeout
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
            todayPlannedExercises     = day.sortedExercises
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
