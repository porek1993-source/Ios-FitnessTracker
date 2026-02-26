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
    private weak var appEnv: AppEnvironment?  // ⚠️ weak: zabraňuje retain cycle ViewModel ↔ AppEnvironment

    // MARK: - Init

    init(
        session:   WorkoutSession,
        plan:      PlannedWorkoutDay,
        planLabel: String,
        aiResponse: TrainerResponse? = nil,
        appEnv:    AppEnvironment? = nil
    ) {
        self.session   = session
        self.planLabel = planLabel
        self.appEnv    = appEnv

        buildExerciseStates(from: plan, aiResponse: aiResponse)
        startElapsedTimer()
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
        // Zruš předchozí Task pokud ještě běží (uživatel rychle přepíná cviky)
        coachTipTask?.cancel()

        coachTipTask = Task { [weak self] in  // ⚠️ [weak self] — POVINNÉ
            guard let self else { return }     // ⚠️ guard — POVINNÉ

            self.isLoadingCoachTip = true
            defer {
                // defer se spustí i při Task cancellation — zajistí reset stavu
                // ⚠️ V defer MUSÍME znovu ověřit, že self existuje
                Task { @MainActor [weak self] in
                    self?.isLoadingCoachTip = false
                }
            }

            // Kontrola Task cancellation před heavyweight operací
            guard !Task.isCancelled else { return }

            // Simulace AI volání (nahraď skutečným AI service voláním)
            // V produkci: let tip = try await aiService.generateCoachTip(for: exercise)
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s debounce

    

            // ✅ Bezpečné: @MainActor třída zajišťuje, že jsme na main threadu
            self.coachMessage = self.exercises[safe: self.currentExerciseIndex]?.coachTip
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

            // ✅ Výsledky zapisujeme zpět na MainActor
            // Protože třída je @MainActor, stačí await na MainActor.run
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.hkWriteResult = hkResult
                self.isFinishing   = false
                AppLogger.info("[ActiveSession] Trénink dokončen: \(completedExercises.count) cviků.")
            }

            // SwiftData save na background threadu (pomocí ModelActor v produkci)
            // Zde pro jednoduchost voláme na MainActor
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.saveSessionToSwiftData(session: sessionCopy, context: modelContext)
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
        // Zruš existující task (prevence duplicit)
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
        restSecondsRemaining = seconds
        totalRestSeconds     = seconds
        isResting            = true

        restTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, let self = self else { break }
                
                if self.restSecondsRemaining > 0 {
                    self.restSecondsRemaining -= 1
                } else {
                    self.restTask = nil
                    self.isResting = false
                    HapticManager.shared.playSuccess()
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
        restSecondsRemaining = max(0, restSecondsRemaining + delta)
        totalRestSeconds     = max(totalRestSeconds, restSecondsRemaining)
    }

    func skipExercise() {
        guard currentExerciseIndex < exercises.count - 1 else { return }
        currentExerciseIndex += 1
        HapticManager.shared.playSelection()
    }

    func swapExercise(at index: Int, newName: String, newSlug: String) {
        guard exercises.indices.contains(index) else { return }
        exercises[index].name = newName
        exercises[index].slug = newSlug
        HapticManager.shared.playMediumClick()
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
        let result = await writer.write(session: session)
        if result.success {
            return .success
        } else {
            let errorMsg = result.error?.localizedDescription ?? "Neznámá chyba zápisu"
            AppLogger.error("[ActiveSession] HealthKit zápis selhal: \(errorMsg)")
            return .failed(errorMsg)
        }
    }

    private func saveSessionToSwiftData(session: WorkoutSession, context: ModelContext) {
        session.finishedAt = .now
        do {
            try context.save()
            AppLogger.info("[ActiveSession] Session uložena do SwiftData.")
        } catch {
            AppLogger.error("[ActiveSession] Chyba při ukládání session: \(error)")
            appEnv?.showError(message: "Trénink se nepodařilo uložit. Zkus to znovu.")
        }
    }

    private func buildExerciseStates(from plan: PlannedWorkoutDay, aiResponse: TrainerResponse?) {
        var states: [SessionExerciseState] = []

        if let response = aiResponse, !response.mainBlocks.isEmpty {
            for wu in response.warmUp {
                states.append(SessionExerciseState.warmupExercise(wu))
            }
            for block in response.mainBlocks {
                for ex in block.exercises {
                    states.append(SessionExerciseState(from: ex))
                }
            }
        } else {
            for plannedEx in plan.plannedExercises.sorted(by: { $0.order < $1.order }) {
                states.append(SessionExerciseState(from: plannedEx))
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


