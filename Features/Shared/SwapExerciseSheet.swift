// SwapExerciseSheet.swift
// Agilní Fitness Trenér — Smart Swap & Quick Filter System
//
// Použití:
//   .sheet(isPresented: $showSwap) {
//       SwapExerciseSheet(
//           sessionExercise: $currentExercise,
//           allExercises: exerciseDatabase,
//           onSwap: { newExercise, reason in ... }
//       )
//   }

import SwiftUI
import SwiftData

// MARK: - Quick Filter Preset

enum QuickFilterPreset: String, CaseIterable, Identifiable {
    case thirtyMinutes  = "⏱ 30 minut"
    case dumbbellsOnly  = "🏋️ Jen jednoručky"
    case noBarbells     = "🚫 Bez osy"
    case bodyweightOnly = "💪 Bodyweight"
    case cableOnly      = "🔗 Kabelák / stroje"
    case fullGym        = "🏛 Plné vybavení"

    var id: String { rawValue }

    /// Equipment allowed for this preset
    var allowedEquipment: Set<Equipment>? {
        switch self {
        case .thirtyMinutes:  return nil  // handled separately (time logic)
        case .dumbbellsOnly:  return [.dumbbell]
        case .noBarbells:     return [.dumbbell, .cable, .machine, .bodyweight, .resistanceBand, .kettlebell]
        case .bodyweightOnly: return [.bodyweight]
        case .cableOnly:      return [.cable, .machine]
        case .fullGym:        return nil  // no restriction
        }
    }

    var isTimePreset: Bool { self == .thirtyMinutes }

    var color: Color {
        switch self {
        case .thirtyMinutes:  return Color(red: 1.0, green: 0.45, blue: 0.1)
        case .dumbbellsOnly:  return Color(red: 0.2, green: 0.7,  blue: 1.0)
        case .noBarbells:     return Color(red: 0.9, green: 0.25, blue: 0.4)
        case .bodyweightOnly: return Color(red: 0.3, green: 0.85, blue: 0.55)
        case .cableOnly:      return Color(red: 0.7, green: 0.35, blue: 1.0)
        case .fullGym:        return Color(red: 0.95, green: 0.75, blue: 0.1)
        }
    }
}

// MARK: - Swap Reason

enum SwapReason: String, Identifiable {
    case equipmentUnavailable = "Stroj je obsazený"
    case timeLimit            = "Mám málo času"
    case injury               = "Bolest / zranění"
    case preference           = "Chci zkusit jiný cvik"
    case equipment            = "Nemám vybavení"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .equipmentUnavailable: return "person.2.slash"
        case .timeLimit:            return "timer"
        case .injury:               return "bandage"
        case .preference:           return "shuffle"
        case .equipment:            return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Swap Score (biomechanical match)

fileprivate struct SwapCandidate: Identifiable {
    let exercise: Exercise
    var score: Int       // 0–100, higher = better match
    var tags: [String]   // "Stejná partie", "Stejný pohyb", "Bez osy", …
    var id: UUID { exercise.id }
}

// MARK: - Smart Swap Engine

struct SmartSwapEngine {

    /// Scores + filters alternatives for a given exercise.
    fileprivate static func candidates(
        for original: Exercise,
        from pool: [Exercise],
        activePresets: Set<QuickFilterPreset>,
        thirtyMinuteMode: Bool
    ) -> [SwapCandidate] {

        // Allowed equipment union
        var allowedEquip: Set<Equipment>? = nil
        for preset in activePresets where !preset.isTimePreset {
            if let e = preset.allowedEquipment {
                allowedEquip = (allowedEquip ?? Set()).union(e)
            } else {
                allowedEquip = nil  // fullGym = no restriction
                break
            }
        }

        return pool
            .filter { $0.id != original.id }
            .compactMap { candidate -> SwapCandidate? in
                // --- Equipment filter ---
                if let allowed = allowedEquip {
                    let candidateEquip = Set(candidate.equipment)
                    // All candidate equipment must be within allowed set
                    // OR candidate is bodyweight (always ok)
                    if !candidateEquip.isSubset(of: allowed) && !candidateEquip.contains(.bodyweight) {
                        return nil
                    }
                }

                // --- Score ---
                var score = 0
                var tags: [String] = []

                // Primary muscle overlap (most important)
                let primaryOverlap = Set(original.musclesTarget)
                    .intersection(Set(candidate.musclesTarget))
                if primaryOverlap.isEmpty { return nil }   // must hit same primary
                let primaryScore = primaryOverlap.count * 30
                score += min(primaryScore, 60)
                tags.append("Stejná partie")

                // Movement pattern match
                if candidate.movementPattern == original.movementPattern {
                    score += 20
                    tags.append("Stejný pohyb")
                }

                // Secondary muscle overlap (bonus)
                let secondaryOverlap = Set(original.musclesSecondary)
                    .intersection(Set(candidate.musclesSecondary))
                score += secondaryOverlap.count * 5

                // Prefer bodyweight / dumbbell when those presets active
                if activePresets.contains(.dumbbellsOnly) && candidate.equipment.contains(.dumbbell) {
                    score += 10
                    tags.append("Jednoručky ✓")
                }
                if activePresets.contains(.bodyweightOnly) && candidate.equipment.contains(.bodyweight) {
                    score += 10
                    tags.append("Bodyweight ✓")
                }

                // Time preset: prefer unilateral / isolation — faster to set up
                if thirtyMinuteMode {
                    if candidate.equipment.contains(.dumbbell) || candidate.equipment.contains(.bodyweight) {
                        score += 8
                        tags.append("Rychlé nastavení")
                    }
                }

                // Category match (bonus)
                if candidate.category == original.category {
                    score += 5
                }

                return SwapCandidate(exercise: candidate, score: min(score, 100), tags: tags)
            }
            .sorted { $0.score > $1.score }
    }
}

// MARK: - Time Optimizer (30-min mode)

struct TimeOptimizationPlan {
    let originalCount: Int
    let keptExercises: [PlannedExercise]
    let supersets: [(PlannedExercise, PlannedExercise)]
    let estimatedMinutes: Int
}

struct TimeOptimizer {

    static func optimize(
        exercises: [PlannedExercise],
        targetMinutes: Int = 30
    ) -> TimeOptimizationPlan {

        let avgSetDuration = 45   // seconds per set (work + short rest)
        let supersetSaving = 30   // seconds saved per superset pair

        // Estimate time per exercise
        func minutes(_ ex: PlannedExercise) -> Double {
            let sets = ex.targetSets
            let restTotal = sets * ex.restSeconds
            let workTotal = sets * avgSetDuration
            return Double(restTotal + workTotal) / 60.0
        }

        // 1. Sort by compound-first (more sets = more important)
        var sorted = exercises.sorted { $0.targetSets > $1.targetSets }

        // 2. Remove exercises until we fit, keeping compound first
        var kept: [PlannedExercise] = []
        var totalMin = 0.0
        for ex in sorted {
            let t = minutes(ex)
            if totalMin + t <= Double(targetMinutes) {
                kept.append(ex)
                totalMin += t
            }
        }

        // 3. Build supersets from remaining time:
        // Pair antagonist movements (push+pull, bi+tri)
        var supersets: [(PlannedExercise, PlannedExercise)] = []
        if kept.count >= 2 {
            var unpaired = kept
            var paired: [(PlannedExercise, PlannedExercise)] = []
            var i = 0
            while i < unpaired.count - 1 {
                let a = unpaired[i]
                let b = unpaired[i + 1]
                if isAntagonist(a.exercise, b.exercise) {
                    paired.append((a, b))
                    i += 2
                } else {
                    i += 1
                }
            }
            supersets = paired
        }

        // 4. Recalculate with supersets
        let targetSets = kept.first?.targetSets ?? 3
        let savedSeconds = supersets.count * supersetSaving * targetSets
        let finalMinutes = max(20, Int(totalMin * 60 - Double(savedSeconds)) / 60)

        return TimeOptimizationPlan(
            originalCount: exercises.count,
            keptExercises: kept,
            supersets: supersets,
            estimatedMinutes: finalMinutes
        )
    }

    private static func isAntagonist(_ a: Exercise?, _ b: Exercise?) -> Bool {
        guard let a, let b else { return false }
        let antagonistPairs: [(MovementPattern, MovementPattern)] = [
            (.push, .pull),
            (.pull, .push),
            (.squat, .hinge),
            (.hinge, .squat)
        ]
        return antagonistPairs.contains { $0.0 == a.movementPattern && $0.1 == b.movementPattern }
    }
}

// MARK: - SwapExerciseSheet (Main View)

struct SwapExerciseSheet: View {

    // Input
    let sessionExercise: SessionExercise
    let allExercises: [Exercise]
    let plannedExercises: [PlannedExercise]  // current day's plan (for time optimizer)
    let onSwap: (Exercise, String) -> Void
    let onApplyTimeOptimization: (TimeOptimizationPlan) -> Void

    @Environment(\.dismiss) private var dismiss

    // State
    @State private var activePresets: Set<QuickFilterPreset> = []
    @State private var selectedReason: SwapReason?
    @State private var searchText = ""
    @State private var candidates: [SwapCandidate] = []
    @State private var timeOptPlan: TimeOptimizationPlan?
    @State private var showTimeOptBanner = false
    @State private var selectedCandidate: SwapCandidate?
    @State private var animateIn = false

    var thirtyMinuteMode: Bool { activePresets.contains(.thirtyMinutes) }

    private var original: Exercise? { sessionExercise.exercise }

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.07, green: 0.07, blue: 0.1)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.top, 8)

                // Quick filters
                quickFiltersSection
                    .padding(.top, 16)

                // Time optimization banner
                if showTimeOptBanner, let plan = timeOptPlan {
                    timeOptBanner(plan: plan)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Reason selector
                reasonSelector
                    .padding(.top, 16)
                    .padding(.horizontal, 16)

                // Search
                searchField
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Candidates list
                candidatesList
                    .padding(.top, 8)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { animateIn = true }
            recompute()
        }
        .onChange(of: activePresets) { recompute() }
        .onChange(of: searchText) { recompute() }
    }

    // MARK: Header

    private var headerView: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 4)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nahradit cvik")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if let ex = original {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(ex.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    // MARK: Quick Filters

    private var quickFiltersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RYCHLÉ FILTRY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .kerning(1.2)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Spacer(minLength: 10)
                    ForEach(QuickFilterPreset.allCases) { preset in
                        PresetChip(
                            preset: preset,
                            isActive: activePresets.contains(preset)
                        ) {
                            togglePreset(preset)
                        }
                    }
                    Spacer(minLength: 10)
                }
            }
        }
    }

    // MARK: Time Opt Banner

    private func timeOptBanner(plan: TimeOptimizationPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 15))
                VStack(alignment: .leading, spacing: 2) {
                    Text("30minutový plán připraven")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(plan.originalCount) cviků → \(plan.keptExercises.count) cviků · cca \(plan.estimatedMinutes) min")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }

            if !plan.supersets.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Supersérie (\(plan.supersets.count)×):")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    ForEach(Array(plan.supersets.enumerated()), id: \.offset) { _, pair in
                        HStack(spacing: 6) {
                            Circle().fill(Color.orange.opacity(0.7)).frame(width: 6, height: 6)
                            Text("\(pair.0.exercise?.name ?? "?") + \(pair.1.exercise?.name ?? "?")")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
            }

            Button {
                onApplyTimeOptimization(plan)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Použít optimalizovaný plán")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: Reason Selector

    private var reasonSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DŮVOD ZÁMĚNY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .kerning(1.2)

            HStack(spacing: 8) {
                ForEach(SwapReason.allCases, id: \.id) { reason in
                    ReasonChip(reason: reason, isSelected: selectedReason == reason) {
                        selectedReason = selectedReason == reason ? nil : reason
                    }
                }
            }
        }
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.35))
                .font(.system(size: 15))
            TextField("Hledat cvik…", text: $searchText)
                .foregroundStyle(.white)
                .font(.system(size: 15))
                .tint(.blue)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.07))
        )
    }

    // MARK: Candidates List

    private var candidatesList: some View {
        Group {
            if candidates.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        sectionHeader(
                            "BIOMECHANICKÉ ALTERNATIVY",
                            subtitle: "\(candidates.count) cviků"
                        )
                        .padding(.horizontal, 16)

                        ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                            CandidateRow(
                                candidate: candidate,
                                isTop: index == 0,
                                isSelected: selectedCandidate?.id == candidate.id
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCandidate = selectedCandidate?.id == candidate.id
                                        ? nil : candidate
                                }
                            } onConfirm: {
                                confirmSwap(candidate)
                            }
                            .padding(.horizontal, 16)
                            .offset(y: animateIn ? 0 : 30)
                            .opacity(animateIn ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.75)
                                    .delay(Double(index) * 0.06),
                                value: animateIn
                            )
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.2))
            Text("Žádné alternativy")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text("Zkus jiný filtr nebo rozšiř vybavení.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .kerning(1.2)
            Spacer()
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.25))
        }
    }

    // MARK: Logic

    private func togglePreset(_ preset: QuickFilterPreset) {
        withAnimation(.spring(response: 0.3)) {
            if activePresets.contains(preset) {
                activePresets.remove(preset)
                if preset == .thirtyMinutes {
                    showTimeOptBanner = false
                }
            } else {
                // fullGym clears others; others clear fullGym
                if preset == .fullGym {
                    activePresets = [.fullGym]
                } else {
                    activePresets.remove(.fullGym)
                    activePresets.insert(preset)
                }
                if preset == .thirtyMinutes {
                    computeTimeOpt()
                }
            }
        }
    }

    private func recompute() {
        guard let original else { candidates = []; return }

        var pool = allExercises
        // Apply search
        if !searchText.isEmpty {
            pool = pool.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.nameEN.localizedCaseInsensitiveContains(searchText)
            }
        }

        candidates = SmartSwapEngine.candidates(
            for: original,
            from: pool,
            activePresets: activePresets,
            thirtyMinuteMode: thirtyMinuteMode
        )
    }

    private func computeTimeOpt() {
        let plan = TimeOptimizer.optimize(exercises: plannedExercises, targetMinutes: 30)
        timeOptPlan = plan
        withAnimation(.spring(response: 0.4)) {
            showTimeOptBanner = true
        }
    }

    private func confirmSwap(_ candidate: SwapCandidate) {
        let reason = selectedReason?.rawValue ?? "Uživatelská volba"
        onSwap(candidate.exercise, reason)
        dismiss()
    }
}

// MARK: - PresetChip

private struct PresetChip: View {
    let preset: QuickFilterPreset
    let isActive: Bool
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(preset.rawValue)
                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? .black : .white.opacity(0.75))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isActive ? preset.color : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(isActive ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                )
                .scaleEffect(pressed ? 0.94 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: isActive)
        ._onButtonGesture(pressing: { pressing in
            withAnimation(.spring(response: 0.15)) { pressed = pressing }
        }, perform: {})
    }
}

// MARK: - ReasonChip

private struct ReasonChip: View {
    let reason: SwapReason
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: reason.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.45))
                Text(reason.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.3) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

extension SwapReason: CaseIterable {}

// MARK: - CandidateRow

private struct CandidateRow: View {
    let candidate: SwapCandidate
    let isTop: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            mainRow
                .padding(14)
            
            if isSelected {
                expandedDetail
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isTop
                    ? Color.white.opacity(isSelected ? 0.1 : 0.07)
                    : Color.white.opacity(isSelected ? 0.08 : 0.05)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isTop ? Color.green.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { onTap() }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelected)
    }
    
    private var mainRow: some View {
        HStack(spacing: 14) {
            // Score ring
            ScoreRing(score: candidate.score, isTop: isTop)
                .frame(width: 48, height: 48)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(candidate.exercise.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    if isTop {
                        Text("DOPORUČENO")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green))
                    }
                }

                // Tags
                HStack(spacing: 6) {
                    ForEach(candidate.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                }

                // Equipment icons
                HStack(spacing: 4) {
                    ForEach(Array(candidate.exercise.equipment.prefix(3)), id: \.self) { equip in
                        Text(equip.emoji)
                            .font(.system(size: 12))
                    }
                    Text(candidate.exercise.category.displayName)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            Spacer()

            Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
    
    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().background(Color.white.opacity(0.08))

            // Muscles
            HStack(alignment: .top, spacing: 20) {
                MuscleColumn(
                    title: "Primární",
                    muscles: candidate.exercise.musclesTarget,
                    color: .blue
                )
                MuscleColumn(
                    title: "Sekundární",
                    muscles: candidate.exercise.musclesSecondary,
                    color: Color.white.opacity(0.35)
                )
                Spacer()
            }
            .padding(.horizontal, 14)

            // Instructions preview
            if !candidate.exercise.instructions.isEmpty {
                Text(candidate.exercise.instructions)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(3)
                    .padding(.horizontal, 14)
            }

            // Confirm button
            Button(action: onConfirm) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Nahradit \(candidate.exercise.name)")
                        .fontWeight(.bold)
                }
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Score Ring

private struct ScoreRing: View {
    let score: Int
    let isTop: Bool

    private var color: Color {
        if score >= 75 { return .green }
        if score >= 50 { return .blue }
        return Color.white.opacity(0.4)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7), value: score)
            Text("\(score)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Muscle Column

private struct MuscleColumn: View {
    let title: String
    let muscles: [MuscleGroup]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
                .kerning(0.8)
            ForEach(muscles, id: \.rawValue) { muscle in
                HStack(spacing: 4) {
                    Circle().fill(color).frame(width: 5, height: 5)
                    Text(muscle.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }
}

// MARK: - Extensions

// Equipment emoji helper — nyní v Data/Models/Exercise.swift nebo podobně

extension ExerciseCategory {
    var displayName: String {
        switch self {
        case .chest:     return "Hrudník"
        case .back:      return "Záda"
        case .legs:      return "Nohy"
        case .shoulders: return "Ramena"
        case .arms:      return "Paže"
        case .core:      return "Core"
        case .cardio:    return "Cardio"
        case .olympic:   return "Olymp."
        }
    }
}

extension MuscleGroup {
    var displayName: String {
        switch self {
        case .pecs:           return "Prsní svaly"
        case .lats:           return "Latissimus"
        case .traps:          return "Trapézy"
        case .delts:          return "Deltoid"
        case .biceps:         return "Biceps"
        case .triceps:        return "Triceps"
        case .quads:          return "Quadriceps"
        case .hamstrings:     return "Hamstringy"
        case .glutes:         return "Hýžďové"
        case .calves:         return "Lýtka"
        case .abs:            return "Břišní svaly"
        case .obliques:       return "Boky"
        case .spinalErectors: return "Vzpřimovače"
        case .forearms:       return "Předloktí"
        }
    }
}

// Equipment enum je nyní v Data/Models/Exercise.swift

// MARK: - Preview

#Preview {
    let bench = Exercise(
        slug: "barbell-bench-press",
        name: "Bench Press (činka)",
        nameEN: "Barbell Bench Press",
        category: .chest,
        movementPattern: .push,
        equipment: [.barbell],
        musclesTarget: [.pecs],
        musclesSecondary: [.triceps, .delts],
        instructions: "Lehni si na lavičku, spusť čínku na hrudník a zatlač zpět."
    )

    let alternatives = [
        Exercise(
            slug: "dumbbell-press",
            name: "Tlaky s jednoručkami",
            nameEN: "Dumbbell Bench Press",
            category: .chest,
            movementPattern: .push,
            equipment: [.dumbbell],
            musclesTarget: [.pecs],
            musclesSecondary: [.triceps, .delts],
            instructions: "Větší rozsah pohybu než s osou."
        ),
        Exercise(
            slug: "cable-crossover",
            name: "Překřížení na kabeláku",
            nameEN: "Cable Crossover",
            category: .chest,
            movementPattern: .isolation,
            equipment: [.cable],
            musclesTarget: [.pecs],
            musclesSecondary: [],
            instructions: "Konstantní napětí v celém rozsahu."
        ),
        Exercise(
            slug: "pushup",
            name: "Kliky",
            nameEN: "Push-up",
            category: .chest,
            movementPattern: .push,
            equipment: [.bodyweight],
            musclesTarget: [.pecs],
            musclesSecondary: [.triceps, .delts],
            instructions: "Základní pohyb, vždy dostupný."
        )
    ]

    let session = SessionExercise(order: 1, exercise: bench, session: nil)

    SwapExerciseSheet(
        sessionExercise: session,
        allExercises: [bench] + alternatives,
        plannedExercises: [],
        onSwap: { ex, reason in print("Swap: \(ex.name), reason: \(reason)") },
        onApplyTimeOptimization: { _ in print("Time opt applied") }
    )
}
