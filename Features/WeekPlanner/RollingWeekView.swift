// RollingWeekView.swift
// Klouzavý 7denní kalendář s možností overridu dnů. Vše česky.

import SwiftUI
import SwiftData

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Day Model
// MARK: ═══════════════════════════════════════════════════════════════════════

enum DayType: String, CaseIterable, Identifiable {
    case workout    = "Trénink"
    case rest       = "Volno"
    case sport      = "Jiný sport"
    case cardio     = "Kardio"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .workout: return "dumbbell.fill"
        case .rest:    return "bed.double.fill"
        case .sport:   return "sportscourt.fill"
        case .cardio:  return "figure.run"
        }
    }

    var tint: Color {
        switch self {
        case .workout: return .appPrimaryAccent
        case .rest:    return .white.opacity(0.3)
        case .sport:   return .orange
        case .cardio:  return .appGreenBadge
        }
    }
}

struct WeekDay: Identifiable {
    let id = UUID()
    let date: Date
    var dayType: DayType
    var label: String          // "Push", "Pull", "Volno", "Fotbal" apod.
    var isToday: Bool
    var isOverridden: Bool     // Uživatel manuálně změnil

    var czechDayName: String {
        WeekDay.dayFormatter.string(from: date).capitalized
    }

    var dayNumber: String {
        WeekDay.numberFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "cs_CZ")
        f.dateFormat = "EEE"
        return f
    }()

    private static let numberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ViewModel
// MARK: ═══════════════════════════════════════════════════════════════════════

@MainActor
final class RollingWeekViewModel: ObservableObject {
    @Published var days: [WeekDay] = []
    @Published var isRecalculating = false
    @Published var recalculationMessage: String?
    @Published var lastRecalculated: Date?

    init() {
        buildWeek()
    }

    /// Sestaví 7 dnů od dneška na základě aktivního plánu.
    func buildWeek() {
        let calendar = Calendar.current
        let today = Date.now
        
        // Načteme aktivní plán z databáze
        let context = SharedModelContainer.container.mainContext
        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
        let plan = profile?.workoutPlans.first(where: { $0.isActive })
        
        days = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let isToday = offset == 0
            
            // Zjistíme den v týdnu (1-7, 1=Po)
            let weekday = calendar.component(.weekday, from: date)
            let ourIdx = (weekday == 1 ? 7 : weekday - 1)
            
            // Najdeme v plánu
            let plannedDay = plan?.scheduledDays.first { $0.dayOfWeek == ourIdx }
            
            let type: DayType = (plannedDay == nil || plannedDay?.isRestDay == true) ? .rest : .workout
            let label = plannedDay?.label ?? (type == .rest ? "Volno" : "Trénink")
            
            return WeekDay(
                date: date,
                dayType: type,
                label: label,
                isToday: isToday,
                isOverridden: false
            )
        }
        
        // Pokud jsme přepočítávali před méně než hodinou, nevoláme AI znovu (šetříme requesty)
        if let last = lastRecalculated, Date().timeIntervalSince(last) < 3600 {
            return
        }
        
        // Po inicializaci automaticky spustíme AI, aby zvážila sytém "rolling" plánu podle historie
        Task { await triggerRecalculation() }
    }

    /// Uživatel přepne den na jiný typ.
    func overrideDay(id: UUID, newType: DayType, customLabel: String?) {
        guard let idx = days.firstIndex(where: { $0.id == id }) else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            days[idx].dayType = newType
            days[idx].label = customLabel ?? newType.rawValue
            days[idx].isOverridden = true
        }

        HapticManager.shared.playMediumClick()

        // Spustíme AI přepočet na pozadí
        Task { await triggerRecalculation() }
    }

    /// AI přepočet zbylých tréninků na základě nového rozložení a historie.
    func triggerRecalculation() async {
        isRecalculating = true
        recalculationMessage = nil

        // Sestavíme kontext pro AI
        let availableDays = days.filter { $0.dayType == .workout && !$0.isToday }
        let totalWorkoutDays = days.filter { $0.dayType == .workout }.count

        // Načteme historii posledních 5 tréninků pro kontext
        let context = SharedModelContainer.container.mainContext
        let statusCompleted = SessionStatus.completed
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.status == statusCompleted },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let recentSessions: [WorkoutSession] = (try? context.fetch(descriptor)) ?? []
        let historyLabels = recentSessions.prefix(5).map { session -> String in
            if let label = session.plannedDay?.label { return label }
            if let firstEx = session.exercises.first { return firstEx.exerciseName }
            return "Trénink"
        }

        do {
            let newSchedule = try await AIReschedulingEngine.recalculateWeek(
                currentDays: days,
                availableWorkoutDays: availableDays.count,
                totalDays: 7,
                historyDescriptions: Array(historyLabels)
            )

            // Animovaně aktualizujeme labels
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                for update in newSchedule {
                    if let idx = days.firstIndex(where: { $0.date.isSameDay(as: update.date) }),
                       days[idx].dayType == .workout {
                        days[idx].label = update.label
                    }
                }
            }

            lastRecalculated = Date()
            recalculationMessage = "Plán přepočítán — \(totalWorkoutDays) tréninkových dnů tento týden."
            HapticManager.shared.playSuccess()
        } catch {
            recalculationMessage = "Přepočet se nezdařil, plán zůstává beze změn."
            HapticManager.shared.playWarning()
        }

        isRecalculating = false
        lastRecalculated = Date()
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: View
// MARK: ═══════════════════════════════════════════════════════════════════════

struct RollingWeekView: View {
    @StateObject private var vm = RollingWeekViewModel()
    @State private var showOverrideSheet = false
    @State private var selectedDayForEdit: WeekDay?
    @State private var selectedWorkoutDay: WeekDay?    // Den pro zobrazení cviků
    @State private var showWorkout = false
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    private var profile: UserProfile? { profiles.first }
    private var activePlan: WorkoutPlan? {
        profile?.workoutPlans.first(where: { $0.isActive })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Nadpis
            HStack {
                Text("TENTO TÝDEN")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white.opacity(0.3))
                    .kerning(1.5)
                Spacer()
                if vm.isRecalculating {
                    HStack(spacing: 6) {
                        ProgressView().tint(.white.opacity(0.5))
                            .scaleEffect(0.7)
                        Text("Přepočítávám…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            // 7denní scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.days) { day in
                        DayCell(day: day) {
                            if day.dayType == .workout {
                                // Tréninkový den → toggle zobrazení cviků
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                    if selectedWorkoutDay?.id == day.id {
                                        selectedWorkoutDay = nil
                                    } else {
                                        selectedWorkoutDay = day
                                    }
                                }
                            } else {
                                selectedDayForEdit = day
                                showOverrideSheet = true
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal, 4)
            }

            // Status zpráva
            if let msg = vm.recalculationMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .transition(.opacity)
            }

            // ── Detail dne se cviky ──────────────────────────────────────────
            if let selectedDay = selectedWorkoutDay {
                WeekDayExerciseDetailView(
                    day: selectedDay,
                    plan: activePlan,
                    onStartWorkout: {
                        showWorkout = true
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1))
        )
        .sheet(item: $selectedDayForEdit) { day in
            DayOverrideSheet(day: day) { newType, label in
                vm.overrideDay(id: day.id, newType: newType, customLabel: label)
                showOverrideSheet = false
            }
            .presentationDetents([.height(380)])
        }
        .fullScreenCover(isPresented: $showWorkout) {
            WorkoutLaunchWrapper(
                profile: profile,
                activePlan: activePlan,
                selectedDay: selectedWorkoutDay,
                onDismiss: { showWorkout = false }
            )
        }
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let day: WeekDay
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(day.czechDayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))

                ZStack {
                    Circle()
                        .fill(day.isToday
                              ? day.dayType.tint
                              : day.dayType.tint.opacity(0.15))
                        .frame(width: 48, height: 48)
                    if day.isToday {
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 2)
                            .frame(width: 48, height: 48)
                    }
                    Image(systemName: day.dayType.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(day.isToday ? .white : day.dayType.tint)
                }

                Text(day.dayNumber)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(day.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .frame(width: 50)

                if day.isOverridden {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day Override Sheet

private struct DayOverrideSheet: View {
    let day: WeekDay
    let onSave: (DayType, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: DayType = .rest
    @State private var customLabel: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(.white.opacity(0.18))
                .frame(width: 36, height: 4).padding(.top, 12)

            Text("Změnit den — \(day.czechDayName) \(day.dayNumber).")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                ForEach(DayType.allCases) { type in
                    Button {
                        withAnimation(.spring(response: 0.25)) { selectedType = type }
                        HapticManager.shared.playSelection()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(type.tint)
                                .frame(width: 28)
                            Text(type.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            if selectedType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(type.tint)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedType == type
                                      ? type.tint.opacity(0.12)
                                      : Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(selectedType == type
                                            ? type.tint.opacity(0.3)
                                            : Color.white.opacity(0.06), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if selectedType == .sport {
                TextField("Název sportu (např. Tenis, Fotbal)", text: $customLabel)
                    .font(.system(size: 14))
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)))
                    .foregroundStyle(.white)
            }

            Button {
                let label = selectedType == .sport && !customLabel.isEmpty ? customLabel : nil
                onSave(selectedType, label)
                dismiss()
            } label: {
                Text("Uložit změnu")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Color.appSecondaryBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { selectedType = day.dayType }
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - WeekDayExerciseDetailView
// Zobrazí seznam cviků pro vybraný tréninkový den z aktivního plánu
// ─────────────────────────────────────────────────────────────────

struct WeekDayExerciseDetailView: View {
    let day: WeekDay
    let plan: WorkoutPlan?
    var onStartWorkout: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext

    // Mapování WeekDay.date → dayOfWeek (1=Po...7=Ne)
    private var ourDayIndex: Int {
        let cal = Calendar.current
        let wd = cal.component(.weekday, from: day.date)
        return wd == 1 ? 7 : wd - 1
    }

    private var plannedDay: PlannedWorkoutDay? {
        plan?.scheduledDays.first { $0.dayOfWeek == ourDayIndex && !$0.isRestDay }
    }

    private var exercises: [PlannedExercise] {
        let exs = (plannedDay?.plannedExercises ?? []).sorted { $0.order < $1.order }
        // Auto-repair: pokud exercise relationship chybí, zkus dohledat podle pořadí
        if exs.contains(where: { $0.exercise == nil }) {
            repairMissingExercises(exs)
        }
        return exs
    }

    /// Opravuje chybějící exercise relationship v PlannedExercise (race condition při seeding)
    private func repairMissingExercises(_ exs: [PlannedExercise]) {
        guard let label = plannedDay?.label else { return }
        let slugMap: [String: [String]] = [
            "Push": ["barbell-bench-press", "overhead-press", "lateral-raise", "tricep-pushdown"],
            "Pull": ["pull-up", "barbell-row", "face-pull", "barbell-curl"],
            "Legs": ["barbell-squat", "romanian-deadlift", "leg-extension", "calf-raise"],
            "Upper": ["dumbbell-bench-press", "cable-row", "dumbbell-shoulder-press", "tricep-dip"],
            "Lower": ["leg-press", "lying-leg-curl", "goblet-squat", "hip-thrust"],
            "Fullbody": ["barbell-squat", "barbell-bench-press", "barbell-row", "plank"]
        ]
        let normalized = label.components(separatedBy: " ").first ?? label
        guard let slugs = slugMap[normalized] else { return }
        let allExercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        for (i, ex) in exs.enumerated() where ex.exercise == nil && i < slugs.count {
            if let found = allExercises.first(where: { $0.slug == slugs[i] }) {
                ex.exercise = found
            }
        }
        try? modelContext.save()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hlavička
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.label.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.appPrimaryAccent)
                        .kerning(1.2)
                    Text(exercises.isEmpty ? "Cviky vygeneruje Jakub při startu" : "\(exercises.count) cviků")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.2))
            }

            Divider().background(Color.white.opacity(0.07))

            if exercises.isEmpty {
                // Prázdný stav — AI vygeneruje cviky při spuštění tréninku
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue.opacity(0.7))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Plán čeká na AI")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Klikni na „Začít trénink“ a Jakub sestaví personalizovaný workout.")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.2), lineWidth: 1)))
            } else {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, ex in
                    HStack(spacing: 12) {
                        // Pořadí
                        ZStack {
                            Circle().fill(Color.white.opacity(0.07)).frame(width: 28, height: 28)
                            Text("\(idx + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        // Info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ex.exercise?.name ?? ex.exercise?.nameEN ?? "Cvik \(idx + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ex.exercise == nil ? .white.opacity(0.4) : .white)
                            Text("\(ex.targetSets)× \(ex.targetRepsMin)–\(ex.targetRepsMax) rep · \(ex.restSeconds / 60)m \(ex.restSeconds % 60)s pauza")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                        if let lastWeight = ex.exercise?.lastUsedWeight {
                            Text(String(format: "%.0f kg", lastWeight))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange.opacity(0.8))
                        }
                    }
                    if idx < exercises.count - 1 {
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
            }
            // ── Začít trénink button — zobrazuje se pro všechny tréninkové dny ──
            Button(action: { onStartWorkout?() }) {
                HStack(spacing: 10) {
                    Image(systemName: day.isToday ? "play.fill" : "play.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(day.isToday ? "Začít trénink" : "Spustit trénink (\(day.czechDayName))")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(day.isToday
                            ? LinearGradient(
                                colors: [Color(red: 0.20, green: 0.52, blue: 1.0),
                                         Color(red: 0.08, green: 0.35, blue: 0.85)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(day.isToday ? Color.clear : Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: day.isToday ? .blue.opacity(0.4) : .clear, radius: 14, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.appPrimaryAccent.opacity(0.2), lineWidth: 1))
        )
    }
}


// MARK: - WorkoutLaunchWrapper
// Bezpečně spustí workout, ošetří všechny edge cases aby nevznikla černá obrazovka

struct WorkoutLaunchWrapper: View {
    let profile: UserProfile?
    let activePlan: WorkoutPlan?
    let selectedDay: WeekDay?
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @State private var session: WorkoutSession?
    @State private var plannedDay: PlannedWorkoutDay?
    @State private var isReady = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()

            if let errorMessage {
                // Chyba — zobrazíme info a tlačítko zpět
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.orange)
                    Text("Nelze spustit trénink")
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
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.12)))
                            .padding(.horizontal, 40)
                    }
                    .buttonStyle(.plain)
                }
                .preferredColorScheme(.dark)
            } else if isReady, let session, let plannedDay, let profile {
                WorkoutViewWithAI(
                    session: session,
                    plannedDay: plannedDay,
                    profile: profile
                )
            } else {
                // Loading
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
        guard profile != nil else {
            errorMessage = "Profil nenalezen. Zkontroluj nastavení."
            return
        }
        guard let plan = activePlan else {
            errorMessage = "Nemáš aktivní tréninkový plán. Dokonči onboarding nebo si vytvoř plán."
            return
        }
        guard let day = selectedDay else {
            errorMessage = "Nebyl vybrán žádný den."
            return
        }

        let cal = Calendar.current
        let wd = cal.component(.weekday, from: day.date)
        let ourIdx = wd == 1 ? 7 : wd - 1

        // Najdeme plannedDay
        guard let found = plan.scheduledDays.first(where: {
            $0.dayOfWeek == ourIdx && !$0.isRestDay
        }) else {
            errorMessage = "Pro \(day.label) (\(day.czechDayName)) neexistuje tréninkový plán. Je to odpočinkový den."
            return
        }

        // Vytvoříme session pouze jednou (ne při každém renderu)
        let newSession = WorkoutSession(plan: plan, plannedDay: found)
        modelContext.insert(newSession)
        try? modelContext.save()

        self.plannedDay = found
        self.session = newSession

        withAnimation(.easeInOut(duration: 0.3)) {
            isReady = true
        }
    }
}
