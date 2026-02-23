// WorkoutView.swift
import SwiftUI

struct WorkoutView: View {
    @StateObject private var vm: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss

    init(session: WorkoutSession, plan: PlannedWorkoutDay, planLabel: String) {
        _vm = StateObject(wrappedValue: WorkoutViewModel(session: session, plan: plan, planLabel: planLabel))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                WorkoutHeaderView(vm: vm)

                TabView(selection: $vm.currentExerciseIndex) {
                    ForEach(vm.exercises.indices, id: \.self) { index in
                        ExerciseCardView(exercise: vm.exercises[index], vm: vm)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: vm.currentExerciseIndex)
            }

            if vm.isResting {
                RestTimerOverlay(vm: vm)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal:   .opacity
                    ))
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
    }
}
