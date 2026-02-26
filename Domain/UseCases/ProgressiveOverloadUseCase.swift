// ProgressiveOverloadUseCase.swift

import Foundation

enum ProgressiveOverloadUseCase {

    struct Suggestion {
        enum Action: String, Codable {
            case increase = "increase"
            case maintain = "maintain"
            case decrease = "decrease"
        }
        let lastWeightKg: Double
        let suggestedWeightKg: Double
        let action: Action
        let reason: String
    }

    /// Vstup: posledních 9 WeightEntry (3 session × 3 top sety) pro jeden cvik.
    /// 3/3 úspěšné → +2.5 / +5 kg
    /// 2/3 úspěšné → drž stejnou váhu
    /// <2/3         → micro deload -5 %
    static func suggest(history: [WeightEntry]) -> Suggestion? {
        guard
            let lastWeight = history
                .sorted(by: { $0.loggedAt > $1.loggedAt })
                .first?.weightKg,
            !history.isEmpty
        else { return nil }

        let bySession = Dictionary(grouping: history, by: \.sessionId)
        let recentSessions = bySession.values
            .sorted {
                ($0.first?.loggedAt ?? .distantPast) > ($1.first?.loggedAt ?? .distantPast)
            }
            .prefix(AppConstants.progressiveOverloadLookbackSessions)

        let successCount = recentSessions.filter { sets in
            let successful = sets.filter(\.wasSuccessful).count
            return successful >= (sets.count / 2 + 1)
        }.count

        let isLowerBody = history.first?.exercise?.category == .legs
        let increment = isLowerBody
            ? AppConstants.progressiveOverloadLowerBodyIncrement
            : AppConstants.progressiveOverloadUpperBodyIncrement

        switch successCount {
        case 3...:
            return Suggestion(
                lastWeightKg: lastWeight,
                suggestedWeightKg: lastWeight + increment,
                action: .increase,
                reason: "3 úspěšné session v řadě → navyšujeme o \(increment) kg"
            )
        case 2:
            return Suggestion(
                lastWeightKg: lastWeight,
                suggestedWeightKg: lastWeight,
                action: .maintain,
                reason: "2/3 session úspěšné → váhu držíme"
            )
        default:
            let deload = (lastWeight * AppConstants.progressiveOverloadDeloadPercent)
                .rounded(toNearest: 2.5)
            return Suggestion(
                lastWeightKg: lastWeight,
                suggestedWeightKg: deload,
                action: .decrease,
                reason: "Méně než 2/3 session úspěšné → micro deload -5 %"
            )
        }
    }
}
