// WorkoutPreviewView.swift
// Agilní Fitness Trenér — Náhled tréninkového plánu (bez startu session)

import SwiftUI
import SwiftData

/// Modální sheet zobrazující náhled dnešního plánu (cviky, série, cíle).
struct WorkoutPreviewView: View {

    @ObservedObject var vm: DashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @EnvironmentObject private var healthKit: HealthKitService
    @Query private var profiles: [UserProfile]

    @State private var isGenerating = false
    @State private var previewResponse: TrainerResponse?

    // Opravit chybějící exercise relationships při zobrazení
    private var repairedExercises: [PlannedExercise] {
        let exs = vm.todayPlannedExercises
        if exs.contains(where: { $0.exercise == nil }) {
            repairExercises(exs)
        }
        return exs
    }

    private func repairExercises(_ exs: [PlannedExercise]) {
        let label = vm.todayPlanLabel
        let slugMap: [String: [String]] = [
            "Push": ["barbell-bench-press", "overhead-press", "incline-dumbbell-press", "lateral-raise", "tricep-pushdown", "cable-fly-low"],
            "Pull": ["pull-up", "barbell-row", "lat-pulldown", "face-pull", "barbell-curl", "hammer-curl"],
            "Legs": ["barbell-squat", "romanian-deadlift", "leg-press", "lying-leg-curl", "leg-extension", "calf-raise"],
            "Upper A": ["barbell-bench-press", "barbell-row", "dumbbell-shoulder-press", "cable-row", "tricep-pushdown", "barbell-curl"],
            "Upper B": ["overhead-press", "pull-up", "incline-dumbbell-press", "lat-pulldown", "lateral-raise", "dumbbell-curl"],
            "Upper C": ["dumbbell-bench-press", "chest-supported-row", "arnold-press", "cable-chest-fly", "skull-crusher", "incline-dumbbell-curl"],
            "Upper": ["barbell-bench-press", "barbell-row", "dumbbell-shoulder-press", "cable-row", "tricep-pushdown", "barbell-curl"],
            "Lower A": ["barbell-squat", "romanian-deadlift", "leg-press", "lying-leg-curl", "leg-extension", "calf-raise"],
            "Lower B": ["conventional-deadlift", "bulgarian-split-squat", "hip-thrust", "lying-leg-curl", "goblet-squat", "seated-calf-raise"],
            "Lower": ["barbell-squat", "romanian-deadlift", "leg-press", "lying-leg-curl", "leg-extension", "calf-raise"],
            "Fullbody A": ["barbell-squat", "barbell-bench-press", "barbell-row", "dumbbell-shoulder-press", "plank"],
            "Fullbody B": ["romanian-deadlift", "dumbbell-bench-press", "pull-up", "lateral-raise", "ab-crunch"],
            "Fullbody C": ["goblet-squat", "incline-dumbbell-press", "cable-row", "overhead-press", "russian-twist"],
            "Fullbody": ["barbell-squat", "barbell-bench-press", "barbell-row", "dumbbell-shoulder-press", "plank"]
        ]
        let normalized = label.contains(" ") ? label : (label.components(separatedBy: " ").first ?? label)
        let lookupKey = slugMap[label] != nil ? label : normalized
        guard let slugs = slugMap[lookupKey] else { return }
        let allExercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        for (i, ex) in exs.enumerated() where ex.exercise == nil && i < slugs.count {
            if let found = allExercises.first(where: { $0.slug == slugs[i] }) {
                ex.exercise = found
            }
        }
        try? modelContext.save()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // Header
                        VStack(spacing: 6) {
                            Text("NÁHLED PLÁNU")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(.white.opacity(0.35))
                                .kerning(1.2)

                            Text(vm.todayPlanLabel)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(vm.todayPlanSplit)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.45))

                            // Stats pills
                            HStack(spacing: 12) {
                                StatPill(icon: "timer",        value: "\(vm.estimatedMinutes)", unit: "min",   color: .blue)
                                StatPill(icon: "scalemass",    value: "\(vm.exerciseCount)",   unit: "cviků",  color: .purple)
                            }
                            .padding(.top, 6)
                        }
                        .padding(.top, 28)
                        .padding(.bottom, 24)

                        // Exercise list
                        if isGenerating {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(.blue)
                                Text("iKorba připravuje plán na míru...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.blue)
                            }
                            .padding(.top, 40)
                            .padding(.bottom, 20)
                        } else if let response = previewResponse {
                            VStack(spacing: 12) {
                                ForEach(Array(response.mainBlocks.flatMap { $0.exercises }.enumerated()), id: \.offset) { idx, ex in
                                     AIPreviewExerciseRow(index: idx + 1, exercise: ex)
                                }
                            }
                            .padding(.horizontal, 18)
                        } else if !repairedExercises.isEmpty {
                            VStack(spacing: 16) {
                                Button {
                                    generatePreview()
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "wand.and.sparkles")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Získat AI rozpis přesně na míru")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(red: 0.20, green: 0.52, blue: 1.0),
                                                             Color(red: 0.08, green: 0.35, blue: 0.85)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing)
                                            )
                                    )
                                    .shadow(color: .blue.opacity(0.4), radius: 10, y: 4)
                                }
                                .padding(.horizontal, 18)

                                VStack(spacing: 12) {
                                    ForEach(Array(repairedExercises.enumerated()), id: \.offset) { idx, ex in
                                        PlannedExerciseRow(index: idx + 1, exercise: ex)
                                    }
                                }
                                .padding(.horizontal, 18)
                            }
                        } else {
                            emptyState
                        }

                        // Info footer
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(.blue.opacity(0.6))
                            Text("AI může plán upravit před zahájením tréninku podle tvé připravenosti.")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .padding(16)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zavřít") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run.square.stack")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.2))
            Text("Plán se načte při zahájení tréninku")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.top, 60)
    }

    private func generatePreview() {
        guard let profile = profiles.first else { return }
        
        let dayIndex = Date.now.weekday
        guard let activePlan = profile.workoutPlans.first(where: { $0.isActive }),
              let plannedDay = activePlan.scheduledDays.first(where: { $0.dayOfWeek == dayIndex && !$0.isRestDay }) else {
            return
        }

        isGenerating = true
        Task {
            let aiService = AITrainerService(modelContext: modelContext, healthKitService: healthKit)
            let response = await aiService.generateTodayWorkout(
                for: .now,
                profile: profile,
                plannedDay: plannedDay,
                equipmentOverride: nil,
                timeLimitMinutes: nil
            )
            
            await MainActor.run {
                self.previewResponse = response
                self.isGenerating = false
            }
        }
    }
}

// MARK: - StatPill

private struct StatPill: View {
    let icon: String; let value: String; let unit: String; let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text("\(value) \(unit)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.10))
                .overlay(Capsule().stroke(color.opacity(0.18), lineWidth: 1))
        )
    }
}

// MARK: - Planned Exercise Row

private struct PlannedExerciseRow: View {
    let index: Int
    let exercise: PlannedExercise

    var body: some View {
        HStack(spacing: 14) {
            // Index badge with muscle icon
            ZStack {
                Circle()
                    .fill(AppColors.primaryAccent.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                if let _ = exercise.exercise?.musclesTarget.first {
                    // Cvik má známý sval
                    Text("\(index)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primaryAccent)
                } else {
                    Text("\(index)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primaryAccent)
                }
            }

            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                let displayName = exercise.exercise?.name ?? 
                                  exercise.fallbackName ?? 
                                  exercise.fallbackSlug.map { "🔍 Nastavuji... (\($0))" } ?? 
                                  "Neznámý cvik \(index)"
                
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(exercise.exercise != nil ? .white : .orange.opacity(0.9))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    // Sets × Reps
                    Label(
                        "\(exercise.targetSets)×\(exercise.targetRepsMin)-\(exercise.targetRepsMax)",
                        systemImage: "repeat"
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))

                    // Rest
                    if exercise.restSeconds > 0 {
                        Label("\(exercise.restSeconds)s", systemImage: "timer")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.35))
                    }

                    // RIR
                    if exercise.targetRIR >= 0 {
                        Label("RIR \(exercise.targetRIR)", systemImage: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.30))
                    }
                }

                // Last used weight
                if let lastWeight = exercise.exercise?.lastUsedWeight, lastWeight > 0 {
                    Text("Poslední váha: \(Int(lastWeight)) kg")
                        .font(.system(size: 11))
                        .foregroundStyle(.blue.opacity(0.60))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.secondaryBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        )
    }
}

// MARK: - AI Preview Exercise Row

private struct AIPreviewExerciseRow: View {
    let index: Int
    let exercise: ResponseExercise

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.15)).frame(width: 36, height: 36)
                Text("\(index)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                HStack(spacing: 10) {
                    Label("\(exercise.sets)×\(exercise.repsMin)-\(exercise.repsMax)", systemImage: "repeat")
                    if exercise.restSeconds > 0 { Label("\(exercise.restSeconds)s", systemImage: "timer") }
                }
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                
                if let weight = exercise.weightKg, weight > 0 {
                    Text("Doporučená váha: \(Int(weight)) kg").font(.system(size: 11, weight: .bold)).foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.secondaryBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
