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

        // Sleep score — 8h = 100%, lineární škálování
        if let hours = snapshot.sleepDurationHours {
            let hoursScore: Double
            if hours >= 8      { hoursScore = 100 }
            else if hours >= 7 { hoursScore = 80 }
            else if hours >= 6 { hoursScore = 60 }
            else if hours >= 5 { hoursScore = 35 }
            else               { hoursScore = 15 }
            
            if let eff = snapshot.sleepEfficiencyPct {
                components.sleepScore = (hoursScore * 0.6) + (eff * 0.4)
            } else {
                components.sleepScore = hoursScore
            }
        }

        // HRV score — osobní baseline (ratio-based)
        // Pokud je HRV nad baseline → skvělé zotavení, pod → únava
        if let hrv = snapshot.heartRateVariabilityMs, let baseline = snapshot.hrvBaselineAvg, baseline > 0 {
            let ratio = hrv / baseline
            // ratio 1.0 = normální (75 bodů), >1.2 = excelentní (100), <0.6 = červená (20)
            if ratio >= 1.2       { components.hrvScore = 100 }
            else if ratio >= 1.0  { components.hrvScore = 75 + (ratio - 1.0) * 125 }
            else if ratio >= 0.8  { components.hrvScore = 50 + (ratio - 0.8) * 125 }
            else if ratio >= 0.6  { components.hrvScore = 25 + (ratio - 0.6) * 125 }
            else                  { components.hrvScore = max(10, ratio * 42) }
        } else if let hrv = snapshot.heartRateVariabilityMs {
            // Nemáme baseline — použijeme absolutní hodnoty jako fallback
            if hrv > 60      { components.hrvScore = 85 }
            else if hrv > 40 { components.hrvScore = 65 }
            else if hrv > 25 { components.hrvScore = 45 }
            else             { components.hrvScore = 25 }
        }

        // Resting HR score — osobní baseline (inverted — nižší je lepší)
        if let hr = snapshot.restingHeartRate, let baseline = snapshot.restingHRBaseline, baseline > 0 {
            let ratio = baseline / hr  // >1 = tep nižší než normál = skvělé
            if ratio >= 1.1       { components.restingHRScore = 95 }
            else if ratio >= 1.0  { components.restingHRScore = 80 }
            else if ratio >= 0.9  { components.restingHRScore = 55 }
            else if ratio >= 0.8  { components.restingHRScore = 35 }
            else                  { components.restingHRScore = 20 }
        } else if let hr = snapshot.restingHeartRate {
            // Fallback bez baseline
            if hr < 55      { components.restingHRScore = 90 }
            else if hr < 65 { components.restingHRScore = 75 }
            else if hr < 75 { components.restingHRScore = 55 }
            else             { components.restingHRScore = 30 }
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
