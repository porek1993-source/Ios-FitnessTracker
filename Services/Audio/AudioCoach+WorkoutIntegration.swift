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

/*
@MainActor
final class ActiveSessionViewModel: ObservableObject {
 ... reference implementation removed to prevent duplicate ...
}
*/

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
