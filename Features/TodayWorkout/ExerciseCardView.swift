// ExerciseCardView.swift
import SwiftUI
import AVFoundation

struct ExerciseCardView: View {
    let exercise: SessionExerciseState
    let exerciseIndex: Int  // Vlastní index tohoto cviku (ne vm.currentExerciseIndex!)
    @ObservedObject var vm: WorkoutViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ExerciseAnimationView(
                    slug: exercise.slug,
                    nameCz: exercise.name,
                    nameEn: exercise.exercise?.nameEN,
                    videoUrl: exercise.videoUrl   // ✅ Předáváme videoUrl z muscle_wiki_data_full
                )
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

                    // ── Postup provedení ──
                    if let instructions = exercise.exercise?.instructions,
                       !instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("POSTUP PROVEDENÍ")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white.opacity(0.35))
                                .kerning(1.5)

                            let steps = instructions.components(separatedBy: ". ").enumerated().map { ($0, $1) }
                            ForEach(steps, id: \.0) { index, step in
                                let cleanStep = step.trimmingCharacters(in: .whitespacesAndNewlines)
                                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                                if !cleanStep.isEmpty {
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.appPrimaryAccent.opacity(0.15))
                                                .frame(width: 28, height: 28)
                                            Text("\(index + 1)")
                                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                                .foregroundStyle(Color.appPrimaryAccent)
                                        }
                                        Text(cleanStep)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white.opacity(0.8))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1))
                        )
                        .padding(.horizontal, 20)
                    }
                    VStack(spacing: 10) {
                        SetHeaderRow()
                        ForEach(exercise.sets.indices, id: \.self) { i in
                            SetRowView(
                                setNumber: i + 1,
                                setData:   $vm.exercises[exerciseIndex].sets[i],
                                isActive:  i == exercise.nextIncompleteSetIndex,
                                onComplete: {
                                    HapticManager.shared.playMediumClick()
                                    vm.completeSet(
                                        exerciseIndex: exerciseIndex,
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
        .scrollDismissesKeyboard(.interactively)  // iOS 16+ - keyboard dismiss on scroll
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
    let nameCz: String
    let nameEn: String?
    var videoUrl: String? = nil   // ✅ Video (GIF) z muscle_wiki_data_full (Supabase Storage)

    var body: some View {
        ExerciseMediaView(
            gifURL: videoUrl.flatMap { URL(string: $0) },
            exerciseName: nameCz,
            exerciseNameEn: nameEn
        )
    }
}
