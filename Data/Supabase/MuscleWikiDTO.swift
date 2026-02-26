// MuscleWikiDTO.swift
// DTO mapovaný na Supabase tabulku public.muscle_wiki_data

import Foundation

struct MuscleWikiExercise: Codable, Identifiable, Hashable {
    let name: String
    let videoUrl: String
    let muscleGroup: String
    let instructions: [String]

    /// Identifikátor — používáme `name` jako unikátní klíč.
    var id: String { name }

    /// Parsované URL videa pro AVPlayer.
    var videoURL: URL? { URL(string: videoUrl) }

    /// Lokalizovaný název svalové skupiny pro UI.
    var localizedMuscleGroup: String {
        Self.muscleGroupNames[muscleGroup.lowercased()] ?? muscleGroup.capitalized
    }

    /// Ikona SF Symbol pro svalovou skupinu.
    var muscleGroupIcon: String {
        Self.muscleGroupIcons[muscleGroup.lowercased()] ?? "figure.strengthtraining.traditional"
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case name
        case videoUrl    = "video_url"
        case muscleGroup = "muscle_group"
        case instructions
    }

    // MARK: - Lokalizace svalových skupin

    static let muscleGroupNames: [String: String] = [
        "chest": "Hrudník",
        "back": "Záda",
        "shoulders": "Ramena",
        "biceps": "Biceps",
        "triceps": "Triceps",
        "forearms": "Předloktí",
        "core": "Jádro / Břicho",
        "abs": "Břicho",
        "quadriceps": "Přední stehna",
        "quads": "Přední stehna",
        "hamstrings": "Zadní stehna",
        "glutes": "Hýždě",
        "calves": "Lýtka",
        "legs": "Nohy",
        "traps": "Trapézy",
        "lats": "Latissimus",
        "lower back": "Dolní záda",
        "upper back": "Horní záda"
    ]

    static let muscleGroupIcons: [String: String] = [
        "chest": "figure.arms.open",
        "back": "figure.walk",
        "shoulders": "figure.arms.open",
        "biceps": "figure.strengthtraining.traditional",
        "triceps": "figure.strengthtraining.traditional",
        "forearms": "hand.raised.fill",
        "core": "figure.core.training",
        "abs": "figure.core.training",
        "quadriceps": "figure.walk",
        "quads": "figure.walk",
        "hamstrings": "figure.walk",
        "glutes": "figure.walk",
        "calves": "figure.walk",
        "legs": "figure.walk",
        "traps": "figure.arms.open",
        "lats": "figure.arms.open",
        "lower back": "figure.walk",
        "upper back": "figure.walk"
    ]
}
