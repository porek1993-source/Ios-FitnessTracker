// WorkoutPreviewSheet.swift
import SwiftUI
import SwiftData

struct WorkoutPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allExercises: [Exercise]
    
    let day: PlannedWorkoutDay
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text(day.label.uppercased())
                                .overlineStyle()
                            Text("Předběžný náhled")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Prozkoumej techniku a cviky předem.")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 20)
                        
                        // Exercise List
                        VStack(spacing: 12) {
                            let sortedExercises = day.plannedExercises.sorted(by: { $0.order < $1.order })
                            
                            if sortedExercises.isEmpty {
                                emptyExercisesState
                            } else {
                                ForEach(sortedExercises) { planned in
                                    WorkoutPreviewRow(planned: planned, allExercises: allExercises)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zavřít") { dismiss() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.primaryAccent)
                }
            }
        }
    }
    
    private var emptyExercisesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.blue.opacity(0.4))
            Text("Cviky budou vygenerovány AI při startu tréninku na základě tvého aktuálního stavu.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
    }
}

struct WorkoutPreviewRow: View {
    let planned: PlannedExercise
    let allExercises: [Exercise]
    @State private var showingDetail = false
    
    // Dynamické navázání ze @Query (funguje i po zpožděném nahrání z cloudu)
    private var resolvedExercise: Exercise? {
        if let ex = planned.exercise { return ex }
        if let slug = planned.fallbackSlug {
            return allExercises.first(where: { $0.slug == slug })
        }
        return nil
    }
    
    var body: some View {
        Button { showingDetail = true } label: {
            HStack(spacing: 16) {
                // Exercise Image/Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.cardBg)
                        .frame(width: 56, height: 56)
                    
                    if let videoURL = resolvedExercise?.videoURL, !videoURL.isEmpty {
                        Image(systemName: "video.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppColors.primaryAccent)
                    } else {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 22))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(resolvedExercise?.name ?? planned.fallbackName ?? "Neznámý cvik")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("\(planned.targetSets) série")
                        Text("•")
                        Text("\(planned.targetRepsMin)-\(planned.targetRepsMax) opak.")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.15))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            if let exercise = resolvedExercise {
                ExercisePreviewDetailWrapper(exercise: exercise)
            }
        }
    }
}

struct ExercisePreviewDetailWrapper: View {
    let exercise: Exercise
    @State private var wikiExercise: MuscleWikiExercise?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let wiki = wikiExercise {
                MuscleWikiDetailView(exercise: wiki)
            } else if isLoading {
                ZStack {
                    AppColors.background.ignoresSafeArea()
                    ProgressView("Načítám detail cviku…")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            } else {
                ZStack {
                    AppColors.background.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Detail cviku se nepodařilo načíst.")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .task {
            let repo = SupabaseExerciseRepository()
            do {
                let all = try await repo.fetchMuscleWikiAll()
                wikiExercise = all.first(where: { 
                    $0.name.lowercased() == exercise.nameEN.lowercased() || 
                    $0.videoUrl == exercise.videoURL ||
                    $0.name.lowercased().replacingOccurrences(of: " ", with: "-") == exercise.slug.lowercased()
                })
            } catch {
                AppLogger.error("Chyba při načítání detailu pro náhled: \(error)")
            }
            isLoading = false
        }
    }
}
