import SwiftData
import Foundation

// MARK: - Challenge Models

enum ChallengeType: String, Codable {
    case weekendSprint = "Víkendový sprint"
    case monthlyMarathon = "Měsíční maraton"
    case yearlyVolume = "Roční objemovka"
    case custom = "Vlastní výzva"
}

enum ChallengeMetric: String, Codable {
    case calories = "Spálené kcal"
    case volume = "Nazvedaný objem"
    case workouts = "Počet tréninků"
    case xp = "Získané XP"
}

@Model
final class Challenge {
    var id: UUID = UUID()
    var title: String
    var challengeDescription: String
    var type: ChallengeType
    var metric: ChallengeMetric
    var startDate: Date
    var endDate: Date
    
    // Supabase napojení (volitelné pro synchronizaci)
    var remoteId: String?
    
    @Relationship(deleteRule: .cascade)
    var participants: [ChallengeParticipant] = []
    
    init(title: String, description: String, type: ChallengeType, metric: ChallengeMetric, startDate: Date, endDate: Date) {
        self.title = title
        self.challengeDescription = description
        self.type = type
        self.metric = metric
        self.startDate = startDate
        self.endDate = endDate
    }
    
    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    var isFinished: Bool {
        return Date() > endDate
    }
}

@Model
final class ChallengeParticipant {
    var id: UUID = UUID()
    var userId: String // Auth ID z AuthManager.shared.currentUser?.id.uuidString nebo lokální identifikátor
    var displayName: String
    var avatarUrl: String?
    var currentScore: Double = 0
    var joinedAt: Date = Date()
    
    @Relationship(inverse: \Challenge.participants)
    var challenge: Challenge?
    
    init(userId: String, displayName: String, currentScore: Double = 0) {
        self.userId = userId
        self.displayName = displayName
        self.currentScore = currentScore
    }
}
