// ActiveSessionViewModel.swift
// Agilní Fitness Trenér — Bezpečný concurrency vzor pro aktivní trénink
//
// ✅ @MainActor na třídě: VŠECHNY @Published updates probíhají na hlavním vlákně
// ✅ [weak self] pattern v Task closures: prevence retain cycles a memory leaků
// ✅ Task cancellation: správné zrušení tasks při deinit / view disappear
// ✅ Async AI volání bez blokování UI threadu
// ✅ Timer invalidation v deinit (prevence timer memory leaků)
//
// ─── ARCHITEKTONICKÉ POZNÁMKY PRO TUTO TŘÍDU ────────────────────────────────
//
// PROBLÉM: WorkoutViewModel je @MainActor, ale volá async operace (AI, HealthKit).
// Naivní implementace způsobuje:
//   1. UI freeze pokud async kód běží na main thread synchronně
//   2. Data races pokud async kód aktualizuje @Published z background threadu
//   3. Memory leaky pokud Task closure silně drží `self`
//
// ŘEŠENÍ (implementováno níže):
//   • @MainActor na třídě: SwiftUI @Published properties jsou automaticky
//     čteny/zapisovány z main threadu. Async funkce se suspendují, ale
//     nepouštějí jiná vlákna — jsou non-blocking.
//   • Task { [weak self] in ... }: zabraňuje retain cycle. Self je nil
//     pokud byl ViewModel dealokován (např. uživatel opustil trénink).
//   • Detached tasks pro heavy CPU práci (progress výpočty, HealthKit zápis).

import SwiftUI
import SwiftData

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ActiveSessionViewModel
// MARK: ═══════════════════════════════════════════════════════════════════════

@MainActor
final class ActiveSessionViewModel: ObservableObject {

    // MARK: - @Published state (vždy aktualizováno na @MainActor = main thread)

    @Published var exercises:             [SessionExerciseState] = []
    @Published var currentExerciseIndex:  Int = 0
    @Published var isResting:             Bool = false
    @Published var restSecondsRemaining:  Int = 0
    @Published var totalRestSeconds:      Int = 90
    @Published var elapsedSeconds:        Int = 0
    @Published var audioEnabled:          Bool = false

    // AI Coach state
    @Published var isLoadingCoachTip:     Bool = false
    @Published var coachMessage:          String?
    @Published var isFinishing:           Bool = false
    @Published var hkWriteResult:         WorkoutWriteResult?

    // MARK: - Sledování aktivních Tasks (pro správné zrušení)
    //
    // ⚠️ DŮLEŽITÉ: Ukládáme reference na Tasks abychom je mohli zrušit.
    // Bez zrušení by Task pokračoval i po dealokaci ViewModelu → memory leak.

    private var coachTipTask:   Task<Void, Never>?
    private var finishTask:     Task<Void, Never>?

    // MARK: - Timers (musí být invalidovány v deinit)
    //
    // ⚠️ Timer.scheduledTimer s [weak self] v closure:
    //   - Timer drží silnou referenci na svůj target/closure
    //   - Bez invalidate() v deinit: Timer žije věčně → ViewModel nikdy neuvolněn

    private var restTask:       Task<Void, Never>?
    private var elapsedTask:    Task<Void, Never>?

    // MARK: - Dependencies
    let session:   WorkoutSession
    let planLabel: String
    private let bodyWeightKg: Double          // Váha uživatele pro kalkulaci kalorií v HealthKit
    private weak var appEnv: AppEnvironment?  // ⚠️ weak: zabraňuje retain cycle ViewModel ↔ AppEnvironment
    private var audioCoach: AudioCoachService?

    // MARK: - Init

    init(
        session:   WorkoutSession,
        plan:      PlannedWorkoutDay,
        planLabel: String,
        aiResponse: TrainerResponse? = nil,
        appEnv:    AppEnvironment? = nil,
        bodyWeightKg: Double = 75.0
    ) {
        self.session      = session
        self.planLabel    = planLabel
        self.appEnv       = appEnv
        self.bodyWeightKg = bodyWeightKg

        buildExerciseStates(from: plan, aiResponse: aiResponse)
        startElapsedTimer()
        audioCoach = AudioCoachService()

        // ✅ FIX Bug #1: Dohledat chybějící videoURL přímo ze Supabase
        Task { [weak self] in await self?.enrichWithVideoURLs() }
    }

    // MARK: - deinit: KRITICKY DŮLEŽITÉ pro prevenci memory leaků

    deinit {
        // ⚠️ VŽDY invaliduj timery v deinit.
        // Pokud to uděláš v .onDisappear, riziko race condition (view může zmizet async).
        restTask?.cancel()
        elapsedTask?.cancel()

        // Zruš běžící Tasks — jinak poběží i po dealokaci
        coachTipTask?.cancel()
        finishTask?.cancel()

        // ✅ FIX: deinit nemůže použít @MainActor ani Task — AppLogger je nonisolated OK
        AppLogger.info("[ActiveSessionViewModel] deinit — vše vyčištěno.")
    }

    // MARK: ═══════════════════════════════════════════════════════════════════
    // MARK: VZOR A: Async Task s [weak self] — AI Coach Tip
    // MARK: ═══════════════════════════════════════════════════════════════════
    //
    // Volá se při přechodu na nový cvik. Nesmí blokovat UI.
    //
    // PROČ [weak self]:
    //   Pokud uživatel opustí trénink (view dismissed) dříve než API odpoví,
    //   ViewModel je dealokován. Bez [weak self] by Task stále držel silnou referenci
    //   → ViewModel by žil dalších 30s (po dobu timeoutu API) → memory leak.
    //
    // PROČ guard let self else { return }:
    //   Pokud je self nil (ViewModel dealokován), Task nemá smysl dokončit.
    //   Bez tohoto guardu by kód mohl crashnout při přístupu na dealokovaný objekt.

    func loadCoachTipForCurrentExercise(aiService: AITrainerService) {
        // AI API VOLÁNÍ DEAKTIVOVÁNO PRO ÚSPORU. Proaktivní tipy vypnuty.
        coachTipTask?.cancel()
        coachMessage = "Soustřeď se na techniku a dýchání. 💪"
    }

    // MARK: - Video URL Enrichment (Bug #1 Fix)

    /// ✅ FIX: Hledání primárně přes nameEN (anglický název) — MuscleWiki DB je v angličtině.
    private func enrichWithVideoURLs() async {
        guard exercises.contains(where: { $0.videoUrl == nil }) else { return }
        do {
            let repo = SupabaseExerciseRepository()
            let wikiAll = try await repo.fetchMuscleWikiAll()
            let bgContext = ModelContext(SharedModelContainer.container)

            for i in exercises.indices {
                guard exercises[i].videoUrl == nil else { continue }

                let nameEN  = exercises[i].exercise?.nameEN ?? ""
                let slug    = exercises[i].exercise?.slug ?? exercises[i].slug
                let nameCZ  = exercises[i].name

                func clean(_ s: String) -> String {
                    s.lowercased().folding(options: .diacriticInsensitive, locale: .current)
                }
                let enClean   = clean(nameEN).replacingOccurrences(of: " ", with: "")
                let slugClean = clean(slug).replacingOccurrences(of: "-", with: "")
                let czClean   = clean(nameCZ).replacingOccurrences(of: " ", with: "")

                let match = wikiAll.first(where: { wiki in
                    let wikiClean = clean(wiki.name).replacingOccurrences(of: " ", with: "")
                    if !enClean.isEmpty && (wikiClean == enClean || wikiClean == slugClean) { return true }
                    if wikiClean == slugClean { return true }
                    if enClean.count >= 4 && (wikiClean.contains(enClean) || enClean.contains(wikiClean)) { return true }
                    if slugClean.count >= 4 && (wikiClean.contains(slugClean) || slugClean.contains(wikiClean)) { return true }
                    if nameEN.isEmpty && czClean.count >= 5 && wikiClean.count >= 5 &&
                       (wikiClean.contains(czClean) || czClean.contains(wikiClean)) { return true }
                    return false
                })

                if let match {
                    exercises[i].videoUrl = match.videoUrl
                    if exercises[i].nameEN.isEmpty { exercises[i].nameEN = match.name }  // ✅ doplnit EN název
                    AppLogger.info("✅ [ActiveSession.enrichVideo] \(exercises[i].name) (EN: \(nameEN)) → \(match.name)")
                    if let ex = exercises[i].exercise {
                        let exSlug = ex.slug
                        if let localEx = try? bgContext.fetch(
                            FetchDescriptor<Exercise>(predicate: #Predicate { $0.slug == exSlug })
                        ).first, localEx.videoURL != match.videoUrl {
                            localEx.videoURL = match.videoUrl
                            try? bgContext.save()
                        }
                    }
                } else {
                    AppLogger.error("❌ [ActiveSession.enrichVideo] Nenalezeno: \(exercises[i].name) (EN:\(nameEN), slug:\(slug))")
                }

                if exercises[i].coachTip == nil,
                   let instructions = exercises[i].exercise?.instructions,
                   !instructions.isEmpty {
                    exercises[i].coachTip = instructions
                }
            }
        } catch {
            AppLogger.error("ActiveSessionViewModel.enrichWithVideoURLs: \(error)")
        }
    }

    // MARK: ═══════════════════════════════════════════════════════════════════
    // MARK: VZOR B: Task.detached pro CPU-heavy práci mimo main thread
    // MARK: ═══════════════════════════════════════════════════════════════════
    //
    // finishWorkout() dělá těžkou práci (HealthKit zápis, SwiftData save).
    // Provádíme ji na background threadu, výsledky posíláme zpět na MainActor.
    //
    // PROČ Task.detached místo Task:
    //   Task { } zdědí actor kontext (MainActor) — těžká práce by blokovala UI.
    //   Task.detached { } běží bez inherited actor → volné pro background thread.
    //
    // ⚠️ POZOR: V Task.detached NELZE přímo číst @MainActor properties!
    //   Musíš je předat jako konstanty před spuštěním tasku, nebo použít
    //   await MainActor.run { } pro přístup k nim.

    func finishWorkout(modelContext: ModelContext) {
        guard !isFinishing else { return }
        isFinishing = true

        // Předáme data jako lokální kopie PŘED vstupem do detached tasku
        // ⚠️ Nelze přistupovat k self.session přímo z detached task bez MainActor
        let sessionCopy = self.session
        let exercisesCopy = self.exercises

        finishTask = Task { [weak self] in
            guard let self else { return }

            // Výpočet statistik (CPU práce) — může být na libovolném threadu
            let completedExercises = exercisesCopy.filter { ex in
                ex.sets.contains(where: \.isCompleted)
            }

            // Zápis do HealthKit (async I/O)
            let hkResult = await self.writeToHealthKit(session: sessionCopy)

            // Gamifikace a PR Detection
            let prEvents = self.detectPersonalRecords(exercises: exercisesCopy)
            let gamificationInput = self.buildGamificationInput(from: exercisesCopy, prEvents: prEvents)
            // ✅ FIX #9: GamificationEngine je @MainActor třída — nelze ji instancovat
            // mimo MainActor. Přesunuto dovnitř MainActor.run { }.
            
            await MainActor.run { [weak self] in
                guard let self else { return }
                let engine = GamificationEngine()
                engine.loadRecords(from: modelContext)
                let gains = engine.process(input: gamificationInput, context: modelContext)
                
                if gains.contains(where: { $0.didLevelUp }) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                
                self.saveSessionToSwiftData(session: sessionCopy, context: modelContext, exercises: exercisesCopy)
                self.hkWriteResult = hkResult
                self.isFinishing   = false
                AppLogger.info("[ActiveSession] Trénink dokončen: \(completedExercises.count) cviků. Uloženo do SwiftData.")
            }
        }
    }

    // MARK: ═══════════════════════════════════════════════════════════════════
    // MARK: VZOR C: Timer s [weak self] — elapsed time tracking
    // MARK: ═══════════════════════════════════════════════════════════════════
    //
    // ⚠️ Timer.scheduledTimer drží silnou referenci na closure.
    // Bez [weak self] v closure: ViewModel → Timer closure → ViewModel = retain cycle.

    private func startElapsedTimer() {
        elapsedTask?.cancel()

        elapsedTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self = self else { break }
                self.elapsedSeconds += 1
            }
        }
    }

    func startRestTimer(seconds: Int) {
        restTask?.cancel()
        guard seconds > 0 else { return }
        
        restSecondsRemaining = seconds
        totalRestSeconds     = seconds
        isResting            = true

        if audioEnabled {
            audioCoach?.speak(.restStarted(seconds))
        }

        restTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self = self else { break }
                
                if self.restSecondsRemaining > 1 {
                    self.restSecondsRemaining -= 1
                    
                    if self.restSecondsRemaining == 10 && self.audioEnabled {
                        self.audioCoach?.speak(.restWarning(10))
                    }
                } else {
                    self.restSecondsRemaining -= 1
                    self.restTask = nil
                    self.isResting = false
                    HapticManager.shared.playSuccess()
                    if self.audioEnabled { self.audioCoach?.speak(.restEnd) }
                    break
                }
            }
        }
    }

    // MARK: ═══════════════════════════════════════════════════════════════════
    // MARK: VZOR D: Sdílení dat mezi Tasks pomocí AsyncStream
    // MARK: ═══════════════════════════════════════════════════════════════════
    //
    // Pokud potřebuješ real-time updates z background tasku do UI,
    // použij AsyncStream místo callbacks (bezpečnější pro concurrency).

    func streamProgressUpdates() -> AsyncStream<Double> {
        AsyncStream { continuation in
            Task.detached { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                for _ in 0..<10 {
                    guard !Task.isCancelled else {
                        continuation.finish()
                        return
                    }

                    let progress = await MainActor.run { [weak self] in
                        self?.completionProgress ?? 0
                    }

                    continuation.yield(progress)
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Public Actions

    func completeSet(exerciseIndex: Int, setIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex)
        else { return }

        exercises[exerciseIndex].sets[setIndex].isCompleted = true
        
        stopTempo()

        if audioEnabled {
            let exercise = exercises[exerciseIndex]
            let setNum = setIndex + 1
            let totalSets = exercise.sets.filter { !$0.isWarmup }.count
            audioCoach?.speak(.setStarting(setNum, totalSets))
        }

        let restSeconds = exercises[exerciseIndex].restSeconds
        if restSeconds > 0 {
            startRestTimer(seconds: restSeconds)
        }

        HapticManager.shared.playMediumClick()
    }

    func skipRest() {
        restTask?.cancel()
        restTask = nil
        isResting = false
        HapticManager.shared.playSelection()
    }

    func adjustRest(by delta: Int) {
        let updated = max(0, restSecondsRemaining + delta)
        restSecondsRemaining = updated
        totalRestSeconds     = max(totalRestSeconds, restSecondsRemaining)
        // Pokud se pauza vyčerpala, přeskočíme ji
        if updated == 0 { skipRest(); return }
        // Synchronizuj Live Activity s novou délkou pauzy
        let newEndsAt = Date.now.addingTimeInterval(Double(updated))
        Task {
            await LiveActivityManager.shared.updateRestTimer(
                newEndsAt: newEndsAt,
                totalSeconds: updated
            )
        }
    }

    @Published var allExercisesDone = false

    func skipExercise() {
        guard currentExerciseIndex < exercises.count - 1 else {
            withAnimation { allExercisesDone = true }
            if audioEnabled { audioCoach?.speak(.sessionEnd) }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        currentExerciseIndex += 1
        HapticManager.shared.playSelection()
        
        if audioEnabled {
            let next = exercises[currentExerciseIndex]
            let workingSets = next.sets.filter { !$0.isWarmup }.count
            audioCoach?.speak(.setStarting(1, workingSets))
        }
    }

    func swapExercise(at index: Int, newName: String, newSlug: String) {
        guard exercises.indices.contains(index) else { return }
        exercises[index].name = newName
        exercises[index].slug = newSlug
        HapticManager.shared.playMediumClick()
    }
    
    // MARK: - Tempo Controls
    
    func startTempoForCurrentExercise() {
        guard audioEnabled else { return }
        let ex = exercises[currentExerciseIndex]
        let reps = ex.sets.first?.targetRepsMax ?? 10
        audioCoach?.startTempo(tempoString: ex.tempo, reps: reps)
    }
    
    func stopTempo() {
        audioCoach?.stopTempo()
    }

    func toggleAudio() {
        audioEnabled.toggle()
        if audioEnabled {
            audioCoach?.speak(.sessionStart)
        }
    }

    // MARK: - Computed Properties

    var elapsedTimeFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var restTimeFormatted: String {
        let m = restSecondsRemaining / 60
        let s = restSecondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var restProgress: Double {
        guard totalRestSeconds > 0 else { return 0 }
        return Double(restSecondsRemaining) / Double(totalRestSeconds)
    }

    var completionProgress: Double {
        let totalSets     = exercises.flatMap(\.sets).count
        let completedSets = exercises.flatMap(\.sets).filter(\.isCompleted).count
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
    }

    // MARK: - Private Helpers

    private func writeToHealthKit(session: WorkoutSession) async -> WorkoutWriteResult {
        let writer = HealthKitWorkoutWriter()
        let result = await writer.write(session: session, bodyWeightKg: bodyWeightKg)
        if result.success {
            return .success
        } else {
            let errorMsg = result.error?.localizedDescription ?? "Neznámá chyba zápisu"
            AppLogger.error("[ActiveSession] HealthKit zápis selhal: \(errorMsg)")
            return .failed(errorMsg)
        }
    }

    private func saveSessionToSwiftData(session: WorkoutSession, context: ModelContext, exercises: [SessionExerciseState]) {
        session.finishedAt = .now
        session.durationMinutes = elapsedSeconds / 60
        session.status = .completed

        // Ulož WeightEntry pro progressive overload
        for ex in exercises {
            guard !ex.isWarmupOnly, let exerciseDB = ex.exercise else { continue }
            let workingSets = ex.sets.filter { $0.isCompleted && !$0.isWarmup }
            for (setIdx, set) in workingSets.enumerated() {
                let weight = set.weightKg ?? 0
                guard let reps = set.reps, reps > 0 else { continue }
                let isSuccess = (set.rpe ?? 5) <= 9 // RPE 10 znamená selhání
                let entry = WeightEntry(
                    exercise: exerciseDB,
                    sessionId: session.id,
                    weightKg: weight,
                    reps: reps,
                    rpe: set.rpe,
                    wasSuccessful: isSuccess,
                    setNumber: setIdx + 1
                )
                context.insert(entry)
            }
        }

        do {
            try context.save()
            AppLogger.info("[ActiveSession] Session uložena do SwiftData s WeightEntry záznamy.")
        } catch {
            AppLogger.error("[ActiveSession] Chyba při ukládání session: \(error)")
            appEnv?.showError(message: "Trénink se nepodařilo uložit. Zkus to znovu.")
        }
    }

    private func detectPersonalRecords(exercises: [SessionExerciseState]) -> [PREvent] {
        var prs: [PREvent] = []
        for ex in exercises {
            guard let exercise = ex.exercise else { continue }
            let maxWeight = ex.sets.filter { $0.isCompleted && !$0.isWarmup }
                .compactMap { $0.weightKg }.max() ?? 0
            let prev = exercise.lastUsedWeight ?? 0
            if maxWeight > prev && prev > 0 {
                prs.append(PREvent(
                    exerciseName: ex.name,
                    muscleGroup: exercise.musclesTarget.first ?? .chest,
                    oldValue: prev,
                    newValue: maxWeight,
                    type: .weight
                ))
            }
        }
        return prs
    }

    private func buildGamificationInput(from states: [SessionExerciseState], prEvents: [PREvent] = []) -> SessionGamificationInput {
        let exerciseResults: [SessionGamificationInput.ExerciseResult] = states.compactMap { state in
            guard !state.isWarmupOnly else { return nil }
            let completed = state.sets.filter { $0.isCompleted }
            guard !completed.isEmpty else { return nil }

            let primary = state.exercise?.musclesTarget ?? [.chest]
            let secondary = state.exercise?.musclesSecondary ?? []

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
        return SessionGamificationInput(exercises: exerciseResults, personalRecords: prEvents)
    }

    private func buildExerciseStates(from plan: PlannedWorkoutDay, aiResponse: TrainerResponse?) {
        var states: [SessionExerciseState] = []

        if let response = aiResponse, !response.mainBlocks.isEmpty {
            // Warmup
            for wu in response.warmUp {
                states.append(SessionExerciseState.warmupExercise(wu))
            }

            // ✅ Načteme VŠECHNY cviky z DB pro spolehlivé napárování
            let allDBExercises: [Exercise] = (try? SharedModelContainer.container.mainContext.fetch(FetchDescriptor<Exercise>())) ?? []

            // Main blocks — napáruj Exercise DB referenci a progressive overload
            let allPlanned = plan.plannedExercises
            var isFirstWorkingExercise = true

            for block in response.mainBlocks {
                for ex in block.exercises {
                    var state = SessionExerciseState(from: ex)

                    // ✅ Hledej v planned i v celé DB
                    let normalizedSlug = FallbackWorkoutGenerator.normalizedSlug(ex.slug)
                    var matchedExercise: Exercise? = allPlanned.first(where: {
                        let dbSlug = $0.exercise?.slug ?? ""
                        return dbSlug == normalizedSlug || dbSlug == ex.slug
                    })?.exercise

                    // Fallback: hledej v celé DB podle slug nebo jména
                    if matchedExercise == nil {
                        matchedExercise = allDBExercises.first(where: {
                            $0.slug == normalizedSlug || $0.slug == ex.slug
                                || $0.nameEN.lowercased() == ex.name.lowercased()
                                || $0.name.lowercased() == ex.name.lowercased()
                        })
                    }

                    if let exercise = matchedExercise {
                        state.exercise = exercise
                        state.nameEN = exercise.nameEN  // ✅ Anglický název pro video lookup

                        // Video URL z DB
                        if let videoURL = exercise.videoURL {
                            state.videoUrl = videoURL
                        }

                        // Progressive overload — výpočet doporučené váhy
                        let history = exercise.weightHistory
                            .sorted { $0.loggedAt > $1.loggedAt }
                            .prefix(12)
                        let completedSets = history.map {
                            // ✅ FIX: Používáme SetSnapshot (ValueType) místo @Model CompletedSet
                            SetSnapshot(from: $0)
                        }

                        if let suggestion = ProgressionEngine.calculateNextTarget(
                            previousSets: Array(completedSets),
                            programRepsMin: ex.repsMin,
                            programRepsMax: ex.repsMax
                        ) {
                            for j in 0..<state.sets.count {
                                state.sets[j].previousWeightKg = suggestion.weight
                            }
                        }

                        // Warmup série pro první pracovní cvik
                        if isFirstWorkingExercise {
                            isFirstWorkingExercise = false
                            let targetWeight = state.sets.first?.previousWeightKg
                                ?? exercise.lastUsedWeight
                                ?? ex.weightKg ?? 0
                            let warmups = WarmupCalculator.generateWarmups(
                                targetWeight: targetWeight,
                                targetRepsMin: ex.repsMin
                            )
                            state.sets.insert(contentsOf: warmups, at: 0)
                        }
                    }

                    states.append(state)
                }
            }
        } else {
            // Fallback — PlannedExercises z DB
            // SessionExerciseState(from: planned) již načítá lastUsedWeight jako previousWeightKg
            for (index, plannedEx) in plan.plannedExercises.sorted(by: { $0.order < $1.order }).enumerated() {
                var state = SessionExerciseState(from: plannedEx)

                // Progressive overload — přepočítej pokud máme historii (přesnější než lastUsedWeight)
                if let exercise = plannedEx.exercise, !exercise.weightHistory.isEmpty {
                    let history = exercise.weightHistory
                        .sorted { $0.loggedAt > $1.loggedAt }
                        .prefix(12)
                    let completedSets = history.map {
                        // ✅ FIX: Používáme SetSnapshot (ValueType) místo @Model CompletedSet
                        SetSnapshot(from: $0)
                    }
                    if let suggestion = ProgressionEngine.calculateNextTarget(
                        previousSets: Array(completedSets),
                        programRepsMin: plannedEx.targetRepsMin,
                        programRepsMax: plannedEx.targetRepsMax
                    ) {
                        for j in 0..<state.sets.count {
                            state.sets[j].previousWeightKg = suggestion.weight
                        }
                    }

                    // Warmup pro první cvik
                    if index == 0 {
                        let targetWeight = state.sets.first?.previousWeightKg
                            ?? exercise.lastUsedWeight ?? 0
                        let warmups = WarmupCalculator.generateWarmups(
                            targetWeight: targetWeight,
                            targetRepsMin: plannedEx.targetRepsMin
                        )
                        state.sets.insert(contentsOf: warmups, at: 0)
                    }
                }

                states.append(state)
            }
        }

        self.exercises = states
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: WorkoutWriteResult
// MARK: ═══════════════════════════════════════════════════════════════════════

enum WorkoutWriteResult: Equatable {
    case success
    case failed(String)
    case notAttempted
}


