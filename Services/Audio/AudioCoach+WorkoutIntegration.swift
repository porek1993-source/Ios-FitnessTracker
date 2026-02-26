// AudioCoach+WorkoutIntegration.swift
// Agilní Fitness Trenér — Rozšíření WorkoutViewModel o audio kouče + SwiftUI komponenty

import SwiftUI
import Combine

// MARK: - WorkoutViewModel rozšíření o audio kouče
//
// Níže jsou přesné body v WorkoutViewModel, kde volat AudioCoachService.
// Zkopíruj a vlož do WorkoutView.swift / WorkoutViewModel.

extension WorkoutViewModel {

    // ── 1. V init() ─────────────────────────────────────────────────────────
    //
    // func setup(audioCoach: AudioCoachService) {
    //     self.audioCoach = audioCoach
    //     audioCoach.announceSessionStart()
    // }
    //
    // ── 2. completeSet() ────────────────────────────────────────────────────
    //
    // func completeSet(exerciseIndex: Int, setIndex: Int) {
    //     ...stávající kód...
    //
    //     // [AUDIO] Série dokončena
    //     audioCoach?.announceSetComplete(praise: setIndex == exercise.sets.count - 1)
    //
    //     // [AUDIO] Pauza
    //     audioCoach?.announceRestStart(seconds: restSeconds)
    //
    //     startRestTimer(seconds: restSeconds)  // stávající
    // }
    //
    // ── 3. skipRest() ───────────────────────────────────────────────────────
    //
    // func skipRest() {
    //     ...stávající kód...
    //     audioCoach?.announceRestSkipped()
    // }
    //
    // ── 4. startSet (nová metoda — volej před zahájením série) ──────────────
    //
    // func prepareForNextSet(exerciseIndex: Int, setIndex: Int) {
    //     let exercise = exercises[exerciseIndex]
    //     audioCoach?.announceSetStarting(
    //         setIndex: setIndex,
    //         totalSets: exercise.sets.count,
    //         tempoString: exercise.tempo
    //     )
    //     // Spusť metronom — volej kdy uživatel klepne na "Začít sérii"
    //     guard let tempo = exercise.tempo,
    //           let parsed = TempoParser.parse(tempo) else { return }
    //     let reps = exercise.sets[setIndex].targetRepsMax
    //     audioCoach?.startTempo(tempoString: tempo, reps: reps)
    // }

    // Prázdný placeholder — zajišťuje kompilaci bez úpravy originálu
    var _audioCoachIntegrationDoc: Void { () }
}

// MARK: - Rozšířený WorkoutViewModel (self-contained reference implementace)

/// Tento ViewModel ukazuje KOMPLETNÍ integraci, pokud chceš přepsat původní.
/// Obsahuje všechny stávající funkce + audio vrstvy.
@MainActor
final class ActiveSessionViewModel: ObservableObject {

    // MARK: Published (stejné jako WorkoutViewModel)
    @Published var exercises: [SessionExerciseState]
    @Published var currentExerciseIndex = 0
    @Published var isResting = false
    @Published var restSecondsRemaining = 0
    @Published var totalRestSeconds = 90
    @Published var elapsedSeconds = 0

    // MARK: Audio
    @Published var audioCoach = AudioCoachService()

    // MARK: Private
    private var restTimer: Timer?
    private var elapsedTimer: Timer?
    let session: WorkoutSession
    let planLabel: String

    init(session: WorkoutSession, plan: PlannedWorkoutDay, planLabel: String) {
        self.session   = session
        self.planLabel = planLabel
        self.exercises = plan.plannedExercises
            .sorted { $0.order < $1.order }
            .map { SessionExerciseState(from: $0) }
        startElapsedTimer()
    }

    // MARK: - Audio Lifecycle

    func enableAudioCoach() {
        audioCoach.enable()
        audioCoach.announceSessionStart()
    }

    func disableAudioCoach() {
        audioCoach.disable()
    }

    // MARK: - Set Management

    /// Voláno při klepnutí na "Dokončit sérii"
    func completeSet(exerciseIndex: Int, setIndex: Int) {
        guard
            exercises[exerciseIndex].sets[setIndex].weightKg != nil,
            exercises[exerciseIndex].sets[setIndex].reps     != nil
        else { return }

        // Stop metronom — série skončila
        audioCoach.stopTempo()

        withAnimation(.spring(response: 0.3)) {
            exercises[exerciseIndex].sets[setIndex].isCompleted = true
        }

        let exercise    = exercises[exerciseIndex]
        let restSeconds = exercise.restSeconds

        // [AUDIO] Pochvala + oznámení pauzy
        let isLastSet = exercises[exerciseIndex].sets.allSatisfy(\.isCompleted)
        audioCoach.announceSetComplete(praise: !isLastSet)
        audioCoach.announceRestStart(seconds: restSeconds)

        // Live Activity
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

        if isLastSet {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(restSeconds) + 0.5) { [weak self] in
                self?.advanceToNextExercise()
            }
        }
    }

    /// Voláno když uživatel klepne na "Spustit sérii" (button v ActiveSetRow)
    func beginSet(exerciseIndex: Int, setIndex: Int) {
        let exercise = exercises[exerciseIndex]
        audioCoach.announceSetStarting(
            setIndex:     setIndex,
            totalSets:    exercise.sets.count,
            tempoString:  exercise.tempo
        )
        // Spusť metronom s počtem repů z targetu
        let reps = exercise.sets[setIndex].targetRepsMax
        audioCoach.startTempo(tempoString: exercise.tempo, reps: reps)
    }

    // MARK: - Rest Management

    private func startRestTimer(seconds: Int) {
        guard seconds > 0 else { return }
        restTimer?.invalidate()
        totalRestSeconds     = seconds
        restSecondsRemaining = seconds
        withAnimation { isResting = true }

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.restSecondsRemaining > 1 {
                    self.restSecondsRemaining -= 1
                } else {
                    self.skipRest()
                }
            }
        }
    }

    func skipRest() {
        restTimer?.invalidate()
        audioCoach.announceRestSkipped()
        withAnimation(.spring(response: 0.35)) { isResting = false }
        Task { await LiveActivityManager.shared.endWithDismissalDelay(2) }
    }

    func adjustRest(by delta: Int) {
        restSecondsRemaining = max(0, restSecondsRemaining + delta)
        if restSecondsRemaining == 0 { skipRest(); return }
        let newEndsAt = Date.now.addingTimeInterval(Double(restSecondsRemaining))
        Task {
            await LiveActivityManager.shared.updateRestTimer(
                newEndsAt:    newEndsAt,
                totalSeconds: restSecondsRemaining
            )
        }
    }

    // MARK: - Navigation

    func skipExercise() {
        audioCoach.stopAll()
        withAnimation { advanceToNextExercise() }
    }

    private func advanceToNextExercise() {
        guard currentExerciseIndex < exercises.count - 1 else { return }
        withAnimation(.easeInOut) { currentExerciseIndex += 1 }
    }

    func finishWorkout() {
        audioCoach.stopAll()
        audioCoach.disable()
        restTimer?.invalidate()
        elapsedTimer?.invalidate()
        Task { await LiveActivityManager.shared.endCurrentActivity() }
    }

    // MARK: - Elapsed Timer

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.elapsedSeconds += 1 }
        }
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

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: - SwiftUI Komponenty
// MARK: ─────────────────────────────────────────────────────────────────────

// MARK: - AudioCoachToggle (tlačítko pro header)

struct AudioCoachToggle: View {
    @ObservedObject var coach: AudioCoachService

    @State private var pulse = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                coach.toggle()
            }
            // Haptika
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            ZStack {
                // Glow při mluvení
                if coach.isSpeaking {
                    Circle()
                        .fill(Color.blue.opacity(0.25))
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulse ? 1.4 : 1.0)
                        .opacity(pulse ? 0 : 1)
                        .animation(
                            .easeOut(duration: 0.7).repeatForever(autoreverses: false),
                            value: pulse
                        )
                }

                // Background pill
                Capsule()
                    .fill(coach.isEnabled
                          ? Color.blue.opacity(0.2)
                          : Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(
                                coach.isEnabled ? Color.blue.opacity(0.5) : Color.clear,
                                lineWidth: 1
                            )
                    )

                // Content
                HStack(spacing: 5) {
                    Image(systemName: coach.isEnabled ? "waveform" : "waveform.slash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(coach.isEnabled ? .blue : .white.opacity(0.4))
                        .symbolEffect(.variableColor.cumulative, isActive: coach.isSpeaking)

                    Text(coach.isEnabled ? "Kouč" : "Kouč")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(coach.isEnabled ? .white : .white.opacity(0.4))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
            .frame(height: 34)
        }
        .buttonStyle(.plain)
        .onAppear { pulse = true }
        .onChange(of: coach.isSpeaking) { _, speaking in
            pulse = speaking
        }
    }
}

// MARK: - TempoIndicator (zobrazení aktuální fáze tempo během série)

struct TempoIndicator: View {
    let tempoString: String?
    @ObservedObject var coach: AudioCoachService

    private var parsed: ParsedTempo? { TempoParser.parse(tempoString) }

    var body: some View {
        if let tempo = parsed, coach.isEnabled {
            HStack(spacing: 6) {
                ForEach(TempoPhase.allCases, id: \.rawValue) { phase in
                    TempoPhaseCell(
                        phase:      phase,
                        beats:      beats(for: phase, tempo: tempo),
                        isActive:   coach.currentPhase == phase
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
            .animation(.spring(response: 0.25), value: coach.currentPhase)
        }
    }

    private func beats(for phase: TempoPhase, tempo: ParsedTempo) -> Int {
        switch phase {
        case .eccentric:   return tempo.eccentric
        case .pauseBottom: return tempo.pauseBottom
        case .concentric:  return tempo.concentric
        case .pauseTop:    return tempo.pauseTop
        }
    }
}

private struct TempoPhaseCell: View {
    let phase: TempoPhase
    let beats: Int
    let isActive: Bool

    var label: String {
        switch phase {
        case .eccentric:   return "↓"
        case .pauseBottom: return "•"
        case .concentric:  return "↑"
        case .pauseTop:    return "•"
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isActive ? .white : .white.opacity(0.3))

            Text("\(beats)s")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(isActive ? Color.blue : .white.opacity(0.2))
        }
        .frame(minWidth: 28)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.blue.opacity(0.2) : Color.clear)
        )
        .scaleEffect(isActive ? 1.08 : 1.0)
    }
}

// MARK: - Ukázka použití v WorkoutHeaderView
//
// Přidej `audioCoach: AudioCoachService` do WorkoutHeaderView
// a vlož AudioCoachToggle do HStack v headeru:
//
// struct WorkoutHeaderView: View {
//     @ObservedObject var vm: ActiveSessionViewModel
//
//     var body: some View {
//         HStack(alignment: .center) {
//             // ... elapsed time ...
//             Spacer()
//             // ... progress dots ...
//             Spacer()
//
//             HStack(spacing: 8) {
//                 AudioCoachToggle(coach: vm.audioCoach)  // ← PŘIDAT
//
//                 Button { vm.finishWorkout() } label: {
//                     Text("Dokončit")
//                     // ... styling ...
//                 }
//             }
//         }
//     }
// }
//
// A do ExerciseCardView přidej TempoIndicator:
//
// TechTipsRow(exercise: exercise)
//     .padding(.horizontal, 20)
//
// TempoIndicator(tempoString: exercise.tempo, coach: vm.audioCoach)  // ← PŘIDAT
//     .padding(.horizontal, 20)


// MARK: - Preview

#Preview("AudioCoachToggle") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            AudioCoachToggle(coach: AudioCoachService())

            // S aktivním koučem
            let activeCoach: AudioCoachService = {
                let c = AudioCoachService()
                return c
            }()
            AudioCoachToggle(coach: activeCoach)

            // Tempo indikátor
            TempoIndicator(tempoString: "3-1-2-0", coach: AudioCoachService())
        }
    }
}
