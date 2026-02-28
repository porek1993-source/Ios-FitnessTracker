// FatigueEntry.swift
// Definice modelů pro únavu svalů

import Foundation

enum MuscleState { case healthy, sore, fatigued, jointPain }

struct FatigueEntry: Identifiable, Codable {
    var id = UUID()
    let areaSlug: String
    let severity: Int
    let isJointPain: Bool

    var area: MuscleArea? {
        MuscleArea.all.first(where: { $0.slug == areaSlug })
    }
}
