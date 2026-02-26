// RestTimerOverlay.swift
import SwiftUI

struct RestTimerOverlay: View {
    @ObservedObject var vm: WorkoutViewModel

    private var nextExerciseName: String? {
        let nextIdx = vm.currentExerciseIndex + 1
        guard nextIdx < vm.exercises.count else { return nil }
        let next = vm.exercises[nextIdx]
        return next.isWarmupOnly ? nil : next.name
    }

    private var currentSetsDone: Int {
        guard vm.exercises.indices.contains(vm.currentExerciseIndex) else { return 0 }
        return vm.exercises[vm.currentExerciseIndex].sets.filter { $0.isCompleted }.count
    }

    private var currentSetsTotal: Int {
        guard vm.exercises.indices.contains(vm.currentExerciseIndex) else { return 0 }
        return vm.exercises[vm.currentExerciseIndex].sets.filter { !$0.isWarmup }.count
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.80).ignoresSafeArea().onTapGesture { vm.skipRest() }
            VStack(spacing: 20) {
                // Série info
                Text("SÉRIE \(currentSetsDone) / \(currentSetsTotal)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white.opacity(0.4))
                    .kerning(2)

                Text("PAUZA")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .kerning(2)

                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 8).frame(width: 160, height: 160)
                    Circle()
                        .trim(from: 0, to: vm.restProgress)
                        .stroke(
                            AngularGradient(colors: [.blue, .cyan], center: .center),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: vm.restProgress)
                    VStack(spacing: 4) {
                        Text(vm.restTimeFormatted)
                            .font(.system(size: 52, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText(countsDown: true))
                        Text("zbývá").font(.system(size: 13)).foregroundStyle(.white.opacity(0.4))
                    }
                }

                // Příští cvik
                if let next = nextExerciseName {
                    VStack(spacing: 4) {
                        Text("PŘÍŠTÍ CVIK")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white.opacity(0.3))
                            .kerning(1.5)
                        Text(next)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
                }

                HStack(spacing: 16) {
                    TimerAdjustButton(label: "−15s") { vm.adjustRest(by: -15) }
                    Button { vm.skipRest() } label: {
                        Text("Přeskočit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 140, height: 48)
                            .background(Capsule().fill(Color.white))
                    }
                    TimerAdjustButton(label: "+15s") { vm.adjustRest(by: 15) }
                }
                Text("Klepni kamkoliv pro přeskočení")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
    }
}

struct TimerAdjustButton: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 48)
                .background(Capsule().fill(Color.white.opacity(0.12)))
        }
    }
}
