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

// MARK: - WorkoutPreviewRow

struct WorkoutPreviewRow: View {
    let planned: PlannedExercise
    let allExercises: [Exercise]
    @State private var showingDetail = false
    
    // ✅ FIX Bug #3: Vylepšené hledání — normalizovaný slug + fallback přes nameEN/fallbackName
    private var resolvedExercise: Exercise? {
        if let ex = planned.exercise { return ex }
        
        if let slug = planned.fallbackSlug {
            let normalizedSlug = FallbackWorkoutGenerator.normalizedSlug(slug)
            if let found = allExercises.first(where: {
                $0.slug == slug || $0.slug == normalizedSlug
            }) { return found }
        }
        
        if let name = planned.fallbackName {
            let nameLower = name.lowercased()
            if let found = allExercises.first(where: {
                $0.name.lowercased() == nameLower ||
                $0.nameEN.lowercased() == nameLower ||
                $0.name.lowercased().contains(nameLower) ||
                $0.nameEN.lowercased().contains(nameLower)
            }) { return found }
        }
        
        return nil
    }
    
    /// ✅ FIX Bug #3: Vždy vrátí smysluplné jméno
    private var displayName: String {
        resolvedExercise?.name
            ?? planned.fallbackName
            ?? planned.fallbackSlug?.replacingOccurrences(of: "-", with: " ").capitalized
            ?? "Cvik \(planned.order + 1)"
    }
    
    var body: some View {
        Button { showingDetail = true } label: {
            HStack(spacing: 16) {
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
                    Text(displayName)
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
        // ✅ FIX Bug #4: Sheet vždy zobrazí obsah — Exercise nebo FallbackDetail
        .sheet(isPresented: $showingDetail) {
            if let exercise = resolvedExercise {
                ExercisePreviewDetailWrapper(exercise: exercise)
            } else {
                ExerciseFallbackDetailView(
                    name: displayName,
                    sets: planned.targetSets,
                    repsMin: planned.targetRepsMin,
                    repsMax: planned.targetRepsMax
                )
            }
        }
    }
}

// MARK: - ExercisePreviewDetailWrapper

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
                // ✅ FIX Bug #4: Základní info i bez MuscleWiki záznamu
                ExerciseFallbackDetailView(
                    name: exercise.name,
                    sets: nil,
                    repsMin: nil,
                    repsMax: nil,
                    instructions: exercise.instructions.isEmpty ? nil : exercise.instructions,
                    videoURL: exercise.videoURL
                )
            }
        }
        .task {
            let repo = SupabaseExerciseRepository()
            do {
                let all = try await repo.fetchMuscleWikiAll()
                let nameLower = exercise.nameEN.lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)
                let slugClean = exercise.slug.lowercased().replacingOccurrences(of: "-", with: "")
                
                wikiExercise = all.first(where: { wiki in
                    let wikiLower = wiki.name.lowercased()
                        .folding(options: .diacriticInsensitive, locale: .current)
                    let wikiSlug = wikiLower.replacingOccurrences(of: " ", with: "")
                    return wikiLower == nameLower
                        || wiki.videoUrl == exercise.videoURL
                        || wikiSlug == slugClean
                        || wikiLower.contains(nameLower)
                        || nameLower.contains(wikiLower)
                })
            } catch {
                AppLogger.error("Chyba při načítání detailu pro náhled: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - ExerciseFallbackDetailView
// ✅ FIX Bug #4: Zobrazí základní info i bez MuscleWiki záznamu nebo Exercise reference.

struct ExerciseFallbackDetailView: View {
    let name: String
    var sets: Int?
    var repsMin: Int?
    var repsMax: Int?
    var instructions: String? = nil
    var videoURL: String? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ExerciseMediaView(
                            gifURL: videoURL.flatMap { URL(string: $0) },
                            exerciseName: name,
                            exerciseNameEn: name
                        )
                        .padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text(name)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            if let sets = sets, let repsMin = repsMin, let repsMax = repsMax {
                                HStack(spacing: 12) {
                                    Label("\(sets) série", systemImage: "repeat")
                                    Label("\(repsMin)–\(repsMax) opakování", systemImage: "number")
                                }
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            if let instructions = instructions {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("INSTRUKCE")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .kerning(1.4)
                                    Text(instructions)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.white.opacity(0.8))
                                        .lineSpacing(4)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AppColors.cardBg)
                                        .overlay(RoundedRectangle(cornerRadius: 14)
                                            .stroke(AppColors.border, lineWidth: 1))
                                )
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(.blue.opacity(0.7))
                                    Text("Detail cviku bude dostupný po synchronizaci s databází.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.cardBg))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zavřít") { dismiss() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.primaryAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
