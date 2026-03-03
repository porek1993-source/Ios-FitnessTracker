// SprintGoal.swift
// Model pro cíle (User Stories) sprintu
// ✅ deepanal.pdf bod 9: "Definice cílů se Sprint Planning"

import Foundation
import SwiftData

@Model
final class SprintGoal {
    @Attribute(.unique) var id: UUID
    var title: String             // "Benchpress 80 kg"
    var goalDescription: String   // "Chci zvýšit 1RM na benchpress o 5 kg"
    var metricTarget: String      // "80 kg 1RM" nebo "3x týdně"
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    
    // Vázáno na profil
    var sprintNumber: Int
    
    init(
        title: String,
        goalDescription: String = "",
        metricTarget: String = "",
        sprintNumber: Int = 1
    ) {
        self.id = UUID()
        self.title = title
        self.goalDescription = goalDescription
        self.metricTarget = metricTarget
        self.isCompleted = false
        self.createdAt = .now
        self.sprintNumber = sprintNumber
    }
}
