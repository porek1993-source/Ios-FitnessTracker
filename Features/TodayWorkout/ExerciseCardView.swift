// ExerciseCardView.swift
import SwiftUI

struct ExerciseCardView: View {
    let exercise: SessionExerciseState
    @ObservedObject var vm: WorkoutViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ExerciseAnimationView(slug: exercise.slug)
                    .frame(height: 260)

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text(exercise.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        if let tip = exercise.coachTip {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.system(size: 13))
                                    .padding(.top, 1)
                                Text(tip)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.yellow.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.yellow.opacity(0.2), lineWidth: 1))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    TechTipsRow(exercise: exercise)
                        .padding(.horizontal, 20)

                    VStack(spacing: 10) {
                        SetHeaderRow()
                        ForEach(exercise.sets.indices, id: \.self) { i in
                            SetRowView(
                                setNumber: i + 1,
                                setData:   $vm.exercises[vm.currentExerciseIndex].sets[i],
                                isActive:  i == exercise.nextIncompleteSetIndex,
                                onComplete: {
                                    vm.completeSet(
                                        exerciseIndex: vm.currentExerciseIndex,
                                        setIndex: i
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    Button { vm.skipExercise() } label: {
                        Label("Přeskočit cvik", systemImage: "forward.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Tech Tips

struct TechTipsRow: View {
    let exercise: SessionExerciseState
    var body: some View {
        HStack(spacing: 10) {
            if let tempo = exercise.tempo {
                TechBadge(icon: "metronome.fill", label: "Tempo", value: tempo, color: .blue)
            }
            TechBadge(icon: "wind", label: "Dýchání", value: "Výdech při zdvihu", color: .teal)
            if exercise.restSeconds > 0 {
                TechBadge(icon: "timer", label: "Pauza", value: "\(exercise.restSeconds)s", color: .orange)
            }
        }
    }
}

struct TechBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 12))
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .kerning(0.8)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.1)))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Exercise Animation

struct ExerciseAnimationView: View {
    let slug: String
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.08), Color.black], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 12) {
                Image(systemName: exerciseIcon(slug))
                    .font(.system(size: 64))
                    .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.pulse)
                Text("animace cviku")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.2))
            }
            LinearGradient(colors: [.clear, .black], startPoint: .init(x: 0.5, y: 0.6), endPoint: .bottom)
        }
    }

    private func exerciseIcon(_ slug: String) -> String {
        if slug.contains("bench") || slug.contains("press") { return "dumbbell.fill" }
        if slug.contains("squat") || slug.contains("leg")   { return "figure.strengthtraining.traditional" }
        if slug.contains("pull") || slug.contains("row")    { return "figure.gymnastics" }
        if slug.contains("run")  || slug.contains("cardio") { return "figure.run" }
        return "figure.core.training"
    }
}
