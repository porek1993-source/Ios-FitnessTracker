// MuscleWikiDTO.swift
// DTO mapovaný na Supabase tabulku public.muscle_wiki_data

import Foundation
import SwiftUI

struct MuscleWikiExercise: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let videoUrl: String
    let muscleGroup: String
    let instructions: [String]
    let difficulty: String?
    let exerciseType: String?
    let grip: String?

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

    // MARK: - Chip Helpers

    /// Všechny dostupné chipy pro detail view (pouze non-nil hodnoty).
    var chips: [ExerciseChip] {
        var result: [ExerciseChip] = []
        if let difficulty {
            result.append(ExerciseChip(
                label: difficulty,
                icon: Self.difficultyIcon(difficulty),
                color: Self.difficultyColor(difficulty)
            ))
        }
        if let exerciseType {
            result.append(ExerciseChip(
                label: exerciseType,
                icon: "arrow.triangle.branch",
                color: .cyan
            ))
        }
        if let grip {
            result.append(ExerciseChip(
                label: grip,
                icon: "hand.raised.fill",
                color: .orange
            ))
        }
        return result
    }

    struct ExerciseChip: Hashable, Sendable {
        let label: String
        let icon: String
        let color: Color
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case videoUrl     = "video_url"
        case muscleGroup  = "muscle_group"
        case instructions
        case difficulty
        case exerciseType = "exercise_type"
        case grip
    }

    // MARK: - Difficulty Mapping

    private static func difficultyIcon(_ value: String) -> String {
        switch value.lowercased() {
        case "beginner", "začátečník":   return "leaf.fill"
        case "intermediate", "pokročilý": return "flame.fill"
        case "advanced", "expert":        return "bolt.fill"
        default:                          return "star.fill"
        }
    }

    private static func difficultyColor(_ value: String) -> Color {
        switch value.lowercased() {
        case "beginner", "začátečník":   return .green
        case "intermediate", "pokročilý": return .yellow
        case "advanced", "expert":        return .red
        default:                          return .purple
        }
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

// MARK: - Static Helpers

extension MuscleWikiExercise {
    /// Statický helper pro lokalizaci — použitelný i bez instance.
    static func localizedName(for group: String) -> String {
        muscleGroupNames[group.lowercased()] ?? group.capitalized
    }
}
