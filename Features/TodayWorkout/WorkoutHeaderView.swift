// WorkoutHeaderView.swift
import SwiftUI

struct WorkoutHeaderView: View {
    @ObservedObject var vm: WorkoutViewModel

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ČAS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .kerning(1.5)
                Text(vm.elapsedTimeFormatted)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(vm.exercises.indices, id: \.self) { i in
                    Circle()
                        .fill(progressDotColor(index: i))
                        .frame(
                            width:  i == vm.currentExerciseIndex ? 8 : 5,
                            height: i == vm.currentExerciseIndex ? 8 : 5
                        )
                        .animation(.spring(response: 0.3), value: vm.currentExerciseIndex)
                }
            }

            Spacer()

            Button { vm.finishWorkout() } label: {
                Text("Dokončit")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func progressDotColor(index: Int) -> Color {
        if index < vm.currentExerciseIndex  { return .green }
        if index == vm.currentExerciseIndex { return .white }
        return .white.opacity(0.25)
    }
}
