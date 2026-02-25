// ExerciseDatabaseLoader.swift
// Načte cviky do SwiftData při prvním spuštění aplikace.
// Primární zdroj: ExerciseDatabase.json v bundle.
// Fallback: Supabase REST API (public.exercises).

import SwiftData
import Foundation

/// Dekódovatelná struktura z ExerciseDatabase.json
private struct ExerciseJSON: Decodable {
    let slug: String
    let name: String
    let nameEN: String
    let category: String
    let movementPattern: String
    let equipment: [String]
    let musclesTarget: [String]
    let musclesSecondary: [String]
    let isUnilateral: Bool
    let instructions: String
    let breathingTip: String?
    let commonMistakes: String?
    let videoURL: String?
}

@MainActor
enum ExerciseDatabaseLoader {

    /// Seeduje databázi cviků. Pokud cviky už existují, přeskočí.
    /// 1. Zkusí načíst z JSON bundle
    /// 2. Pokud selže → stáhne ze Supabase
    static func seedIfNeeded(context: ModelContext) {
        let existingCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard existingCount == 0 else {
            AppLogger.info("ExerciseDatabaseLoader: \(existingCount) cviků již existuje, seed přeskočen.")
            return
        }

        // ── 1. Pokus: JSON bundle ──
        if seedFromBundle(context: context) {
            return
        }

        // ── 2. Fallback: Supabase REST API ──
        AppLogger.info("ExerciseDatabaseLoader: JSON v bundle nenalezen, stahuji ze Supabase...")
        Task {
            await seedFromSupabase(context: context)
        }
    }

    // MARK: - Bundle Seed

    private static func seedFromBundle(context: ModelContext) -> Bool {
        // Zkus různé varianty názvu souboru (podpora pro různé build systémy/případy)
        let candidates = [
            ("ExerciseDatabase", "json"),
            ("exercisedatabase", "json"),
            ("exercise_database", "json"),
            ("ExerciseDatabase", "JSON")
        ]

        var url: URL?
        for (name, ext) in candidates {
            if let found = Bundle.main.url(forResource: name, withExtension: ext) {
                url = found
                break
            }
        }

        guard let fileURL = url else {
            // DIAGNOSTIKA: Pokud soubor nenajdeme, vypíšeme co v bundle vůbec je.
            AppLogger.error("ExerciseDatabaseLoader: ExerciseDatabase.json nenalezen v bundle. Startuji diagnostiku obsahu...")
            listBundleContents()
            return false
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            AppLogger.error("ExerciseDatabaseLoader: Nelze přečíst data z \(fileURL.path).")
            return false
        }

        guard let exercises = try? JSONDecoder().decode([ExerciseJSON].self, from: data) else {
            AppLogger.error("ExerciseDatabaseLoader: Chyba dekódování JSON!")
            return false
        }

        insertExercises(from: exercises, context: context, source: "bundle")
        return true
    }

    // MARK: - Supabase Fallback

    @MainActor
    private static func seedFromSupabase(context: ModelContext) async {
        let repo = SupabaseExerciseRepository()
        do {
            let dtos = try await repo.fetchAll()
            guard !dtos.isEmpty else {
                AppLogger.info("ExerciseDatabaseLoader: Supabase neobsahuje žádné cviky k seedování.")
                return
            }

            var inserted = 0
            for dto in dtos {
                let exercise = Exercise(
                    slug: dto.safeSlug,
                    name: dto.safeNameCz,
                    nameEN: dto.nameEn ?? dto.safeNameCz,
                    category: ExerciseCategory(rawValue: dto.category ?? "chest") ?? .chest,
                    movementPattern: .isolation,
                    equipment: dto.equipment?.split(separator: ",").compactMap { Equipment(rawValue: String($0).trimmingCharacters(in: .whitespaces)) } ?? [],
                    musclesTarget: (dto.primaryMuscles ?? []).compactMap { MuscleGroup(rawValue: $0) },
                    musclesSecondary: (dto.secondaryMuscles ?? []).compactMap { MuscleGroup(rawValue: $0) },
                    isUnilateral: false,
                    instructions: dto.instructions ?? ""
                )
                if let gifUrl = dto.gifUrl {
                    exercise.videoURL = gifUrl
                }
                context.insert(exercise)
                inserted += 1
            }

            try context.save()
            AppLogger.info("ExerciseDatabaseLoader: Úspěšně seedováno \(inserted) cviků ze Supabase.")
        } catch {
            AppLogger.error("ExerciseDatabaseLoader: Supabase fallback selhal: \(error.localizedDescription)")
        }
    }

    // MARK: - Shared Insert

    private static func insertExercises(from jsonList: [ExerciseJSON], context: ModelContext, source: String) {
        var inserted = 0
        for json in jsonList {
            let exercise = Exercise(
                slug: json.slug,
                name: json.name,
                nameEN: json.nameEN,
                category: ExerciseCategory(rawValue: json.category) ?? .chest,
                movementPattern: MovementPattern(rawValue: json.movementPattern) ?? .isolation,
                equipment: json.equipment.compactMap { Equipment(rawValue: $0) },
                musclesTarget: json.musclesTarget.compactMap { MuscleGroup(rawValue: $0) },
                musclesSecondary: json.musclesSecondary.compactMap { MuscleGroup(rawValue: $0) },
                isUnilateral: json.isUnilateral,
                instructions: buildInstructions(json: json)
            )
            exercise.videoURL = json.videoURL
            context.insert(exercise)
            inserted += 1
        }

        do {
            try context.save()
            AppLogger.info("ExerciseDatabaseLoader: Seedováno \(inserted) cviků z \(source).")
        } catch {
            AppLogger.error("ExerciseDatabaseLoader: Chyba při ukládání: \(error)")
        }
    }

    private static func buildInstructions(json: ExerciseJSON) -> String {
        var parts: [String] = []
        if !json.instructions.isEmpty {
            parts.append(json.instructions)
        }
        if let breathing = json.breathingTip, !breathing.isEmpty {
            parts.append("🫁 Dýchání: \(breathing)")
        }
        if let mistakes = json.commonMistakes, !mistakes.isEmpty {
            parts.append("⚠️ Časté chyby: \(mistakes)")
        }
        return parts.joined(separator: "\n\n")
    }

    private static func listBundleContents() {
        let fm = FileManager.default
        let path = Bundle.main.bundlePath
        do {
            let items = try fm.contentsOfDirectory(atPath: path)
            AppLogger.info("ExerciseDatabaseLoader: Obsah Bundle.main (\(items.count) položek):")
            for item in items.prefix(50) { // Prvních 50 pro přehlednost
                AppLogger.info(" - \(item)")
            }
        } catch {
            AppLogger.error("ExerciseDatabaseLoader: Nelze vypsat obsah bundle: \(error)")
        }
    }
}
