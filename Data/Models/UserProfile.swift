// UserProfile.swift

import SwiftData
import Foundation

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var dateOfBirth: Date
    var gender: Gender

    var heightCm: Double
    var weightKg: Double

    var primaryGoal: FitnessGoal
    var fitnessLevel: FitnessLevel
    
    // AI Adaptation flags
    var isDeloadRecommended: Bool = false

    // ✅ Phase 4: Klinická data — zranění a životní omezení
    /// Seznam zranění / bolestí (výstup z Onboarding V2 chatu)
    /// Příklad: ["levé rameno", "bederní páteř"]
    var injuries: [String]? = []
    /// Životní omezení — stres, sedavá práce, spánek, čas
    /// Příklad: ["sedavé zaměstnání 8h/den", "chronický stres", "5–6 hodin spánku"]
    var lifestyleConstraints: [String]? = []
    /// Volný text pro speciální medicínské poznámky / výjimky
    var medicalNotes: String? = nil

    var availableDaysPerWeek: Int
    var preferredSplitType: SplitType
    var sessionDurationMinutes: Int

    var currentLocation: String?
    var availableEquipment: [Equipment]
    var primarySport: String?   // Primární sport (fotbal, tenis…) pro sportovní výkon

    var healthKitAuthorized: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var workoutPlans: [WorkoutPlan]

    @Relationship(deleteRule: .cascade)
    var healthMetricsHistory: [HealthMetricsSnapshot]
    
    @Relationship(deleteRule: .cascade)
    var machineNotes: [ExerciseNote]

    init(
        name: String,
        dateOfBirth: Date = .now,
        gender: Gender = .other,
        heightCm: Double = 175,
        weightKg: Double = 75,
        primaryGoal: FitnessGoal = .hypertrophy,
        fitnessLevel: FitnessLevel = .intermediate,
        availableDaysPerWeek: Int = 4,
        preferredSplitType: SplitType = .ppl,
        sessionDurationMinutes: Int = 60
    ) {
        self.id = UUID()
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.primaryGoal = primaryGoal
        self.fitnessLevel = fitnessLevel
        self.availableDaysPerWeek = availableDaysPerWeek
        self.preferredSplitType = preferredSplitType
        self.sessionDurationMinutes = sessionDurationMinutes
        self.currentLocation = "gym"
        self.availableEquipment = [.barbell, .dumbbell, .cable, .machine]
        self.primarySport = nil
        self.injuries = []
        self.lifestyleConstraints = []
        self.medicalNotes = nil
        self.healthKitAuthorized = false
        self.createdAt = .now
        self.updatedAt = .now
        self.workoutPlans = []
        self.healthMetricsHistory = []
        self.machineNotes = []
    }
}

@Model
final class ExerciseNote {
    @Attribute(.unique) var id: UUID
    var exerciseSlug: String
    var note: String
    var updatedAt: Date
    
    init(exerciseSlug: String, note: String) {
        self.id = UUID()
        self.exerciseSlug = exerciseSlug
        self.note = note
        self.updatedAt = .now
    }
}

enum FitnessGoal: String, Codable, CaseIterable {
    case strength       = "strength"
    case hypertrophy    = "hypertrophy"
    case weightLoss     = "weightLoss"
    case endurance      = "endurance"
    case maintenance    = "maintenance"
    case sportsPerf     = "sportsPerf"

    var displayName: String {
        switch self {
        case .strength:    return "Síla"
        case .hypertrophy: return "Objem (Hypertrofie)"
        case .weightLoss:  return "Hubnutí"
        case .endurance:   return "Vytrvalost / Kondice"
        case .maintenance: return "Udržování formy"
        case .sportsPerf:  return "Sportovní výkon"
        }
    }

    var description: String {
        switch self {
        case .strength:    return "Maximální síla, nízká opakování (1–5)"
        case .hypertrophy: return "Růst svalů, střední opakování (8–12)"
        case .weightLoss:  return "Hubnutí, vyšší intenzita a kardio"
        case .endurance:   return "Kardio kondice a svalová vytrvalost"
        case .maintenance: return "Udržení stávající formy a zdraví"
        case .sportsPerf:  return "Doplněk k primárnímu sportu"
        }
    }

    var icon: String {
        switch self {
        case .strength:    return "bolt.fill"
        case .hypertrophy: return "figure.strengthtraining.traditional"
        case .weightLoss:  return "flame.fill"
        case .endurance:   return "heart.fill"
        case .maintenance: return "checkmark.seal.fill"
        case .sportsPerf:  return "sportscourt.fill"
        }
    }
}

enum FitnessLevel: String, Codable, CaseIterable {
    case beginner     = "beginner"
    case intermediate = "intermediate"
    case advanced     = "advanced"

    var displayName: String {
        switch self {
        case .beginner:     return "Začátečník"
        case .intermediate: return "Pokročilý"
        case .advanced:     return "Expert"
        }
    }

    var icon: String {
        switch self {
        case .beginner:     return "figure.walk"
        case .intermediate: return "figure.strengthtraining.traditional"
        case .advanced:     return "flame.fill"
        }
    }

    var description: String {
        switch self {
        case .beginner:     return "Méně než 1 rok pravidelného cvičení"
        case .intermediate: return "1–3 roky, znám základní techniky"
        case .advanced:     return "Více než 3 roky, trénuji systematicky"
        }
    }
}

enum Gender: String, Codable, CaseIterable {
    case male   = "male"
    case female = "female"
    case other  = "other"
}

enum SplitType: String, Codable, CaseIterable {
    case fullBody    = "fullBody"
    case upperLower  = "upperLower"
    case ppl         = "ppl"

    var displayName: String {
        switch self {
        case .fullBody:   return "Fullbody"
        case .upperLower: return "Upper / Lower"
        case .ppl:        return "Push / Pull / Legs"
        }
    }
}

// Equipment enum je nyní v Data/Models/Exercise.swift
