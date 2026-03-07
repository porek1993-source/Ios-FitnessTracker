// QuickWorkoutPickerView.swift
// Agilní Fitness Trenér — Smart Quick Workout Hub
//
// Moduly:
//   1. Partie (svalová skupina)         → cílený silový trénink z DB
//   2. Zdravotní problém                → terapeutický/mobilizační plán
//   3. Ženské zdraví & Cycle Syncing    → trénink podle fáze cyklu
//   4. Anti-Stres & Mentální Reset      → "Dneska toho mám dost"
//   5. Sport-Specific Prehab            → prevence pro konkrétní sport
//   6. Longevity 50+                    → rovnováha, úchop, funkční pohyb
//   7. Micro-Breaks                     → kancelářské přestávky + notifikace
//
// ⚠️ TÝDENNÍ PLÁN: NE — všechny session jsou standalone (dayOfWeek = 99)

import SwiftUI
import SwiftData
import UserNotifications

// MARK: ══════════════════════════════════════════════════════════════════════
// MARK: MAIN VIEW
// MARK: ══════════════════════════════════════════════════════════════════════

struct QuickWorkoutPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var selectedModule: QuickModule = .muscle
    @State private var workoutDuration: Int = 45
    @State private var isGenerating = false

    @State private var selectedMuscle: MuscleTarget? = nil
    @State private var selectedHealthPlan: QuickWorkoutPlan? = nil
    @State private var selectedCyclePhase: CyclePhase? = nil
    @State private var selectedSport: SportPrehab? = nil
    @State private var selectedLongevity: QuickWorkoutPlan? = nil
    @State private var microBreaksEnabled = false
    @State private var microBreakInterval: Int = 2
    @State private var showMicroBreakSuccess = false

    var readyToGenerate: Bool {
        switch selectedModule {
        case .muscle:     return selectedMuscle != nil
        case .health:     return selectedHealthPlan != nil
        case .femHealth:  return selectedCyclePhase != nil
        case .antiStress: return true
        case .prehab:     return selectedSport != nil
        case .longevity:  return selectedLongevity != nil
        case .microBreak: return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    moduleTabBar
                    durationBar
                    contentScrollView
                }
                if readyToGenerate || selectedModule == .antiStress {
                    generateButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Rychlý trénink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavřít") { dismiss() }.foregroundStyle(.white.opacity(0.6))
                }
            }
            .onChange(of: selectedModule) { _, _ in clearSelections() }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: ─── Module Tab Bar ──────────────────────────────────────────────

    private var moduleTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(QuickModule.allCases) { module in
                    let isSelected = selectedModule == module
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) { selectedModule = module }
                        HapticManager.shared.playSelection()
                    }) {
                        VStack(spacing: 5) {
                            Image(systemName: module.icon).font(.system(size: 15, weight: .semibold))
                            Text(module.rawValue).font(.system(size: 9, weight: .bold)).lineLimit(1)
                        }
                        .foregroundStyle(isSelected ? module.accent : .white.opacity(0.4))
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(isSelected ? module.accent.opacity(0.14) : Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 11)
                                    .stroke(isSelected ? module.accent.opacity(0.45) : .clear, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(AppColors.secondaryBg)
    }

    // MARK: ─── Duration Bar ───────────────────────────────────────────────

    @ViewBuilder
    private var durationBar: some View {
        if selectedModule != .microBreak && selectedModule != .antiStress {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "clock").font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                    Text("Délka:").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                }
                .padding(.leading, 14)
                Spacer()
                HStack(spacing: 5) {
                    ForEach([20, 30, 45, 60], id: \.self) { min in
                        Button("\(min) min") {
                            withAnimation(.spring(response: 0.25)) { workoutDuration = min }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(workoutDuration == min ? .white : .white.opacity(0.38))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(workoutDuration == min
                                                    ? selectedModule.accent.opacity(0.2)
                                                    : Color.white.opacity(0.05))
                            .overlay(Capsule().stroke(workoutDuration == min
                                                       ? selectedModule.accent.opacity(0.38)
                                                       : .clear, lineWidth: 1)))
                    }
                }
                .padding(.trailing, 14)
            }
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.02))
        }
    }

    // MARK: ─── Content ───────────────────────────────────────────────────

    private var contentScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                moduleHeaderBanner
                switch selectedModule {
                case .muscle:     muscleContent
                case .health:     healthContent
                case .femHealth:  femHealthContent
                case .antiStress: antiStressContent
                case .prehab:     prehabContent
                case .longevity:  longevityContent
                case .microBreak: microBreakContent
                }
            }
            .padding(.horizontal, 16).padding(.top, 12)
            .padding(.bottom, (readyToGenerate || selectedModule == .antiStress) ? 140 : 40)
        }
    }

    private var moduleHeaderBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: selectedModule.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(selectedModule.accent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(selectedModule.accent.opacity(0.14))
                    .overlay(Circle().stroke(selectedModule.accent.opacity(0.22), lineWidth: 1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedModule.rawValue)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(selectedModule.tagline)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(selectedModule.accent.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(selectedModule.accent.opacity(0.15), lineWidth: 1)))
    }

    // MARK: ─── MODULE 1: Partie ──────────────────────────────────────────

    private var muscleContent: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(MuscleTarget.all) { target in
                MuscleTargetCell(
                    target: target,
                    isSelected: selectedMuscle?.id == target.id,
                    onTap: {
                        withAnimation(.spring(response: 0.28)) {
                            selectedMuscle = (selectedMuscle?.id == target.id) ? nil : target
                        }
                        HapticManager.shared.playMediumClick()
                    }
                )
            }
        }
    }

    // MARK: ─── MODULE 2: Zdraví ──────────────────────────────────────────

    private var healthContent: some View {
        ForEach(QuickWorkoutPlan.healthProblems) { plan in
            ExpandablePlanCard(
                plan: plan,
                isSelected: selectedHealthPlan?.id == plan.id,
                onTap: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedHealthPlan = selectedHealthPlan?.id == plan.id ? nil : plan
                    }
                    HapticManager.shared.playMediumClick()
                }
            )
        }
    }

    // MARK: ─── MODULE 3: Ženské zdraví ──────────────────────────────────

    private var femHealthContent: some View {
        VStack(spacing: 10) {
            Text("Vyber fázi cyklu")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.35))
                .kerning(1.2).textCase(.uppercase).frame(maxWidth: .infinity, alignment: .leading)

            ForEach(CyclePhase.allCases) { phase in
                CyclePhaseCard(
                    phase: phase,
                    isSelected: selectedCyclePhase == phase,
                    onTap: {
                        withAnimation(.spring(response: 0.35)) {
                            selectedCyclePhase = (selectedCyclePhase == phase) ? nil : phase
                        }
                        HapticManager.shared.playMediumClick()
                    }
                )
            }
        }
    }

    // MARK: ─── MODULE 4: Anti-Stres ─────────────────────────────────────

    private var antiStressContent: some View {
        AntiStressCard()
    }

    // MARK: ─── MODULE 5: Prehab ──────────────────────────────────────────

    private var prehabContent: some View {
        ForEach(SportPrehab.all) { sport in
            SportPrehabCard(
                sport: sport,
                isSelected: selectedSport?.id == sport.id,
                onTap: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedSport = (selectedSport?.id == sport.id) ? nil : sport
                    }
                    HapticManager.shared.playMediumClick()
                }
            )
        }
    }

    // MARK: ─── MODULE 6: Longevity ───────────────────────────────────────

    private var longevityContent: some View {
        VStack(spacing: 10) {
            LongevityHeroBanner()

            ForEach(QuickWorkoutPlan.longevityFocus) { plan in
                ExpandablePlanCard(
                    plan: plan,
                    isSelected: selectedLongevity?.id == plan.id,
                    onTap: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedLongevity = (selectedLongevity?.id == plan.id) ? nil : plan
                        }
                        HapticManager.shared.playMediumClick()
                    }
                )
            }
        }
    }

    // MARK: ─── MODULE 7: Micro-Breaks ────────────────────────────────────

    private var microBreakContent: some View {
        MicroBreakView(
            microBreakInterval: $microBreakInterval,
            microBreaksEnabled: $microBreaksEnabled,
            showSuccess: showMicroBreakSuccess,
            onSchedule: scheduleMicroBreaks,
            onCancel: cancelMicroBreaks,
            onSelectBreak: { ex in startMicroBreak(ex) }
        )
    }

    // MARK: ─── Generate Button ───────────────────────────────────────────

    private var generateButton: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, AppColors.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 24).allowsHitTesting(false)

            if let label = ctaLabel {
                HStack(spacing: 8) {
                    Image(systemName: selectedModule.icon).font(.system(size: 12)).foregroundStyle(selectedModule.accent)
                    Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(selectedModule.accent)
                }
                .padding(.horizontal, 16).padding(.vertical, 7)
                .background(selectedModule.accent.opacity(0.07))
            }

            Button(action: generateSelectedWorkout) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "bolt.fill").font(.system(size: 14))
                    }
                    Text(isGenerating ? "Připravuji..." : "Spustit trénink")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(LinearGradient(colors: [selectedModule.accent, selectedModule.accent.opacity(0.72)],
                                           startPoint: .leading, endPoint: .trailing))
            }
            .disabled(isGenerating).padding(.horizontal, 16).padding(.vertical, 10)
            .background(AppColors.background)
        }
        .animation(.spring(response: 0.3), value: ctaLabel)
    }

    private var ctaLabel: String? {
        switch selectedModule {
        case .muscle:     return selectedMuscle.map { "Partie: \($0.title)" }
        case .health:     return selectedHealthPlan.map { $0.label }
        case .femHealth:  return selectedCyclePhase.map { "Fáze: \($0.rawValue)" }
        case .antiStress: return "15 min · Anti-Stres Reset"
        case .prehab:     return selectedSport.map { $0.sport }
        case .longevity:  return selectedLongevity.map { $0.label }
        case .microBreak: return nil
        }
    }

    // MARK: ─── Logic ─────────────────────────────────────────────────────

    private func clearSelections() {
        selectedMuscle = nil; selectedHealthPlan = nil
        selectedCyclePhase = nil; selectedSport = nil; selectedLongevity = nil
    }

    private func generateSelectedWorkout() {
        isGenerating = true
        HapticManager.shared.playMediumClick()
        Task { @MainActor in
            let plan: QuickWorkoutPlan?
            switch selectedModule {
            case .muscle:
                if let m = selectedMuscle { let s = generateMuscleWorkout(target: m); finishGeneration(session: s); return }
                plan = nil
            case .health:     plan = selectedHealthPlan
            case .femHealth:  plan = selectedCyclePhase?.workoutPlan
            case .antiStress: plan = QuickWorkoutPlan.antiStress
            case .prehab:     plan = selectedSport?.plan
            case .longevity:  plan = selectedLongevity
            case .microBreak: plan = nil
            }
            if let p = plan { finishGeneration(session: generatePlanWorkout(plan: p)) }
            else { isGenerating = false }
        }
    }

    private func finishGeneration(session: WorkoutSession) {
        do {
            try modelContext.save()
        } catch {
            AppLogger.error("QuickWorkoutPickerView: Nepodařilo se uložit vygenerovaný trénink: \(error)")
            // Pokračujeme i přes chybu — session je v paměti a trénink lze odcvičit
        }
        NotificationCenter.default.post(name: NSNotification.Name("StartCustomWorkout"), object: session)
        isGenerating = false
        dismiss()
    }

    private func generateMuscleWorkout(target: MuscleTarget) -> WorkoutSession {
        var matched: [Exercise] = []
        for slug in target.exerciseSlugs {
            if let ex = allExercises.first(where: { $0.slug == slug || $0.slug.contains(slug) }),
               !matched.contains(where: { $0.id == ex.id }) { matched.append(ex) }
        }
        if matched.count < 4 {
            let byMuscle = allExercises.filter { ex in
                target.muscleGroups.contains(where: { ex.musclesTarget.contains($0) })
                && !matched.contains(where: { $0.id == ex.id })
            }
            matched.append(contentsOf: byMuscle.prefix(6 - matched.count))
        }
        let maxEx = workoutDuration <= 20 ? 3 : workoutDuration <= 30 ? 4 : workoutDuration <= 45 ? 5 : 6
        return createSession(label: "\(target.icon) \(target.title) — Rychlý trénink",
                             exercises: Array(matched.prefix(maxEx)),
                             sets: workoutDuration <= 20 ? 2 : 3)
    }

    private func generatePlanWorkout(plan: QuickWorkoutPlan) -> WorkoutSession {
        var exercises: [Exercise] = []
        for t in plan.exercises {
            let match = allExercises.first(where: {
                $0.slug == t.slug || $0.nameEN.lowercased() == t.nameEN.lowercased()
                || $0.name.localizedCaseInsensitiveContains(t.name.components(separatedBy: " — ").first ?? t.name)
            })
            if let ex = match {
                exercises.append(ex)
            } else {
                let ep = Exercise(slug: t.slug, name: t.name, nameEN: t.nameEN, category: .core, movementPattern: .isolation,
                                   equipment: t.isBodyweight ? [.bodyweight] : [.resistanceBand],
                                   musclesTarget: [], musclesSecondary: [], isUnilateral: false, instructions: t.coachTip)
                modelContext.insert(ep); exercises.append(ep)
            }
        }
        return createSession(label: "\(plan.icon) \(plan.label)", exercises: exercises, sets: 3)
    }

    private func createSession(label: String, exercises: [Exercise], sets: Int) -> WorkoutSession {
        let day = PlannedWorkoutDay(dayOfWeek: 99, label: label)
        modelContext.insert(day)
        let session = WorkoutSession(plan: nil, plannedDay: day)
        modelContext.insert(session)
        for (i, ex) in exercises.enumerated() {
            let p = PlannedExercise(order: i, exercise: ex, targetSets: sets, targetRepsMin: 10, targetRepsMax: 15)
            p.plannedDay = day
            _ = SessionExercise(order: i, exercise: ex, session: session)
        }
        return session
    }

    private func scheduleMicroBreaks() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: MicroBreakExercise.deskBreaks.map { "mb_\($0.id)" })
            for (i, ex) in MicroBreakExercise.deskBreaks.shuffled().prefix(8).enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "⏱️ \(ex.duration) pro tvoje tělo"
                content.body = "\(ex.icon) \(ex.title) — \(String(ex.instruction.prefix(70)))"
                content.sound = .default
                var c = DateComponents(); c.hour = 8 + (i * microBreakInterval); c.minute = 0
                let req = UNNotificationRequest(identifier: "mb_\(ex.id)", content: content,
                                                 trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: true))
                center.add(req)
            }
            Task { @MainActor in
                withAnimation { showMicroBreakSuccess = true }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation { showMicroBreakSuccess = false }
            }
        }
    }

    private func cancelMicroBreaks() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: MicroBreakExercise.deskBreaks.map { "mb_\($0.id)" })
    }

    private func startMicroBreak(_ ex: MicroBreakExercise) {
        let plan = QuickWorkoutPlan(
            label: "Micro-Break: \(ex.title)",
            icon: ex.icon,
            accentColor: Color(red: 0.95, green: 0.30, blue: 0.30),
            exercises: [
                QuickExerciseTemplate(name: ex.title, nameEN: ex.title, slug: "micro-break-\(ex.id)", sets: 1, repsMin: 1, repsMax: 1, isBodyweight: true, coachTip: ex.instruction, durationSeconds: ex.durationSeconds)
            ],
            warmupItems: [],
            coachNote: ex.benefit,
            estimatedMinutes: 2,
            intensity: .low
        )
        let session = generatePlanWorkout(plan: plan)
        finishGeneration(session: session)
    }
}

// MARK: - Subviews

struct MuscleTargetCell: View {
    let target: MuscleTarget
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(target.icon).font(.system(size: 24))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.blue)
                    }
                }
                Text(target.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(target.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cellBackground)
            .shadow(color: isSelected ? Color.blue.opacity(0.18) : .clear, radius: 6)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28), value: isSelected)
    }

    @ViewBuilder
    private var cellBackground: some View {
        let bgColor = isSelected ? Color.blue.opacity(0.13) : Color.white.opacity(0.045)
        let strokeColor = isSelected ? Color.blue.opacity(0.45) : Color.white.opacity(0.08)
        
        RoundedRectangle(cornerRadius: 13)
            .fill(bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(strokeColor, lineWidth: isSelected ? 1.5 : 1)
            )
    }
}

struct ExpandablePlanCard: View {
    let plan: QuickWorkoutPlan
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Text(plan.icon).font(.system(size: 24)).frame(width: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.label).font(.system(size: 14).bold()).foregroundStyle(.white)
                        Text("\(plan.estimatedMinutes) min · \(plan.intensity.rawValue)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                        .font(.system(size: isSelected ? 18 : 13))
                        .foregroundStyle(isSelected ? plan.accentColor : .white.opacity(0.3))
                }
                .padding(13)
            }
            .buttonStyle(.plain)

            if isSelected {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().background(Color.white.opacity(0.07))
                    Text(plan.coachNote).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                        .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(plan.accentColor.opacity(0.07)))
                    ForEach(plan.exercises) { ex in QuickExerciseRow(ex: ex, accent: plan.accentColor) }
                }
                .padding(.horizontal, 13).padding(.bottom, 13)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? plan.accentColor.opacity(0.08) : Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? plan.accentColor.opacity(0.35) : Color.white.opacity(0.07),
                            lineWidth: isSelected ? 1.5 : 1))
        )
        .animation(.spring(response: 0.28), value: isSelected)
    }

}

struct CyclePhaseCard: View {
    let phase: CyclePhase
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Text(phase.icon).font(.system(size: 22)).frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phase.rawValue).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        Text(phase.subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? phase.accentColor : .white.opacity(0.2))
                }
                .padding(13)
            }
            .buttonStyle(.plain)

            if isSelected {
                phaseExpandedContent
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? phase.accentColor.opacity(0.08) : Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? phase.accentColor.opacity(0.4) : Color.white.opacity(0.07),
                            lineWidth: isSelected ? 1.5 : 1))
        )
        .animation(.spring(response: 0.28), value: isSelected)
    }

    private var phaseExpandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().background(Color.white.opacity(0.07))
            Text(phase.description)
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(phase.accentColor.opacity(0.07)))
            
            HStack(spacing: 8) {
                IntensityBadgeView(intensity: phase.workoutPlan.intensity)
                Label("\(phase.workoutPlan.estimatedMinutes) min", systemImage: "clock")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            }
            
            ForEach(phase.workoutPlan.exercises) { ex in
                QuickExerciseRow(ex: ex, accent: phase.accentColor)
            }
        }
        .padding(.horizontal, 13).padding(.bottom, 13)
    }
}

struct SportPrehabCard: View {
    let sport: SportPrehab
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Text(sport.icon).font(.system(size: 26)).frame(width: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sport.sport).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9)).foregroundStyle(sport.accentColor.opacity(0.8))
                            Text("Riziko: \(sport.riskArea)").font(.system(size: 11)).foregroundStyle(sport.accentColor.opacity(0.8))
                        }
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                        .font(.system(size: isSelected ? 18 : 13))
                        .foregroundStyle(isSelected ? sport.accentColor : .white.opacity(0.28))
                }
                .padding(13)
            }
            .buttonStyle(.plain)

            if isSelected {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().background(Color.white.opacity(0.07))
                    Text(sport.plan.coachNote).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                        .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(sport.accentColor.opacity(0.07)))
                    ForEach(sport.plan.exercises) { ex in
                        QuickExerciseRow(ex: ex, accent: sport.accentColor)
                    }
                }
                .padding(.horizontal, 13).padding(.bottom, 13)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? sport.accentColor.opacity(0.08) : Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? sport.accentColor.opacity(0.38) : Color.white.opacity(0.07),
                            lineWidth: isSelected ? 1.5 : 1))
        )
    }
}

struct LongevityHeroBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("🌿").font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text("Investice do dalších 30 let").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                Text("Vyber oblast na které chceš pracovat").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.15, green: 0.82, blue: 0.88).opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.15, green: 0.82, blue: 0.88).opacity(0.18), lineWidth: 1)))
    }
}

struct IntensityBadgeView: View {
    let intensity: QuickWorkoutPlan.WorkoutIntensity
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: intensity.icon).font(.system(size: 9))
            Text(intensity.rawValue).font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(intensity.color.opacity(0.15)))
        .foregroundStyle(intensity.color)
    }
}

struct QuickExerciseRow: View {
    let ex: QuickExerciseTemplate
    let accent: Color
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                if let dur = ex.durationSeconds {
                    Text("\(dur)s · \(ex.coachTip)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                } else {
                    Text("\(ex.sets)×\(ex.repsMin)-\(ex.repsMax) · \(ex.coachTip)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "info.circle").font(.system(size: 12)).foregroundStyle(accent.opacity(0.5))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
    }
}

struct MicroBreakView: View {
    @Binding var microBreakInterval: Int
    @Binding var microBreaksEnabled: Bool
    let showSuccess: Bool
    let onSchedule: () -> Void
    let onCancel: () -> Void
    let onSelectBreak: (MicroBreakExercise) -> Void

    var body: some View {
        let accent = Color(red: 0.95, green: 0.30, blue: 0.30)
        VStack(spacing: 14) {
            // Toggle
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill").font(.system(size: 20)).foregroundStyle(accent).frame(width: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Připomínky každé \(microBreakInterval)h").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        Text("Notifikace s cvikem na protažení").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Toggle("", isOn: $microBreaksEnabled).tint(accent)
                        .onChange(of: microBreaksEnabled) { _, on in if on { onSchedule() } else { onCancel() } }
                }
                .padding(13)

                if microBreaksEnabled {
                    Divider().background(Color.white.opacity(0.07))
                    HStack {
                        Text("Interval:").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)).padding(.leading, 13)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach([1, 2, 3], id: \.self) { h in
                                Button("\(h)h") { microBreakInterval = h; onSchedule() }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(microBreakInterval == h ? .white : .white.opacity(0.4))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Capsule().fill(microBreakInterval == h ? accent.opacity(0.22) : Color.white.opacity(0.05)))
                            }
                        }
                        .padding(.trailing, 13)
                    }
                    .padding(.vertical, 8)
                }

                if showSuccess {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Připomínky nastaveny!").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 13).padding(.bottom, 10)
                    .transition(.opacity)
                }
            }
            .background(RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(microBreaksEnabled ? accent.opacity(0.3) : Color.white.opacity(0.07), lineWidth: 1)))

            Text("Kancelářský zásobník")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.35))
                .kerning(1.2).textCase(.uppercase).frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(MicroBreakExercise.deskBreaks) { ex in
                    Button(action: {
                        HapticManager.shared.playMediumClick()
                        onSelectBreak(ex)
                    }) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(ex.icon).font(.system(size: 18))
                                Spacer()
                                Text(ex.duration).font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(accent.opacity(0.8))
                                    .padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Capsule().fill(accent.opacity(0.1)))
                            }
                            Text(ex.title).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            Text(ex.benefit).font(.system(size: 10)).foregroundStyle(.white.opacity(0.48)).lineLimit(2)
                        }
                        .padding(11).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 11)
                            .fill(Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.07), lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                }
            }

            // 20-20-20 highlight
            HStack(alignment: .top, spacing: 10) {
                Text("👁️").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pravidlo 20-20-20").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    Text("Každých **20 minut** se podívej na bod vzdálený **20 stop (6m)** po dobu **20 sekund**. Uvolňuje ciliární sval a snižuje únavu zraku od modrého světla.")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(13)
            .background(RoundedRectangle(cornerRadius: 13)
                .fill(accent.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(accent.opacity(0.18), lineWidth: 1)))
        }
    }
}

struct AntiStressCard: View {
    let plan = QuickWorkoutPlan.antiStress
    let accent = Color(red: 0.58, green: 0.44, blue: 0.95)
    
    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 14) {
                Text("🧠").font(.system(size: 48))
                Text("Dneska toho mám dost")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white).multilineTextAlignment(.center)
                Text("15 minut. Žádný výkon.\nPouze regulace nervové soustavy.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
            }
            .padding(18).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.15, blue: 0.35), Color(red: 0.12, green: 0.1, blue: 0.22)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.3), lineWidth: 1)))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "brain").foregroundStyle(accent).font(.system(size: 14))
                Text("**Proč to funguje:** Pohyb aktivuje vagus nerv. Pomalé výdechy snižují srdeční frekvenci. Protažení psoas uvolňuje \"sval stresu\". 15 minut = měřitelný pokles kortizolu.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
            }
            .padding(11).background(RoundedRectangle(cornerRadius: 11).fill(accent.opacity(0.07)))

            VStack(alignment: .leading, spacing: 6) {
                Text("Co tě čeká")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.35))
                    .kerning(1.2).textCase(.uppercase)
                ForEach(plan.exercises) { ex in
                    QuickExerciseRow(ex: ex, accent: accent)
                }
            }
        }
    }
}
