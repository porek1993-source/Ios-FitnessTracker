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
    var availableDaysPerWeek: Int
    var preferredSplitType: SplitType
    var sessionDurationMinutes: Int

    var currentLocation: String?
    var availableEquipment: [Equipment]

    var healthKitAuthorized: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var workoutPlans: [WorkoutPlan]

    @Relationship(deleteRule: .cascade)
    var healthMetricsHistory: [HealthMetricsSnapshot]

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
        self.healthKitAuthorized = false
        self.createdAt = .now
        self.updatedAt = .now
        self.workoutPlans = []
        self.healthMetricsHistory = []
    }
}

enum FitnessGoal: String, Codable, CaseIterable {
    case strength     = "strength"
    case hypertrophy  = "hypertrophy"
    case weightLoss   = "weightLoss"
    case endurance    = "endurance"

    var displayName: String {
        switch self {
        case .strength:    return "Síla"
        case .hypertrophy: return "Objem (Hypertrofie)"
        case .weightLoss:  return "Hubnutí"
        case .endurance:   return "Vytrvalost"
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
