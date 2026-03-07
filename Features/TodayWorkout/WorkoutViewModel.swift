// WorkoutViewModel.swift
// Agilní Fitness Trenér — ViewModel pro aktivní trénink

import SwiftUI
import SwiftData

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published var exercises: [SessionExerciseState]
    @Published var currentExerciseIndex = 0
    @Published var warmupExercises: [String]? = nil
    
    // UI State
    @Published var showSummary = false
    @Published var isResting = false
    @Published var restSecondsRemaining = 0
    @Published var totalRestSeconds = 90
    @Published var elapsedSeconds = 0
    @Published var audioEnabled = true
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

            // Warmup — naplníme warmupExercises pro WarmupPhaseView
            var warmupNames: [String] = []
            for wu in response.warmUp {
                states.append(SessionExerciseState.warmupExercise(wu))
                warmupNames.append(wu.name)
            }
            warmupExercises = warmupNames.isEmpty ? nil : warmupNames

            // Main exercises - flatten mainBlocks
            for block in response.mainBlocks {
                for (index, ex) in block.exercises.enumerated() {
                    var state = SessionExerciseState(from: ex)

                    // ✅ Phase 18 FIX: Striktní mapování k eliminaci AI halucinací a ochrana datové suverenity
                    let normalizedSlug = FallbackWorkoutGenerator.normalizedSlug(ex.slug)
                    var exerciseRef: Exercise? = nil

                    // 1. Zkusit najít EXAKTNÍ shodu přes slug (nejspolehlivější, udržuje historii)
                    exerciseRef = allDBExercises.first { $0.slug.lowercased() == normalizedSlug || $0.slug.lowercased() == ex.slug.lowercased() }

                    // 2. Pokud slug selže, zkusit exaktní jméno z plánu (Fallback pro custom cviky)
                    if exerciseRef == nil {
                        if let plannedEx = plan.plannedExercises.first(where: {
                            let fName = ex.name.lowercased()
                            return $0.exercise?.nameEN.lowercased() == fName || $0.exercise?.name.lowercased() == fName
                        }) {
                            exerciseRef = plannedEx.exercise
                        }
                    }

                    // 3. Poslední záchrana: Fuzzy match na celé DB (jen pokud model selhal do názvu)
                    if exerciseRef == nil {
                        let fName = ex.name.lowercased()
                        exerciseRef = allDBExercises.first(where: {
                            $0.nameEN.lowercased() == fName || $0.name.lowercased() == fName ||
                            $0.name.lowercased().contains(fName) || $0.nameEN.lowercased().contains(fName) ||
                            fName.contains($0.name.lowercased())
                        })
                    }

                    if let exercise = exerciseRef {
                        // Použij ProgressionEngine pro výpočet cíle
                        // ✅ FIX: Zohledňujeme pouze POSLEDNÍ trénink daného cviku.
                        let lastSessionId = exercise.weightHistory.max(by: { $0.loggedAt < $1.loggedAt })?.sessionId
                        let history = exercise.weightHistory
                            .filter { lastSessionId != nil && $0.sessionId == lastSessionId }
                            .sorted { $0.loggedAt > $1.loggedAt }
                            .map { entry in
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
            let sortedPlanned = plan.sortedExercises
            var states: [SessionExerciseState] = []

            for (index, planned) in sortedPlanned.enumerated() {
                var state = SessionExerciseState(from: planned)

                // Progressive overload s ProgressionEngine
                if let exercise = planned.exercise {
                    // ✅ FIX: Zohledňujeme pouze POSLEDNÍ trénink daného cviku.
                    let lastSessionId = exercise.weightHistory.max(by: { $0.loggedAt < $1.loggedAt })?.sessionId
                    let history = exercise.weightHistory
                        .filter { lastSessionId != nil && $0.sessionId == lastSessionId }
                        .sorted { $0.loggedAt > $1.loggedAt }
                        .map { entry in
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

        // Init audio coach — obě instance (metronom + obecné hlášky)
        audioCoach = AudioCoachService()
        audioCoach?.enable()
        AudioCoachManager.shared.enable()
        audioCoach?.announceSessionStart()

        // ✅ Phase 4: Upozorni Apple Watch, že trénink začal (spustí HKWorkoutSession + senzory)
        WatchIntegrationService.shared.notifyWorkoutStarted(title: planLabel)

        // ✅ FIX Bug #1: Dohledat chybějící videoURL a coachTip přímo z Supabase MuscleWiki
        // Spustíme async, nezablokujeme UI — výsledky se propisují do @Published exercises
        // ✅ FIX: [weak self] pro zamezení retain cycle v initu
        Task { [weak self] in await self?.enrichWithVideoURLs() }

        // ✅ Phase 4: Registrace příjmu zpráv z Apple Watch
        WatchIntegrationService.shared.registerMessageHandler(
            onSetCompleted: { [weak self] reps, weight in
                self?.handleWatchSetCompleted(reps: reps, weight: weight)
            },
            onRestSkipped: { [weak self] in
                self?.handleWatchRestSkipped()
            },
            onHRRecoveryRPE: { [weak self] setNum, rpe in
                self?.handleWatchHRRecoveryRPE(setNumber: setNum, rpe: rpe)
            }
        )
    }

    // MARK: - Video URL Enrichment (Bug #1 Fix)

    /// Pro cviky, kde videoUrl nebo coachTip chybí (sync nestihl spárovat), načte data přímo ze Supabase.
    /// ✅ FIX: Hledání primárně přes nameEN (anglický název) — MuscleWiki databáze je v angličtině.
    private func enrichWithVideoURLs() async {
        guard exercises.contains(where: { $0.videoUrl == nil }) else { return }
        do {
            let repo = AppEnvironment.shared.exerciseRepository // ✅ FIX: Sdílená instance místo nové
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
                            try? bgContext.save()  // Non-critical: cache video URL do SwiftData
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

    // MARK: - Timer

    private func startElapsedTimer() {
        elapsedTimerTask?.cancel()
        elapsedTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { break }
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
            
            // ✅ RPE Auto-Regulation: Pokud byla série příliš lehká (RPE <= 7) a je další pracovní série
            let currentSet = exercises[exerciseIndex].sets[setIndex]
            let nextSetIdx = setIndex + 1
            if let rpe = currentSet.rpe, rpe <= 7,
               nextSetIdx < exercises[exerciseIndex].sets.count,
               exercises[exerciseIndex].sets[nextSetIdx].type == .normal,
               !exercises[exerciseIndex].sets[nextSetIdx].isCompleted {
                
                let currentWeight = currentSet.weightKg
                if currentWeight > 0 {
                    // Doporučíme zvýšení váhy o 2.5 kg pro další sérii
                    exercises[exerciseIndex].sets[nextSetIdx].previousWeightKg = currentWeight + 2.5
                    exercises[exerciseIndex].sets[nextSetIdx].rpeSuggestionApplied = true
                }
            }
        }
        
        // ✅ CHHapticEngine double-tap (deepanal.pdf)
        HapticPatternEngine.shared.playSetComplete()
        
        stopTempo()

        let exercise    = exercises[exerciseIndex]
        let restSeconds = exercise.restSeconds

        // Audio coach — série hotova (pochvala)
        if audioEnabled {
            AudioCoachManager.shared.announcePraise()
        }

        // ✅ FIX: [weak self] pro zamezení retain cycle
        Task { [weak self] in
            guard let self else { return }
            // Vypočítáme aktuální index a počet dokončených cviků pro Live Activity
            let currentIdx = exerciseIndex
            let completedCount = exercises.filter { $0.sets.allSatisfy { $0.isCompleted } }.count
            let nextEx: SessionExerciseState? = currentIdx + 1 < exercises.count ? exercises[currentIdx + 1] : nil
            
            await LiveActivityManager.shared.startRestActivity(
                session:           session,
                currentExercise:   exercise,
                nextExercise:      nextEx,
                currentExerciseIndex: currentIdx,
                totalExercises:    exercises.count,
                completedExercisesCount: completedCount,
                completedSetIndex: setIndex,
                restSeconds:       restSeconds,
                planLabel:         planLabel
            )
        }

        startRestTimer(seconds: restSeconds)

        // ── Apple Watch sync ──────────────────────────────────────────
        // Přiští série na hodinkách (odešleme info o přístí sérii k připravení)
        let nextSetIndex = setIndex + 1
        if exercise.sets.indices.contains(nextSetIndex) {
            let nextSet = exercise.sets[nextSetIndex]
            WatchIntegrationService.shared.notifySetStarted(
                exerciseName: exercise.name,
                setNumber:    nextSetIndex + 1,
                totalSets:    exercise.sets.count,
                repsMin:      nextSet.targetRepsMin,
                repsMax:      nextSet.targetRepsMax,
                weightKg:     nextSet.weightKg > 0 ? nextSet.weightKg : nextSet.previousWeightKg,
                restSeconds:  exercise.restSeconds,
                setType:      nextSet.type.watchLabel
            )
        }

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
        guard exercises.indices.contains(currentExerciseIndex) else { return }
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

        restTimerTask = Task { [weak self] in
            guard let self else { return }
            // Haptický countdown: posledních 5 sekund = srdeční tep
            let hapticCountdownSecs = min(5, seconds)
            
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                if restSecondsRemaining > 1 {
                    restSecondsRemaining -= 1
                    
                    // Bezpečně spustíme haptics až když zbývá přesný čas
                    if restSecondsRemaining == hapticCountdownSecs {
                        HapticPatternEngine.shared.playHeartbeatCountdown(seconds: hapticCountdownSecs)
                    }
                    
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

    /// Přičte čas strávený rozcvičkou k celkovému elapsed time
    func addWarmupTime(seconds: Int) {
        elapsedSeconds += max(0, seconds)
    }

    // MARK: - Watch Integration Handlers

    private func handleWatchSetCompleted(reps: Int, weight: Double) {
        let exIdx = currentExerciseIndex
        guard exercises.indices.contains(exIdx) else { return }
        
        guard let currentSetIdx = exercises[exIdx].sets.firstIndex(where: { !$0.isCompleted }) else { return }
        
        // Aktualizujeme hodnoty podle hodinek
        exercises[exIdx].sets[currentSetIdx].reps = reps
        if weight > 0 {
            exercises[exIdx].sets[currentSetIdx].weightKg = weight
        }
        
        // Dokončíme sérii
        completeSet(exerciseIndex: exIdx, setIndex: currentSetIdx)
        AppLogger.info("⌚️ [WorkoutViewModel] Dokončena série z Apple Watch: rep \(reps), weight \(weight)")
    }

    private func handleWatchRestSkipped() {
        if isResting {
            skipRest()
            AppLogger.info("⌚️ [WorkoutViewModel] Přeskočena pauza z Apple Watch")
        }
    }

    private func handleWatchHRRecoveryRPE(setNumber: Int, rpe: Double) {
        let exIdx = currentExerciseIndex
        guard exercises.indices.contains(exIdx) else { return }
        
        // ✅ FIX: setNumber z hodinek je globální counter (1, 2, 3… přes celý trénink),
        // ale exercises[exIdx].sets je per-exercise. Místo indexování globálním číslem
        // najdeme poslední dokončenou sérii v aktuálním cviku a přiřadíme jí RPE.
        if let lastCompletedIdx = exercises[exIdx].sets.lastIndex(where: { $0.isCompleted && $0.rpe == nil }) {
            exercises[exIdx].sets[lastCompletedIdx].rpe = Int(rpe)
            AppLogger.info("⌚️ [WorkoutViewModel] Přijato HR Recovery RPE \(rpe) pro sérii \(lastCompletedIdx + 1) cviku \(exercises[exIdx].name)")
        } else {
            AppLogger.warning("⌚️ [WorkoutViewModel] HR Recovery RPE \(rpe) přijato, ale nenalezena série bez RPE v cviku \(exercises[exIdx].name)")
        }
    }

    @Published var allExercisesDone = false   // true = uživatel dokončil všechny cviky

    private func advanceToNextExercise() {
        guard currentExerciseIndex < exercises.count - 1 else {
            withAnimation { allExercisesDone = true }
            if audioEnabled { AudioCoachManager.shared.announce(message: "Trénink dokončen! Skvělý výkon.") }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // ── Apple Watch: trénink dokončen ──
            WatchIntegrationService.shared.notifyWorkoutEnded()
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

        // ── Apple Watch: odešleme info o 1. sérii nového cviku ──
        if exercises.indices.contains(currentExerciseIndex) {
            let ex      = exercises[currentExerciseIndex]
            let firstSet = ex.sets.first
            WatchIntegrationService.shared.notifySetStarted(
                exerciseName: ex.name,
                setNumber:    1,
                totalSets:    ex.sets.count,
                repsMin:      firstSet?.targetRepsMin ?? 8,
                repsMax:      firstSet?.targetRepsMax ?? 12,
                weightKg:     firstSet.flatMap { $0.weightKg > 0 ? $0.weightKg : $0.previousWeightKg },
                restSeconds:  ex.restSeconds,
                setType:      firstSet?.type.watchLabel ?? "N"
            )
        }

    } // advanceToNextExercise

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
            audioCoach?.enable()
            AudioCoachManager.shared.enable()
            AudioCoachManager.shared.announce(message: "Zvuk zapnut!")
        } else {
            audioCoach?.disable()
            AudioCoachManager.shared.disable()
        }
    }

    // MARK: - Finish — ukládá WeightEntry do SwiftData pro progressive overload

    @discardableResult
    func finishWorkout(modelContext: ModelContext) -> ([XPGain], [PREvent]) {
        restTimerTask?.cancel()
        elapsedTimerTask?.cancel()
        advanceTask?.cancel()
        advanceTask = nil
        audioCoach?.stopAll()
        audioCoach?.disable()
        AudioCoachManager.shared.disable()
        session.durationMinutes = elapsedSeconds / 60
        session.status = .completed
        session.finishedAt = .now

        // Vymažeme staré cviky ze session (pokud tam nějaké byly z přípravy) a nahradíme je reálně odcvičenými
        session.exercises.removeAll()
        
        // Ulož do session a zároveň vytvoř WeightEntry pro každý dokončený working set
        for (exIdx, ex) in exercises.enumerated() {
            guard let exercise = ex.exercise else { continue }
            
            let sEx = SessionExercise(
                order: exIdx,
                exercise: exercise,
                fallbackSlug: ex.slug,
                fallbackName: ex.name,
                session: session
            )
            modelContext.insert(sEx)
            
            let workingSets = ex.sets.enumerated().filter { $0.element.isCompleted && ($0.element.type == .normal || $0.element.type == .failure) }
            for (setIdx, set) in workingSets {
                let weight = set.weightKg
                guard let reps = set.reps, reps > 0 else { continue }
                
                // 1. Záznam pro analytiku a progressive overload
                let entry = WeightEntry.create(
                    exercise: exercise,
                    sessionId: session.id,
                    weightKg: weight,
                    reps: reps,
                    rpe: set.rpe,
                    wasSuccessful: rpe_isSuccessful(set.rpe),
                    setNumber: setIdx + 1,
                    type: set.type
                )
                modelContext.insert(entry)
                
                // 2. Záznam pro historii session (lehčí objekt)
                let cSet = CompletedSet(
                    setNumber: setIdx + 1,
                    weightKg: weight,
                    reps: reps,
                    rpe: set.rpe.map { Double($0) },  // ✅ FIX: Odstraněno redundantní force-unwrap Double(set.rpe!)
                    type: set.type
                )
                modelContext.insert(cSet)
                sEx.completedSets.append(cSet)
            }
        }

        do {
            try modelContext.save()
        } catch {
            AppLogger.error("WorkoutViewModel: Chyba při ukládání tréninku: \(error)")
        }
        Task { await LiveActivityManager.shared.endCurrentActivity() }

        // ── Zápis do Apple Health ──
        // ✅ Konsolidováno: HealthKitWorkoutWriter (moderní API) místo zastaralého HealthWorkoutWriter.shared
        Task { [weak self] in
            guard let self else { return }
            let estimatedKcal = HealthKitWorkoutWriter.estimateBurnedCalories(durationSeconds: TimeInterval(elapsedSeconds))
            do {
                try await HealthKitWorkoutWriter.saveStrengthWorkout(
                    startDate: session.startedAt,
                    endDate: session.finishedAt ?? Date(),
                    activeEnergyBurnedKcal: estimatedKcal,
                    metadata: ["Plan": planLabel]
                )
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
        advanceTask?.cancel()
        restTimerTask?.cancel()
        elapsedTimerTask?.cancel()
        audioCoach?.stopAll()
        audioCoach?.disable()
        AudioCoachManager.shared.disable()
        
        // Zastavení hodinek při manuálním zrušení tréninku na iPhone!
        WatchIntegrationService.shared.notifyWorkoutEnded()
        
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
            
            // ✅ FIX: Kontrola vůči HISTORICKÉMU maximu (all-time PR), nejen vůči minulé session.
            let allTimeMax = exercise.weightHistory.compactMap { $0.weightKg }.max() ?? 0
            let prev = max(exercise.lastUsedWeight ?? 0, allTimeMax)
            
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

extension SessionExerciseState {
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
                targetRepsMin: planned.targetRepsMin,
                targetRepsMax: planned.targetRepsMax,
                weightKg: planned.exercise?.lastUsedWeight ?? 0,
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
        self.nameEN      = response.nameEN ?? ""
        self.slug        = FallbackWorkoutGenerator.normalizedSlug(response.slug)
        self.coachTip    = response.coachTip
        self.tempo       = response.tempo
        self.restSeconds = response.restSeconds
        self.isWarmupOnly = false
        self.videoUrl    = nil
        self.supersetId  = response.supersetId

        // ── Sestaveni sad serie (rozcvicka + pracovni + drop/failure) ──────
        var allSets: [SetState] = []

        // 1. Zahřívací série před pracovními (pokud AI řekla warmupSets > 0)
        let wCount = max(0, response.warmupSets ?? 0)
        if wCount > 0, let kg = response.weightKg, kg > 0 {
            // Zahřívací: postupně eskalující váhy (50% → 70% → 85%)
            let warmupPcts: [Double] = [0.5, 0.7, 0.85]
            for i in 0..<min(wCount, warmupPcts.count) {
                allSets.append(SetState(
                    type: .warmup,
                    targetRepsMin: 5,
                    targetRepsMax: 8,
                    weightKg: (kg * warmupPcts[i]).rounded(.toNearestOrAwayFromZero),
                    previousWeightKg: nil
                ))
            }
        }

        // 2. Pracovní série (N-1 normálních, poslední může být Drop nebo Failure)
        let workingCount = max(1, response.sets)
        let isLastDrop    = response.isDropSet  == true
        let isLastFailure = response.isFailure  == true

        for i in 0..<workingCount {
            let isLast = (i == workingCount - 1)
            let setType: SetType
            if isLast && isLastDrop { setType = .dropset }
            else if isLast && isLastFailure { setType = .failure }
            else { setType = .normal }

            allSets.append(SetState(
                type: setType,
                targetRepsMin: response.repsMin,
                targetRepsMax: response.repsMax,
                weightKg: response.weightKg ?? 0,
                previousWeightKg: response.weightKg
            ))
        }

        self.sets = allSets
    } // init(from: ResponseExercise)

    static func warmupExercise(_ wu: WarmUpExercise) -> SessionExerciseState {
        let reps = Int(wu.reps.components(separatedBy: CharacterSet.decimalDigits.inverted).first ?? "10") ?? 10
        let sets = (0..<wu.sets).map { _ in
            SetState(type: .warmup, targetRepsMin: reps, weightKg: 0) // Warmup sets typically start with 0 weight
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



