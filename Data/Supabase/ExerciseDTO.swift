// ExerciseDTO.swift
// DTO mapovaný přímo na Supabase tabulku public.exercises

import Foundation

struct ExerciseDTO: Codable, Identifiable {
    let id: UUID?
    let slug: String?
    let nameEn: String?
    let nameCz: String?
    let category: String?
    let equipment: String?
    let primaryMuscles: [String]?
    let secondaryMuscles: [String]?
    let gifUrl: String?
    let instructions: String?
    let instructionsSource: String?
    let instructionsUpdatedAt: Date?
    let instructionsMissing: Bool?

    var safeId: UUID { id ?? UUID() }
    var safeSlug: String { slug ?? "unknown-\(safeId.uuidString.prefix(8))" }
    var safeNameCz: String { nameCz ?? "Neznámý cvik" }
    var isMissing: Bool { instructionsMissing ?? true }

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case nameEn          = "name_en"
        case nameCz          = "name_cz"
        case category
        case equipment
        case primaryMuscles  = "primary_muscles"
        case secondaryMuscles = "secondary_muscles"
        case gifUrl          = "gif_url"
        case instructions
        case instructionsSource  = "instructions_source"
        case instructionsUpdatedAt = "instructions_updated_at"
        case instructionsMissing = "instructions_missing"
    }
}

/// Výsledek AI Enrichmentu — doplněná data pro cvik s chybějícími instrukcemi.
struct AIEnrichedExerciseData: Codable {
    let nameEn: String
    let equipment: String
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: String
}
