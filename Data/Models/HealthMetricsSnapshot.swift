// HealthMetricsSnapshot.swift

import SwiftData
import Foundation

@Model
final class HealthMetricsSnapshot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var createdAt: Date

    var sleepDurationHours: Double?
    var sleepDeepHours: Double?
    var sleepREMHours: Double?
    var sleepEfficiencyPct: Double?

    var restingHeartRate: Double?
    var heartRateVariabilityMs: Double?
    var avgRespiratoryRate: Double?
    var oxygenSaturationPct: Double?

    var hrvBaselineAvg: Double?
    var restingHRBaseline: Double?

    var activeCaloriesKcal: Double?
    var totalSteps: Int?
    var exerciseMinutes: Int?
    var standHours: Int?

    var externalActivities: [ExternalActivity]

    var readinessScore: Double?
    var readinessComponents: ReadinessComponents?

    @Relationship(inverse: \UserProfile.healthMetricsHistory)
    var userProfile: UserProfile?

    init(date: Date) {
        self.id = UUID()
        self.date = date
        self.createdAt = .now
        self.externalActivities = []
    }
}

struct ExternalActivity: Codable, Hashable {
    var type: String
    var durationMinutes: Int
    var energyKcal: Double
    var startedAt: Date
}

struct ReadinessComponents: Codable, Hashable {
    var sleepScore: Double      // váha 40 %
    var hrvScore: Double        // váha 30 %
    var restingHRScore: Double  // váha 20 %
    var activityLoadScore: Double // váha 10 %
}

// MARK: - Readiness Calculator

enum ReadinessCalculator {
    struct Result {
        var score: Double
        var level: ReadinessLevel
    }

    enum ReadinessLevel: String {
        case green  = "green"
        case orange = "orange"
        case red    = "red"
    }

    static func compute(snapshot: HealthMetricsSnapshot) -> Result? {
        var components = ReadinessComponents(
            sleepScore: 50,
            hrvScore: 50,
            restingHRScore: 50,
            activityLoadScore: 80
        )

        // Sleep score
        if let hours = snapshot.sleepDurationHours, let eff = snapshot.sleepEfficiencyPct {
            let hoursScore = min(100, (hours / 8.0) * 100)
            let effScore = eff
            components.sleepScore = (hoursScore + effScore) / 2
        }

        // HRV score
        if let hrv = snapshot.heartRateVariabilityMs, let baseline = snapshot.hrvBaselineAvg, baseline > 0 {
            let ratio = hrv / baseline
            components.hrvScore = min(100, ratio * 100)
        }

        // Resting HR score (inverted — lower is better)
        if let hr = snapshot.restingHeartRate, let baseline = snapshot.restingHRBaseline, baseline > 0 {
            let ratio = baseline / hr
            components.restingHRScore = min(100, ratio * 100)
        }

        // Activity load (penalize heavy external activity)
        let heavyMins = snapshot.externalActivities
            .filter { $0.durationMinutes > 30 }
            .reduce(0) { $0 + $1.durationMinutes }
        components.activityLoadScore = max(0, 100 - Double(heavyMins) * 0.5)

        snapshot.readinessComponents = components

        let score = components.sleepScore * 0.40
            + components.hrvScore * 0.30
            + components.restingHRScore * 0.20
            + components.activityLoadScore * 0.10

        let level: ReadinessLevel = score > 75 ? .green : score > 50 ? .orange : .red
        return Result(score: score, level: level)
    }
}
