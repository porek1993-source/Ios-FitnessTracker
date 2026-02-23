// ExerciseDTO.swift
// DTO mapovaný přímo na Supabase tabulku public.exercises

import Foundation

struct ExerciseDTO: Codable, Identifiable {
    let slug: String
    let nameEn: String?
    let nameCz: String
    let category: String?
    let equipment: String?
    let primaryMuscles: [String]?
    let instructions: String?
    let instructionsMissing: Bool

    var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug
        case nameEn          = "name_en"
        case nameCz          = "name_cz"
        case category
        case equipment
        case primaryMuscles  = "primary_muscles"
        case instructions
        case instructionsMissing = "instructions_missing"
    }
}

/// Výsledek AI Enrichmentu — doplněná data pro cvik s chybějícími instrukcemi.
struct AIEnrichedExerciseData: Codable {
    let equipment: String
    let primaryMuscles: [String]
    let instructions: String
}
