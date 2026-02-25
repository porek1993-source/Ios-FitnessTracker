// WorkoutViewModel.swift
// OPRAVENO: AI response integrace, RPE v progressive overload, audio coach, finishWorkout s DB save

import SwiftUI
import SwiftData

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published var exercises: [SessionExerciseState]
    @Published var currentExerciseIndex = 0
    @Published var isResting = false
    @Published var restSecondsRemaining = 0
    @Published var totalRestSeconds = 90
    @Published var elapsedSeconds = 0
    @Published var audioEnabled = false

    private var restTimer: Timer?
    private var elapsedTimer: Timer?
    private var audioCoach: AudioCoachService?

    let session: WorkoutSession
    let planLabel: String

    init(session: WorkoutSession, plan: PlannedWorkoutDay, planLabel: String, aiResponse: TrainerResponse? = nil) {
        self.session   = session
        self.planLabel = planLabel

        // Priorita: AI response > PlannedExercises z databáze
        if let response = aiResponse, !response.mainBlocks.isEmpty {
            // AI vygenerovala konkrétní cviky
            var states: [SessionExerciseState] = []

            // Warmup
            for wu in response.warmUp {
                states.append(SessionExerciseState.warmupExercise(wu))
            }

            // Main exercises - flatten mainBlocks
            for block in response.mainBlocks {
                for (index, ex) in block.exercises.enumerated() {
                    var state = SessionExerciseState(from: ex)

                    // Progressive overload: načti historii z PlannedExercises
                    if let plannedEx = plan.plannedExercises.first(where: {
                        $0.exercise?.slug == ex.slug || $0.exercise?.nameEN.lowercased() == ex.slug.lowercased()
                    }) {
                        if let exercise = plannedEx.exercise {
                            // Použij RPE z minulé session pro rozhodnutí o váze
                            let suggestion = rpeAwareProgression(exercise: exercise, targetWeight: ex.weightKg)
                            for j in 0..<state.sets.count {
                                state.sets[j].previousWeightKg = suggestion
                            }
                        }
                    }

                    // Warmup pouze pro první cvik v celém tréninku
                    if states.isEmpty && index == 0, let targetWeight = state.sets.first?.previousWeightKg ?? ex.weightKg {
                        let warmups = WarmupCalculator.generateWarmups(
                            targetWeight: targetWeight,
                            targetRepsMin: ex.repsMin
                        )
                        state.sets.insert(contentsOf: warmups, at: 0)
                    }

                    states.append(state)
                }
            }

            self.exercises = states
        } else {
            // Fallback na PlannedExercises z databáze
            let sortedPlanned = plan.plannedExercises.sorted { $0.order < $1.order }
            var states: [SessionExerciseState] = []

            for (index, planned) in sortedPlanned.enumerated() {
                var state = SessionExerciseState(from: planned)

                // Progressive overload s RPE
                if let exercise = planned.exercise {
                    let suggestion = rpeAwareProgression(exercise: exercise, targetWeight: exercise.lastUsedWeight)
                    for j in 0..<state.sets.count {
                        state.sets[j].previousWeightKg = suggestion
                    }

                    // Warmup pro první cvik
                    if index == 0, let targetWeight = suggestion ?? exercise.lastUsedWeight {
                        let warmups = WarmupCalculator.generateWarmups(
                            targetWeight: targetWeight,
                            targetRepsMin: planned.targetRepsMin
                        )
                        state.sets.insert(contentsOf: warmups, at: 0)
                    }
                }

                states.append(state)
            }

            self.exercises = states
        }

        startElapsedTimer()

        // Init audio coach
        audioCoach = AudioCoachService()
    }

    // MARK: - RPE-aware progression
    // Pokud poslední série měla RPE >= 9, nedáme více váhy
    private func rpeAwareProgression(exercise: Exercise, targetWeight: Double?) -> Double? {
        let recentEntries = exercise.weightHistory
            .sorted { $0.loggedAt > $1.loggedAt }
            .prefix(6)

        // Zkontroluj poslední RPE
        let lastHighRPE = recentEntries.contains { ($0.rpe ?? 0) >= 9.0 }
        let lastFailure = recentEntries.contains { !$0.wasSuccessful }

        guard let lastWeight = recentEntries.first?.weightKg else {
            return targetWeight
        }

        if lastHighRPE || lastFailure {
            // Drž stejnou váhu nebo mírný deload
            return lastFailure ? (lastWeight * 0.95).rounded(toNearest: 2.5) : lastWeight
        }

        // Normální progression (+2.5 nebo +5 kg)
        let isLower = exercise.category == .legs
        let increment: Double = isLower ? 5.0 : 2.5
        let allSuccessful = recentEntries.prefix(3).allSatisfy { $0.wasSuccessful }

        if allSuccessful && recentEntries.count >= 3 {
            return (lastWeight + increment).rounded(toNearest: 2.5)
        }
        return lastWeight
    }

    // MARK: - Timer

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.elapsedSeconds += 1 }
        }
    }

    // MARK: - Set Complete

    func completeSet(exerciseIndex: Int, setIndex: Int) {
        guard
            exercises[exerciseIndex].sets[setIndex].weightKg != nil,
            exercises[exerciseIndex].sets[setIndex].reps != nil
        else { return }

        withAnimation(.spring(response: 0.3)) {
            exercises[exerciseIndex].sets[setIndex].isCompleted = true
        }

        let exercise    = exercises[exerciseIndex]
        let restSeconds = exercise.restSeconds

        // Audio coach — série hotova
        if audioEnabled {
            let setNum = setIndex + 1
            let totalSets = exercise.sets.filter { !$0.isWarmup }.count
            audioCoach?.speak(.setStarting(setNum, totalSets))
        }

        Task {
            await LiveActivityManager.shared.startRestActivity(
                session:           session,
                currentExercise:   exercise,
                completedSetIndex: setIndex,
                restSeconds:       restSeconds,
                planLabel:         planLabel
            )
        }

        startRestTimer(seconds: restSeconds)

        let allDone = exercises[exerciseIndex].sets.allSatisfy(\.isCompleted)
        if allDone {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(restSeconds) + 0.5) { [weak self] in
                self?.advanceToNextExercise()
            }
        }
    }

    private func startRestTimer(seconds: Int) {
        guard seconds > 0 else { return }
        restTimer?.invalidate()
        totalRestSeconds     = seconds
        restSecondsRemaining = seconds
        withAnimation { isResting = true }

        if audioEnabled {
            audioCoach?.speak(.restStarted(seconds))
        }

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.restSecondsRemaining > 1 {
                    self.restSecondsRemaining -= 1
                    // Varování 10 sekund před koncem
                    if self.restSecondsRemaining == 10 && self.audioEnabled {
                        self.audioCoach?.speak(.restWarning(10))
                    }
                } else {
                    if self.audioEnabled { self.audioCoach?.speak(.restEnd) }
                    self.skipRest()
                }
            }
        }
    }

    func skipRest() {
        restTimer?.invalidate()
        withAnimation(.spring(response: 0.35)) { isResting = false }
        Task { await LiveActivityManager.shared.endWithDismissalDelay(2) }
    }

    func adjustRest(by delta: Int) {
        restSecondsRemaining = max(0, restSecondsRemaining + delta)
        if restSecondsRemaining == 0 { skipRest(); return }
        let newEndsAt = Date.now.addingTimeInterval(Double(restSecondsRemaining))
        Task {
            await LiveActivityManager.shared.updateRestTimer(
                newEndsAt: newEndsAt,
                totalSeconds: restSecondsRemaining
            )
        }
    }

    func skipExercise() { withAnimation { advanceToNextExercise() } }

    private func advanceToNextExercise() {
        guard currentExerciseIndex < exercises.count - 1 else { return }
        withAnimation(.easeInOut) { currentExerciseIndex += 1 }

        // Audio coach — příští cvik
        if audioEnabled {
            let next = exercises[min(currentExerciseIndex, exercises.count - 1)]
            audioCoach?.speak(.setStarting(1, next.sets.filter { !$0.isWarmup }.count))
        }
    }

    // MARK: - Audio

    func toggleAudio() {
        audioEnabled.toggle()
        if audioEnabled {
            audioCoach?.speak(.sessionStart)
        }
    }

    // MARK: - Finish — ukládá WeightEntry do SwiftData pro progressive overload

    func finishWorkout(modelContext: ModelContext) {
        restTimer?.invalidate()
        elapsedTimer?.invalidate()
        session.durationMinutes = elapsedSeconds / 60
        session.status = .completed
        session.finishedAt = .now

        // Ulož WeightEntry pro každý dokončený working set (ne warmup)
        for ex in exercises {
            guard !ex.isWarmupOnly else { continue }
            let sessionEx = session.exercises.first { $0.exercise?.slug == ex.slug }
            guard let exercise = sessionEx?.exercise else { continue }

            let workingSets = ex.sets.filter { $0.isCompleted && !$0.isWarmup }
            for set in workingSets {
                guard let weight = set.weightKg, let reps = set.reps else { continue }
                let entry = WeightEntry(
                    exercise: exercise,
                    sessionId: session.id,
                    weightKg: weight,
                    reps: reps,
                    rpe: set.rpe,
                    wasSuccessful: rpe_isSuccessful(set.rpe)
                )
                modelContext.insert(entry)
            }
        }

        try? modelContext.save()
        Task { await LiveActivityManager.shared.endCurrentActivity() }

        // ── Gamifikace: přepočítej XP po dokončení tréninku ──
        let gamificationInput = buildGamificationInput(from: exercises)
        let engine = GamificationEngine()
        engine.loadRecords(from: modelContext)
        let gains = engine.process(input: gamificationInput, context: modelContext)
        if gains.contains(where: { $0.didLevelUp }) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func buildGamificationInput(from states: [SessionExerciseState]) -> SessionGamificationInput {
        let exerciseResults: [SessionGamificationInput.ExerciseResult] = states.compactMap { state in
            guard !state.isWarmupOnly else { return nil }
            let completed = state.sets.filter { $0.isCompleted }
            guard !completed.isEmpty else { return nil }

            // Odvoď svalové skupiny ze slugu/názvu
            let primary = muscleGroupsFromSlug(state.slug, primary: true)
            let secondary = muscleGroupsFromSlug(state.slug, primary: false)

            let setResults: [SessionGamificationInput.SetResult] = completed.map {
                .init(weightKg: $0.weightKg ?? 0, reps: $0.reps ?? 0, isWarmup: $0.isWarmup)
            }
            return SessionGamificationInput.ExerciseResult(
                exerciseName: state.name,
                musclesTarget: primary,
                musclesSecondary: secondary,
                completedSets: setResults
            )
        }
        return SessionGamificationInput(exercises: exerciseResults, personalRecords: [])
    }

    /// Jednoduchá heuristika pro mapování slug → svalové skupiny
    private func muscleGroupsFromSlug(_ slug: String, primary: Bool) -> [MuscleGroup] {
        let s = slug.lowercased()
        if s.contains("bench") || s.contains("chest") || s.contains("fly") || (s.contains("press") && !s.contains("shoulder") && !s.contains("over")) {
            return primary ? [.pecs] : [.triceps, .delts]
        } else if s.contains("row") || s.contains("pulldown") || s.contains("pull") || s.contains("lat") {
            return primary ? [.lats] : [.biceps, .traps]
        } else if s.contains("squat") || s.contains("quad") || s.contains("lunge") || s.contains("leg-press") {
            return primary ? [.quads] : [.glutes, .hamstrings]
        } else if s.contains("deadlift") || s.contains("rdl") || s.contains("hip") || s.contains("hamstring") {
            return primary ? [.hamstrings] : [.glutes, .spinalErectors]
        } else if s.contains("shoulder") || s.contains("lateral") || s.contains("overhead") || s.contains("ohp") {
            return primary ? [.delts] : [.triceps, .traps]
        } else if s.contains("curl") || s.contains("bicep") {
            return primary ? [.biceps] : [.forearms]
        } else if s.contains("tricep") || s.contains("dip") || s.contains("extension") || s.contains("pushdown") {
            return primary ? [.triceps] : []
        } else if s.contains("calf") || s.contains("raise") {
            return primary ? [.calves] : []
        } else if s.contains("ab") || s.contains("core") || s.contains("plank") || s.contains("crunch") {
            return primary ? [.abs] : [.obliques]
        } else if s.contains("glute") || s.contains("bridge") {
            return primary ? [.glutes] : [.hamstrings]
        } else if s.contains("trap") || s.contains("shrug") || s.contains("face-pull") {
            return primary ? [.traps] : [.delts]
        }
        return primary ? [.pecs] : []
    }

    private func rpe_isSuccessful(_ rpe: Int?) -> Bool {
        guard let r = rpe else { return true }
        return r <= 9  // RPE 10 = totální selhání = ne "úspěšné" pro next session
    }

    // MARK: - Computed

    var restProgress: Double {
        guard totalRestSeconds > 0 else { return 0 }
        return Double(restSecondsRemaining) / Double(totalRestSeconds)
    }

    var restTimeFormatted: String {
        let m = restSecondsRemaining / 60
        let s = restSecondsRemaining % 60
        return m > 0 ? "\(m):\(String(format: "%02d", s))" : "\(s)"
    }

    var elapsedTimeFormatted: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

// MARK: - State Models

    var sets: [SetState]
    var isWarmupOnly: Bool

    init(id: UUID = UUID(), name: String, slug: String, coachTip: String? = nil, tempo: String? = nil, restSeconds: Int = 60, sets: [SetState] = [], isWarmupOnly: Bool = false) {
        self.id = id
        self.name = name
        self.slug = slug
        self.coachTip = coachTip
        self.tempo = tempo
        self.restSeconds = restSeconds
        self.sets = sets
        self.isWarmupOnly = isWarmupOnly
    }

    var nextIncompleteSetIndex: Int? {
        sets.indices.first { !sets[$0].isCompleted }
    }

    init(from planned: PlannedExercise) {
        self.id          = UUID()
        self.name        = planned.exercise?.name ?? ""
        self.slug        = planned.exercise?.slug ?? ""
        self.coachTip    = nil
        self.tempo       = nil
        self.restSeconds = planned.restSeconds
        self.sets = (0..<planned.targetSets).map { _ in
            SetState(
                targetRepsMin:    planned.targetRepsMin,
                targetRepsMax:    planned.targetRepsMax,
                previousWeightKg: planned.exercise?.lastUsedWeight
            )
        }
    }

    init(from response: ResponseExercise) {
        self.id          = UUID()
        self.name        = response.name
        self.slug        = response.slug
        self.coachTip    = response.coachTip
        self.tempo       = response.tempo
        self.restSeconds = response.restSeconds
        self.sets = (0..<response.sets).map { _ in
            SetState(
                targetRepsMin:    response.repsMin,
                targetRepsMax:    response.repsMax,
                previousWeightKg: response.weightKg
            )
        }
    }

    static func warmupExercise(_ wu: WarmUpExercise) -> SessionExerciseState {
        let reps = Int(wu.reps.components(separatedBy: CharacterSet.decimalDigits.inverted).first ?? "10") ?? 10
        let sets = (0..<wu.sets).map { _ in
            SetState(targetRepsMin: reps, targetRepsMax: reps, isWarmup: true)
        }
        return SessionExerciseState(
            name: wu.name,
            slug: "warmup-\(wu.name.lowercased())",
            coachTip: wu.notes,
            restSeconds: 60,
            sets: sets,
            isWarmupOnly: true
        )
    }

    static func warmupExercise(_ ex: ResponseExercise) -> SessionExerciseState {
        var state = SessionExerciseState(from: ex)
        state.isWarmupOnly = true
        for i in 0..<state.sets.count {
            state.sets[i].isWarmup = true
        }
        return state
    }
}

struct SetState {
    var weightKg: Double?
    var reps: Int?
    var rpe: Int?
    var isCompleted: Bool
    var isWarmup: Bool
    let targetRepsMin: Int
    let targetRepsMax: Int
    var previousWeightKg: Double?

    init(weightKg: Double? = nil, reps: Int? = nil, rpe: Int? = nil, isCompleted: Bool = false, isWarmup: Bool = false, targetRepsMin: Int, targetRepsMax: Int, previousWeightKg: Double? = nil) {
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.isCompleted = isCompleted
        self.isWarmup = isWarmup
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.previousWeightKg = previousWeightKg
    }
}

// MARK: - Helpers

extension Double {
    func rounded(toNearest: Double) -> Double {
        (self / toNearest).rounded() * toNearest
    }
}
