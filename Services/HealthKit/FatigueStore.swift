// FatigueStore.swift

import Foundation

enum FatigueStore {
    private static let key = "today_fatigue_v1"
    private static let dateKey = "today_fatigue_date"

    static func save(_ entries: [FatigueEntry]) {
        // Automaticky promaž starší než dnešek
        UserDefaults.standard.set(Date.now.startOfDay.timeIntervalSince1970, forKey: dateKey)
        let data = entries.map {
            ["id": $0.area.id,
             "severity": $0.severity,
             "isJoint": $0.isJointPain] as [String: Any]
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func loadTodayFatigue() -> [FatigueArea] {
        // Platí jen pro dnešek
        if let savedTimestamp = UserDefaults.standard.object(forKey: dateKey) as? TimeInterval {
            let savedDate = Date(timeIntervalSince1970: savedTimestamp)
            guard Calendar.current.isDateInToday(savedDate) else {
                UserDefaults.standard.removeObject(forKey: key)
                return []
            }
        }

        guard let raw = UserDefaults.standard.array(forKey: key) as? [[String: Any]] else {
            return []
        }
        return raw.compactMap { d in
            guard
                let id       = d["id"] as? String,
                let severity = d["severity"] as? Int,
                let isJoint  = d["isJoint"] as? Bool
            else { return nil }
            return FatigueArea(
                bodyPart: id,
                severity: severity,
                isJointPain: isJoint,
                note: nil
            )
        }
    }
}
