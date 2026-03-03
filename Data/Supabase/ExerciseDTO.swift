// ExerciseDTO.swift
// DTOs pro Supabase integraci a AI enrichment.

import Foundation

// MARK: - ExerciseDTO
// Mapuje na tabulku public.exercises.
struct ExerciseDTO: Codable, Identifiable {
    let id: UUID
    let nameCz: String
    let nameEn: String?
    let slug: String
    let category: String?
    let equipment: String?
    let primaryMuscles: [String]?
    let secondaryMuscles: [String]?
    let instructions: String?
    let instructionsMissing: Bool?
    let instructionsSource: String?
    let gifUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case nameCz               = "name_cz"
        case nameEn               = "name_en"
        case slug
        case category
        case equipment
        case primaryMuscles       = "primary_muscles"
        case secondaryMuscles     = "secondary_muscles"
        case instructions
        case instructionsMissing  = "instructions_missing"
        case instructionsSource   = "instructions_source"
        case gifUrl               = "gif_url"
    }

    // MARK: - Helpers
    // ✅ Přidáno pro kompatibilitu s ExerciseDetailViewModel
    var safeNameCz: String { nameCz }
    var safeSlug: String { slug }
    var isMissing: Bool { instructionsMissing ?? false }
}

// MARK: - AIEnrichedExerciseData
// Payload pro AI write-back do Supabase po dogenerování dat.
struct AIEnrichedExerciseData: Codable {
    let nameEn: String
    let equipment: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: String
}
