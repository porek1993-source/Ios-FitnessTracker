// WorkoutHeaderView.swift
import SwiftUI

struct WorkoutHeaderView: View {
    @ObservedObject var vm: WorkoutViewModel
    var onFinish: (() -> Void)? = nil  // Callback k WorkoutView.finishWorkout()
    @State private var showFinishConfirm = false

    var body: some View {
        HStack(alignment: .center) {
            // Timer
            VStack(alignment: .leading, spacing: 1) {
                Text("ČAS")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white.opacity(0.32))
                    .kerning(1.6)
                Text(vm.elapsedTimeFormatted)
                    .font(.system(size: 19, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            Spacer()

            // Exercise progress dots — max 12 dots
            let dotCount = min(vm.exercises.count, 12)
            HStack(spacing: vm.exercises.count > 8 ? 4 : 6) {
                ForEach(0..<dotCount, id: \.self) { i in
                    let isDone    = i < vm.currentExerciseIndex
                    let isCurrent = i == vm.currentExerciseIndex
                    let dotSize: CGFloat = vm.exercises.count > 8 ? (isCurrent ? 7 : 5) : (isCurrent ? 9 : 6)
                    ZStack {
                        Circle()
                            .fill(isDone ? Color(red:0.15, green:0.82, blue:0.45)
                                        : isCurrent ? .white : .white.opacity(0.18))
                            .frame(width: dotSize, height: dotSize)
                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: dotSize * 0.55, weight: .black))
                                .foregroundStyle(.black)
                        }
                    }
                    .animation(.spring(response: 0.28), value: vm.currentExerciseIndex)
                }
                // Pokud více než 12 cviků, zobraz číslo
                if vm.exercises.count > 12 {
                    Text("+\(vm.exercises.count - 12)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer()

            // Finish button — routes through WorkoutView for proper summary
            Button {
                showFinishConfirm = true
            } label: {
                Text("Hotovo")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.09))
                            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                    )
            }
            .confirmationDialog("Ukončit trénink?", isPresented: $showFinishConfirm, titleVisibility: .visible) {
                Button("Uložit a ukončit", role: .none) { onFinish?() }
                Button("Pokračovat", role: .cancel) {}
            } message: {
                Text("Všechny zalogované série budou uloženy.")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }
}
