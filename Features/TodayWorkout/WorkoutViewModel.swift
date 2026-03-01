// WorkoutViewModel.swift
// Agilní Fitness Trenér — ViewModel pro aktivní trénink

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
    @Published var hkWriteResult: HealthKitWriteResult?

    // Timery jsou bezpečně spravovány jako Task (cancelovatelné, bez nonisolated(unsafe))
    private var restTimerTask:    Task<Void, Never>?
    private var elapsedTimerTask: Task<Void, Never>?
    private var advanceTask:      Task<Void, Never>?
    private var audioCoach: AudioCoachService?

    let session: WorkoutSession
    let planLabel: String
    private let bodyWeightKg: Double  // Váha uživatele pro HealthKit kalorie

    deinit {
        restTimerTask?.cancel()
        elapsedTimerTask?.cancel()
        advanceTask?.cancel()
    }

    init(session: WorkoutSession, plan: PlannedWorkoutDay, planLabel: String, aiResponse: TrainerResponse? = nil, bodyWeightKg: Double = 75.0) {
        self.exercises = []
        self.session   = session
        self.planLabel = planLabel
        self.bodyWeightKg = bodyWeightKg

        // Priorita: AI response > PlannedExercises z databáze
        if let response = aiResponse, !response.mainBlocks.isEmpty {
            // AI vygenerovala konkrétní cviky
            var states: [SessionExerciseState] = []

            // ✅ Načteme VŠECHNY cviky z DB pro spolehlivé napárování (slug/name)
            let allDBExercises: [Exercise] = (try? SharedModelContainer.container.mainContext.fetch(FetchDescriptor<Exercise>())) ?? []

            // Warmup
            for wu in response.warmUp {
                states.append(SessionExerciseState.warmupExercise(wu))
            }

            // Main exercises - flatten mainBlocks
            for block in response.mainBlocks {
                for (index, ex) in block.exercises.enumerated() {
                    var state = SessionExerciseState(from: ex)

                    // ✅ Hledáme v celé DB, ne jen v plannedExercises
                    let normalizedSlug = FallbackWorkoutGenerator.normalizedSlug(ex.slug)
                    var exerciseRef: Exercise? = nil

                    // 1. Zkusit najít v plánu (má weight history)
                    if let plannedEx = plan.plannedExercises.first(where: {
                        let dbSlug = $0.exercise?.slug.lowercased() ?? ""
                        let fName = ex.name.lowercased()
                        return dbSlug == normalizedSlug || dbSlug == ex.slug.lowercased()
                            || $0.exercise?.nameEN.lowercased() == fName
                            || $0.exercise?.name.lowercased() == fName
                            || $0.exercise?.nameEN.lowercased().contains(fName) == true
                            || $0.exercise?.name.lowercased().contains(fName) == true
                    }) {
                        exerciseRef = plannedEx.exercise
                    }

                    // 2. Pokud nenalezeno v plánu, hledej v celé DB (fuzzy match)
                    if exerciseRef == nil {
                        let fName = ex.name.lowercased()
                        exerciseRef = allDBExercises.first(where: {
                            $0.slug.lowercased() == normalizedSlug || $0.slug.lowercased() == ex.slug.lowercased()
                                || $0.nameEN.lowercased() == fName
                                || $0.name.lowercased() == fName
                                || $0.name.lowercased().contains(fName)
                                || $0.nameEN.lowercased().contains(fName)
                                || fName.contains($0.name.lowercased())
                        })
                    }

                    if let exercise = exerciseRef {
                        // Použij ProgressionEngine pro výpočet cíle
                        let history = exercise.weightHistory
                            .sorted { $0.loggedAt > $1.loggedAt }
                            .prefix(6)
                            .map { entry in
                                // ✅ FIX: Používáme SetSnapshot (ValueType) místo @Model CompletedSet
                                SetSnapshot(from: entry)
                            }
                        
                        if let suggestion = ProgressionEngine.calculateNextTarget(
                            previousSets: history,
                            programRepsMin: ex.repsMin,
                            programRepsMax: ex.repsMax
                        ) {
                            for j in 0..<state.sets.count {
                                state.sets[j].previousWeightKg = suggestion.weight
                            }
                        }
                    }

                    state.exercise = exerciseRef
                    // ✅ Předej videoURL a nameEN z Exercise DB modelu do session state
                    if let ref = exerciseRef {
                        if let videoURL = ref.videoURL { state.videoUrl = videoURL }
                        state.nameEN = ref.nameEN  // ✅ Anglický název pro ExerciseMediaView lookup
                    }

                    // Warmup pouze pro první working cvik v celém tréninku (ne warmup bloky)
                    if states.filter({ !$0.isWarmupOnly }).isEmpty, index == 0 {
                        let targetWeight = state.sets.first?.previousWeightKg ?? ex.weightKg
                        if let targetWeight {
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

            self.exercises = states
        } else {
            // Fallback na PlannedExercises z databáze
            let sortedPlanned = plan.plannedExercises.sorted { $0.order < $1.order }
            var states: [SessionExerciseState] = []

            for (index, planned) in sortedPlanned.enumerated() {
                var state = SessionExerciseState(from: planned)

                // Progressive overload s ProgressionEngine
                if let exercise = planned.exercise {
                    let history = exercise.weightHistory
                        .sorted { $0.loggedAt > $1.loggedAt }
                        .prefix(6)
                        .map { entry in
                            // ✅ FIX: Používáme SetSnapshot (ValueType) místo @Model CompletedSet
                            SetSnapshot(from: entry)
                        }
                    
                    let suggestion = ProgressionEngine.calculateNextTarget(
                        previousSets: history,
                        programRepsMin: planned.targetRepsMin,
                        programRepsMax: planned.targetRepsMax
                    )
                    
                    if let weight = suggestion?.weight {
                        for j in 0..<state.sets.count {
                            state.sets[j].previousWeightKg = weight
                        }
                    }

                    // Warmup pro první cvik
                    if index == 0, let targetWeight = suggestion?.weight ?? exercise.lastUsedWeight {
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

        // Populate session.exercises so finishWorkout can save WeightEntry records
        // SessionExercise záznamy musí existovat v DB aby se mohly uložit completed sety
        // Note: Toto se spustí v background - modelContext není k dispozici v initu
        // Proto ukládáme přes sessionExerciseCache a přistupujeme z finishWorkout přes state.exercise
        
        startElapsedTimer()

        // Init audio coach
        audioCoach = AudioCoachService()

        // ✅ FIX Bug #1: Dohledat chybějící videoURL a coachTip přímo z Supabase MuscleWiki
        // Spustíme async, nezablokujeme UI — výsledky se propisují do @Published exercises
        Task { await enrichWithVideoURLs() }
    }

    // MARK: - Video URL Enrichment (Bug #1 Fix)

    /// Pro cviky, kde videoUrl nebo coachTip chybí (sync nestihl spárovat), načte data přímo ze Supabase.
    /// ✅ FIX: Hledání primárně přes nameEN (anglický název) — MuscleWiki databáze je v angličtině.
    private func enrichWithVideoURLs() async {
        guard exercises.contains(where: { $0.videoUrl == nil }) else { return }
        do {
            let repo = SupabaseExerciseRepository()
            let wikiAll = try await repo.fetchMuscleWikiAll()
            let bgContext = ModelContext(SharedModelContainer.container)

            for i in exercises.indices {
                guard exercises[i].videoUrl == nil else { continue }

                // ✅ Hledání: 1) nameEN, 2) slug, 3) český název jako poslední záchrana
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
                    // 1. Přesná shoda EN jménem nebo slugem
                    if !enClean.isEmpty && (wikiClean == enClean || wikiClean == slugClean) { return true }
                    // 2. Slug match
                    if wikiClean == slugClean { return true }
                    // 3. Obsahová shoda EN (min. 4 znaky pro prevenci false matches)
                    if enClean.count >= 4 && (wikiClean.contains(enClean) || enClean.contains(wikiClean)) { return true }
                    // 4. Slug obsahová shoda
                    if slugClean.count >= 4 && (wikiClean.contains(slugClean) || slugClean.contains(wikiClean)) { return true }
                    // 5. Český název — jen pokud nemáme EN a wiki je aspoň 5 znaků
                    if nameEN.isEmpty && czClean.count >= 5 && wikiClean.count >= 5 &&
                       (wikiClean.contains(czClean) || czClean.contains(wikiClean)) { return true }
                    return false
                })

                if let match {
                    exercises[i].videoUrl = match.videoUrl
                    // ✅ Také doplníme nameEN pokud chybí — pro budoucí lookups
                    if exercises[i].nameEN.isEmpty { exercises[i].nameEN = match.name }
                    AppLogger.info("✅ [enrichVideo] \(exercises[i].name) (EN: \(nameEN)) → \(match.name)")

                    // Uložit zpět do SwiftData Exercise pro budoucí offline spuštění
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
                    AppLogger.error("❌ [enrichVideo] Nenalezeno: \(exercises[i].name) (EN:\(nameEN), slug:\(slug))")
                }

                // Doplnit coachTip pokud chybí — coachTip je nyní var
                if exercises[i].coachTip == nil,
                   let dbInstructions = exercises[i].exercise?.instructions,
                   !dbInstructions.isEmpty {
                    exercises[i].coachTip = dbInstructions
                }
            }
        } catch {
            AppLogger.error("WorkoutViewModel.enrichWithVideoURLs: \(error)")
        }
    }

    // MARK: - RPE-aware progression (přesunuto do ProgressionEngine)
    // Tato metoda je zachována pro zpětnou kompatibilitu, ale logika je v ProgressionEngine.
    private func rpeAwareProgression(exercise: Exercise, targetWeight: Double?) -> Double? {
        guard let targetWeight else { return nil }
        // Pokud průměrné RPE bylo ≥10 (failure), mírně sniž váhu
        let recentEntries = exercise.weightHistory
            .sorted { $0.loggedAt > $1.loggedAt }
            .prefix(3)
        let avgRpe = recentEntries.compactMap(\.rpe).reduce(0, +) / Double(max(recentEntries.compactMap(\.rpe).count, 1))
        if avgRpe >= 10 {
            return WeightRounder.roundToNearestPlates(weight: targetWeight * 0.95)
        }
        return targetWeight
    }

    // MARK: - Timer

    private func startElapsedTimer() {
        elapsedTimerTask?.cancel()
        elapsedTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                elapsedSeconds += 1
            }
        }
    }

    // MARK: - Set Complete

    func completeSet(exerciseIndex: Int, setIndex: Int) {
        // Bounds check - prevence pádu při neplatném indexu
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex)
        else { return }
        // Povolíme dokončit i bez váhy (bodyweight cviky) - jen reps jsou povinné
        guard exercises[exerciseIndex].sets[setIndex].reps != nil
        else { return }

        withAnimation(.spring(response: 0.3)) {
            exercises[exerciseIndex].sets[setIndex].isCompleted = true
        }
        
        stopTempo()

        let exercise    = exercises[exerciseIndex]
        let restSeconds = exercise.restSeconds

        // Audio coach — série hotova (pochvala)
        if audioEnabled {
            AudioCoachManager.shared.announcePraise()
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
            advanceTask?.cancel()
            advanceTask = Task { @MainActor [weak self] in
                guard let self else { return }
                // Krátký delay aby uživatel viděl zelený checkmark
                try? await Task.sleep(nanoseconds: UInt64((Double(restSeconds) + 0.5) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.advanceToNextExercise()
            }
        }
    }
    
    // MARK: - Tempo Controls
    
    func startTempoForCurrentExercise() {
        guard audioEnabled else { return }
        let ex = exercises[currentExerciseIndex]
        let reps = ex.sets.first?.targetReps ?? 10
        audioCoach?.startTempo(tempoString: ex.tempo, reps: reps)
    }
    
    func stopTempo() {
        audioCoach?.stopTempo()
    }

    private func startRestTimer(seconds: Int) {
        guard seconds > 0 else { return }
        restTimerTask?.cancel()
        totalRestSeconds     = seconds
        restSecondsRemaining = seconds
        withAnimation { isResting = true }
        
        // Zapsání notifikace
        RestTimerManager.shared.startRestTimer(seconds: seconds)

        if audioEnabled {
            AudioCoachManager.shared.announce(message: "Pauza, \(seconds) vteřin.")
        }

        restTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                if restSecondsRemaining > 1 {
                    restSecondsRemaining -= 1
                    if restSecondsRemaining == 10 && audioEnabled {
                        AudioCoachManager.shared.announce(message: "Zbývá 10 vteřin. Připrav se.")
                    }
                } else {
                    if audioEnabled { AudioCoachManager.shared.announce(message: "Pauza skončila!") }
                    skipRest()
                    break
                }
            }
        }
    }

    func skipRest() {
        restTimerTask?.cancel()
        restTimerTask = nil
        
        // Zrušení případné běžící lokální notifikace
        RestTimerManager.shared.cancelTimer()
        
        withAnimation(.spring(response: 0.35)) { isResting = false }
        Task { await LiveActivityManager.shared.endWithDismissalDelay(2) }

        // Pokud bylo naplánované automatické přejití na další cvik (po dokončení všech sérií),
        // zruš čekání a přejdi okamžitě.
        if let task = advanceTask {
            task.cancel()
            advanceTask = nil
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s — krátký delay pro UI feedback
                self?.advanceToNextExercise()
            }
        }
    }

    func adjustRest(by delta: Int) {
        let updated = max(0, restSecondsRemaining + delta)
        restSecondsRemaining = updated
        // Při prodloužení pauzy upravíme i totalRestSeconds (zobrazení v progress baru)
        if delta > 0 {
            totalRestSeconds = max(totalRestSeconds, updated)
        }
        if updated == 0 { skipRest(); return }
        let newEndsAt = Date.now.addingTimeInterval(Double(updated))
        Task {
            await LiveActivityManager.shared.updateRestTimer(
                newEndsAt: newEndsAt,
                totalSeconds: updated
            )
        }
    }

    func skipExercise() { withAnimation { advanceToNextExercise() } }

    @Published var allExercisesDone = false   // true = uživatel dokončil všechny cviky

    private func advanceToNextExercise() {
        guard currentExerciseIndex < exercises.count - 1 else {
            // Všechny cviky dokončeny — upozorni UI
            withAnimation { allExercisesDone = true }
            if audioEnabled { AudioCoachManager.shared.announce(message: "Trénink dokončen! Skvělý výkon.") }  // ✅ Dedikovaná zpráva pro konec tréninku
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        withAnimation(.easeInOut) { currentExerciseIndex += 1 }
        HapticManager.shared.playMediumClick()

        // Audio coach — příští cvik
        if audioEnabled {
            let next = exercises[min(currentExerciseIndex, exercises.count - 1)]
            let targetWeight = next.sets.first(where: { $0.type == .normal })?.weightKg ?? next.sets.first?.previousWeightKg
            AudioCoachManager.shared.announceNextExercise(exerciseName: next.name, targetWeight: targetWeight)
        }
    }

    // MARK: - Smart Swap Logic

    func swapExercise(at index: Int, newName: String, newSlug: String, newExercise: Exercise? = nil) {
        guard exercises.indices.contains(index) else { return }
        
        let old = exercises[index]
        
        // Vytvoříme nový stav pro náhradní cvik
        let newState = SessionExerciseState(
            name: newName,
            slug: newSlug,
            coachTip: newExercise?.instructions.isEmpty == false
                ? newExercise?.instructions
                : "Sestaveno jako náhrada za \(old.name)",
            tempo: old.tempo,
            restSeconds: old.restSeconds,
            sets: old.sets.map { s in
                var newSet = s
                newSet.isCompleted = false // Resetujeme progres na novém cviku
                // Progressive overload pro nový cvik
                newSet.previousWeightKg = newExercise?.lastUsedWeight ?? old.sets.first?.previousWeightKg
                return newSet
            },
            exercise: newExercise  // Nastavíme Exercise referenci pro gamifikaci a PR tracking
        )
        
        withAnimation(.spring(response: 0.4)) {
            exercises[index] = newState
        }
    }

    // MARK: - Audio

    func toggleAudio() {
        audioEnabled.toggle()
        if audioEnabled {
            AudioCoachManager.shared.enable()
            AudioCoachManager.shared.announce(message: "Jdeme na to, zvuk zapnut!")
        } else {
            AudioCoachManager.shared.disable()
            audioCoach?.disable() // Původní metronom atd.
        }
    }

    // MARK: - Finish — ukládá WeightEntry do SwiftData pro progressive overload

    @discardableResult
    func finishWorkout(modelContext: ModelContext) -> ([XPGain], [PREvent]) {
        restTimerTask?.cancel()
        elapsedTimerTask?.cancel()
        advanceTask?.cancel()
        advanceTask = nil
        session.durationMinutes = elapsedSeconds / 60
        session.status = .completed
        session.finishedAt = .now

        // Ulož WeightEntry pro každý dokončený working set (ne warmup)
        for ex in exercises {
            guard !ex.isWarmupOnly else { continue }
            // Použij exercise přímo ze state (nastaveno v initu) - nepotřebujeme session.exercises lookup
            guard let exercise = ex.exercise else { continue }

            let workingSets = ex.sets.filter { $0.isCompleted && $0.type == .normal }
            for (setIdx, set) in workingSets.enumerated() {
                // Bodyweight cviky mohou mít weightKg = nil nebo 0
                let weight = set.weightKg
                guard let reps = set.reps, reps > 0 else { continue }
                let entry = WeightEntry(
                    exercise: exercise,
                    sessionId: session.id,
                    weightKg: weight,
                    reps: reps,
                    rpe: set.rpe,
                    wasSuccessful: rpe_isSuccessful(set.rpe),
                    setNumber: setIdx + 1
                )
                modelContext.insert(entry)
            }
        }

        do {
            try modelContext.save()
        } catch {
            AppLogger.error("WorkoutViewModel: Chyba při ukládání tréninku: \(error)")
        }
        Task { await LiveActivityManager.shared.endCurrentActivity() }

        // ── Zápis do Apple Health ──
        Task {
            // Vypočítáme odhad kalorií přes sdílenou utilitu
            let estimatedKcal = HealthWorkoutWriter.estimateBurnedCalories(durationSeconds: TimeInterval(elapsedSeconds))
            
            do {
                try await HealthWorkoutWriter.shared.saveStrengthWorkout(
                    startDate: session.startedAt,
                    endDate: session.finishedAt ?? Date(),
                    activeEnergyBurnedKcal: estimatedKcal,
                    metadata: ["Plan": planLabel]
                )
                AppLogger.info("[HealthKit] Trénink úspěšně zapsán do Apple Health. \(Int(estimatedKcal)) kcal")
            } catch {
                AppLogger.error("[HealthKit] Zápis tréninku selhal: \(error)")
            }
        }

        // ── PR detection ──
        let prEvents = detectPersonalRecords()

        // ── Gamifikace: přepočítej XP po dokončení tréninku (předej PR events pro bonus XP) ──
        let gamificationInput = buildGamificationInput(from: exercises, prEvents: prEvents)
        let engine = GamificationEngine()
        engine.loadRecords(from: modelContext)
        let gains = engine.process(input: gamificationInput, context: modelContext)
        if gains.contains(where: { $0.didLevelUp }) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        return (gains, prEvents)
    }

    // MARK: - Cancel — smaže session bez uložení

    func cancelWorkout(modelContext: ModelContext) {
        restTimerTask?.cancel()
        elapsedTimerTask?.cancel()
        session.status = .skipped
        modelContext.delete(session)
        do {
            try modelContext.save()
        } catch {
            AppLogger.error("WorkoutViewModel: Chyba při mazání session: \(error)")
        }
        Task { await LiveActivityManager.shared.endCurrentActivity() }
    }

    private func detectPersonalRecords() -> [PREvent] {
        var prs: [PREvent] = []
        for ex in exercises {
            guard let exercise = ex.exercise else { continue }
            let maxWeight = ex.sets.filter { $0.isCompleted && $0.type == .normal }
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

            // Odvoď svalové skupiny
            let primary: [MuscleGroup]
            let secondary: [MuscleGroup]
            
            if let exercise = state.exercise {
                // Přesná data z databáze
                primary = exercise.musclesTarget
                secondary = exercise.musclesSecondary
            } else {
                // Heuristika jako fallback
                primary = muscleGroupsFromSlug(state.slug, primary: true)
                secondary = muscleGroupsFromSlug(state.slug, primary: false)
            }

            let setResults: [SessionGamificationInput.SetResult] = completed.map {
                .init(weightKg: $0.weightKg, reps: $0.reps ?? 0, isWarmup: $0.isWarmup)
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

    /// Jednoduchá heuristika pro mapování slug → svalové skupiny
    /// Heuristika slug → MuscleGroup (fallback pokud Exercise DB reference chybí)
    private func muscleGroupsFromSlug(_ slug: String, primary: Bool) -> [MuscleGroup] {
        let s = slug.lowercased()
        if s.contains("bench") || s.contains("chest") || s.contains("fly") || (s.contains("press") && !s.contains("shoulder") && !s.contains("over")) {
            return primary ? [.chest] : [.triceps, .frontShoulders]
        } else if s.contains("row") || s.contains("pulldown") || s.contains("pull") || s.contains("lat") {
            return primary ? [.lats] : [.biceps, .traps]
        } else if s.contains("squat") || s.contains("quad") || s.contains("lunge") || s.contains("leg-press") {
            return primary ? [.quads] : [.glutes, .hamstrings]
        } else if s.contains("deadlift") || s.contains("rdl") || s.contains("hip") || s.contains("hamstring") {
            return primary ? [.hamstrings] : [.glutes, .lowerback]
        } else if s.contains("shoulder") || s.contains("lateral") || s.contains("overhead") || s.contains("ohp") {
            return primary ? [.frontShoulders] : [.triceps, .traps]
        } else if s.contains("curl") || s.contains("bicep") {
            return primary ? [.biceps] : [.forearms]
        } else if s.contains("tricep") || s.contains("dip") || s.contains("extension") || s.contains("pushdown") {
            return primary ? [.triceps] : []
        } else if s.contains("calf") || s.contains("raise") {
            return primary ? [.calves] : []
        } else if s.contains("ab") || s.contains("core") || s.contains("plank") || s.contains("crunch") {
            return primary ? [.abdominals] : [.obliques]
        } else if s.contains("glute") || s.contains("bridge") || s.contains("thrust") {
            return primary ? [.glutes] : [.hamstrings]
        } else if s.contains("trap") || s.contains("shrug") {
            return primary ? [.traps] : [.frontShoulders]
        } else if s.contains("face-pull") || s.contains("rear") {
            return primary ? [.rearShoulders] : [.trapsMiddle]
        }
        return primary ? [.chest] : []
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

    var completionProgress: Double {
        let totalSets     = exercises.flatMap(\.sets).count
        let completedSets = exercises.flatMap(\.sets).filter(\.isCompleted).count
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
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

struct SessionExerciseState: Identifiable {
    let id: UUID
    var name: String       // Česky (pro UI)
    var nameEN: String     // ✅ Anglicky — pro MuscleWiki lookup (videoUrl matching)
    var slug: String
    var coachTip: String?  // var — může být doplněno asynchronně
    let tempo: String?
    let restSeconds: Int
    var sets: [SetState]
    var isWarmupOnly: Bool
    var exercise: Exercise?
    var videoUrl: String?
    var supersetId: String? // Pro vizuální spojení supersérií

    init(id: UUID = UUID(), name: String, nameEN: String = "", slug: String, coachTip: String? = nil, tempo: String? = nil, restSeconds: Int = 60, sets: [SetState] = [], isWarmupOnly: Bool = false, exercise: Exercise? = nil, videoUrl: String? = nil, supersetId: String? = nil) {
        self.id = id
        self.name = name
        self.nameEN = nameEN.isEmpty ? (exercise?.nameEN ?? name) : nameEN
        self.slug = slug
        self.coachTip = coachTip
        self.tempo = tempo
        self.restSeconds = restSeconds
        self.sets = sets
        self.isWarmupOnly = isWarmupOnly
        self.exercise = exercise
        self.videoUrl = videoUrl ?? exercise?.videoURL
        self.supersetId = supersetId
    }

    var nextIncompleteSetIndex: Int? {
        sets.indices.first { !sets[$0].isCompleted }
    }

    init(from planned: PlannedExercise) {
        self.id          = UUID()
        let exerciseName = planned.exercise?.name ?? planned.fallbackName ?? planned.exercise?.nameEN ?? "Cvik"
        let exerciseSlug = planned.exercise?.slug ?? planned.fallbackSlug ?? "unknown-\(UUID().uuidString.prefix(8))"
        self.name        = exerciseName
        self.nameEN      = planned.exercise?.nameEN ?? ""  // ✅ Anglický název pro video matching
        self.slug        = exerciseSlug
        self.coachTip    = planned.exercise?.instructions.isEmpty == false ? planned.exercise?.instructions : nil
        self.tempo       = nil
        self.restSeconds = planned.restSeconds
        self.sets = (0..<max(1, planned.targetSets)).map { _ in
            SetState(
                type: .normal,
                targetReps: planned.targetRepsMax, // Using max as the primary target
                weightKg: planned.exercise?.lastUsedWeight ?? 0, // Default to 0 if nil
                previousWeightKg: planned.exercise?.lastUsedWeight
            )
        }
        self.isWarmupOnly = false
        self.exercise = planned.exercise
        self.videoUrl = planned.exercise?.videoURL
        self.supersetId = planned.supersetId
    }

    init(from response: ResponseExercise) {
        self.id          = UUID()
        self.name        = response.name
        self.nameEN      = response.nameEN
        self.slug        = FallbackWorkoutGenerator.normalizedSlug(response.slug)
        self.coachTip    = response.coachTip
        self.tempo       = response.tempo
        self.restSeconds = response.restSeconds
        self.sets = (0..<response.sets).map { _ in
            SetState(
                type: .normal,
                targetReps: response.repsMax, // Using max as the primary target
                weightKg: response.weightKg ?? 0, // Default to 0 if nil
                previousWeightKg: response.weightKg
            )
        }
        self.isWarmupOnly = false
        self.videoUrl = nil  // bude nastaveno po nalezení exerciseRef
        self.supersetId = response.supersetId
    }

    static func warmupExercise(_ wu: WarmUpExercise) -> SessionExerciseState {
        let reps = Int(wu.reps.components(separatedBy: CharacterSet.decimalDigits.inverted).first ?? "10") ?? 10
        let sets = (0..<wu.sets).map { _ in
            SetState(type: .warmup, targetReps: reps, weightKg: 0) // Warmup sets typically start with 0 weight
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
            state.sets[i].type = .warmup
            state.sets[i].weightKg = 0 // Warmup sets typically start with 0 weight
        }
        return state
    }
}



struct SetState: Identifiable {
    let id: UUID
    var type: SetType
    var targetRepsMin: Int
    var targetRepsMax: Int
    var weightKg: Double
    var reps: Int?
    var rpe: Int?
    var isCompleted: Bool
    var previousWeightKg: Double?
    var historicalWeightKg: Double?
    var historicalReps: Int?
    
    // Pro zpětnou kompatibilitu
    var targetReps: Int { targetRepsMin }
    var isWarmup: Bool { type == .warmup }
    
    init(id: UUID = UUID(), type: SetType = .normal, targetRepsMin: Int, targetRepsMax: Int? = nil, weightKg: Double, reps: Int? = nil, rpe: Int? = nil, previousWeightKg: Double? = nil, historicalWeightKg: Double? = nil, historicalReps: Int? = nil, isCompleted: Bool = false) {
        self.id = id
        self.type = type
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax ?? targetRepsMin
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.previousWeightKg = previousWeightKg
        self.historicalWeightKg = historicalWeightKg
        self.historicalReps = historicalReps
        self.isCompleted = isCompleted
    }
    
    // Legacy init
    init(type: SetType, targetReps: Int, weightKg: Double) {
        self.init(type: type, targetRepsMin: targetReps, targetRepsMax: targetReps, weightKg: weightKg)
}
