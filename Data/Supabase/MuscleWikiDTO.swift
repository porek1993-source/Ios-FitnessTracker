// MuscleWikiDTO.swift
// DTO mapovaný na Supabase tabulku public.muscle_wiki_data_full
//
// OPRAVY v2.0:
//  ✅ Přidáno pole equipment (sloupec v tabulce byl ignorován)
//  ✅ Přidán překlad a ikona pro muscle_group "front-shoulders"
//  ✅ Přidán equipmentMap pro mapování CZ názvů na Equipment enum
//  ✅ Přidána computed property mappedEquipment

import Foundation
import SwiftUI

struct MuscleWikiExercise: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let videoUrl: String
    let muscleGroup: String
    let equipment: String?
    let instructions: [String]
    let difficulty: String?
    let exerciseType: String?
    let grip: String?

    var videoURL: URL? { URL(string: videoUrl) }

    var localizedMuscleGroup: String {
        Self.muscleGroupNames[muscleGroup.lowercased()] ?? muscleGroup.capitalized
    }

    var muscleGroupIcon: String {
        Self.muscleGroupIcons[muscleGroup.lowercased()] ?? "figure.strengthtraining.traditional"
    }

    /// Mapuje CZ equipment string na Equipment enum.
    var mappedEquipment: Equipment? {
        guard let eq = equipment else { return nil }
        return Self.equipmentMap[eq]
    }

    // MARK: - Chip Helpers
    // POZNÁMKA: Equipment se zobrazuje v header sekci detail view — zde záměrně vynecháno.

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
        case equipment
        case instructions
        case difficulty
        case exerciseType = "exercise_type"
        case grip
    }

    // MARK: - Difficulty Mapping

    private static func difficultyIcon(_ value: String) -> String {
        switch value.lowercased() {
        case "beginner", "začátečník":             return "leaf.fill"
        case "intermediate", "střední":            return "flame.fill"
        case "advanced", "pokročilý", "moderní",
             "expert":                             return "bolt.fill"
        case "nováček":                            return "star.fill"
        default:                                   return "star.fill"
        }
    }

    private static func difficultyColor(_ value: String) -> Color {
        switch value.lowercased() {
        case "beginner", "začátečník", "nováček":  return .green
        case "intermediate", "střední":            return .yellow
        case "advanced", "pokročilý", "moderní",
             "expert":                             return .red
        default:                                   return .purple
        }
    }

    // MARK: - Equipment Icon
    // POZOR: Používáme pouze SF Symbols kompatibilní s iOS 17+
    // "dumbbell" existuje od iOS 16, "dumbbell.fill" pouze od iOS 18 → nepoužíváme

    private static func equipmentIcon(_ value: String) -> String {
        switch value {
        case "Jednoručka":    return "scalemass.fill"           // iOS 14+
        case "Velká činka":   return "figure.strengthtraining.traditional" // iOS 16+
        case "Vlastní váha":  return "figure.walk"
        case "Stroj":         return "gearshape.fill"
        case "Kladka":        return "arrow.up.and.down.circle.fill"
        case "Kettlebell":    return "circle.fill"
        case "Odporová guma": return "arrow.left.and.right.circle.fill"
        case "TRX":           return "rectangle.and.arrow.up.right.and.arrow.down.left"
        case "Bosu":          return "oval.fill"
        case "Kotouč":        return "record.circle.fill"
        case "Medicimbal":    return "circle.circle.fill"
        case "Kardio":        return "heart.fill"
        default:              return "wrench.fill"
        }
    }

    // MARK: - Equipment Map (CZ → Equipment enum)

    static let equipmentMap: [String: Equipment] = [
        "Jednoručka":    .dumbbell,
        "Velká činka":   .barbell,
        "Vlastní váha":  .bodyweight,
        "Stroj":         .machine,
        "Kladka":        .cable,
        "Kettlebell":    .kettlebell,
        "Odporová guma": .resistanceBand,
        "TRX":           .trx,
        "Kotouč":        .barbell,
        "Bosu":          .bodyweight,
        "Medicimbal":    .kettlebell,
        "Kardio":        .bodyweight,
        "Jiné":          .bodyweight
    ]

    // MARK: - Lokalizace svalových skupin

    static let muscleGroupNames: [String: String] = [
        // ── Nové Supabase klíče (16 svalů) ──
        "traps":           "Trapézy",
        "front-shoulders": "Přední ramena",
        "chest":           "Hrudník",
        "biceps":          "Biceps",
        "forearms":        "Předloktí",
        "obliques":        "Šikmé svaly břišní",
        "abdominals":      "Břicho",
        "quads":           "Přední stehna",
        "calves":          "Lýtka",
        "rear-shoulders":  "Zadní ramena",
        "triceps":         "Triceps",
        "lats":            "Široký sval zádový",
        "traps-middle":    "Střední záda",
        "lowerback":       "Spodní záda",
        "hamstrings":      "Zadní stehna",
        "glutes":          "Hýždě",
        // ── Starší / alternativní klíče (zpětná kompatibilita) ──
        "back":            "Záda",
        "shoulders":       "Ramena",
        "abs":             "Břicho",
        "core":            "Jádro / Břicho",
        "quadriceps":      "Přední stehna",
        "legs":            "Nohy",
        "lats-upper":      "Horní záda (Lats)",
        "lower back":      "Spodní záda",
        "upper back":      "Střední záda",
        "full body":       "Celé tělo",
        "cardio":          "Kardio"
    ]

    static let muscleGroupIcons: [String: String] = [
        "traps":           "figure.arms.open",
        "front-shoulders": "figure.arms.open",
        "chest":           "figure.arms.open",
        "biceps":          "figure.strengthtraining.traditional",
        "forearms":        "hand.raised.fill",
        "obliques":        "figure.core.training",
        "abdominals":      "figure.core.training",
        "quads":           "figure.run",
        "calves":          "figure.run",
        "rear-shoulders":  "figure.arms.open",
        "triceps":         "figure.strengthtraining.traditional",
        "lats":            "figure.arms.open",
        "traps-middle":    "figure.walk",
        "lowerback":       "figure.walk",
        "hamstrings":      "figure.run",
        "glutes":          "figure.run",
        // Starší
        "back":            "figure.walk",
        "shoulders":       "figure.arms.open",
        "abs":             "figure.core.training",
        "core":            "figure.core.training",
        "quadriceps":      "figure.run",
        "legs":            "figure.run",
        "lower back":      "figure.walk",
        "upper back":      "figure.walk",
        "full body":       "figure.strengthtraining.traditional",
        "cardio":          "heart.fill"
    ]
}

// MARK: - Static Helpers

extension MuscleWikiExercise {
    static func localizedName(for group: String) -> String {
        muscleGroupNames[group.lowercased()] ?? group.capitalized
    }

    static func icon(for group: String) -> String {
        muscleGroupIcons[group.lowercased()] ?? "figure.strengthtraining.traditional"
    }
}
