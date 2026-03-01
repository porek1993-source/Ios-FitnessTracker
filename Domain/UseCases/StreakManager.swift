// StreakManager.swift
// Agilní Fitness Trenér — Systém týdenních streaků (🔥)

import Foundation

public struct StreakManager {
    /// Vypočítá aktuální streak (za kolik po sobě jdoucích týdnů uživatel dokončil alespoň jeden trénink).
    /// Ignoruje aktuální týden, pokud v něm ještě nezačal, takže streak nepřeruší před koncem týdne.
    static func calculateWeeklyStreak(completedSessions: [WorkoutSession]) -> Int {
        // ✅ FIX: Calendar.mondayStart zajišťuje pondělní začátek týdne nezávisle na locale zařízení.
        // Calendar.current na US zařízeních (locale en_US) má firstWeekday=1 (neděle),
        // což způsobovalo špatné zařazení session do týdnů a nesprávný streak počet.
        let calendar = Calendar.mondayStart
        let allCompleted = completedSessions.filter { $0.status == .completed && $0.finishedAt != nil }
        
        var streak = 0
        var checkWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        var skippedCurrentWeek = false
        
        for _ in 0..<52 { // Limit max 52 týdnů zpět (1 rok)
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: checkWeek) ?? checkWeek
            let hasWorkout = allCompleted.contains { $0.startedAt >= checkWeek && $0.startedAt < weekEnd }
            
            if hasWorkout {
                streak += 1
                checkWeek = calendar.date(byAdding: .day, value: -7, to: checkWeek) ?? checkWeek
            } else if !skippedCurrentWeek && streak == 0 {
                // Aktuální týden ještě nemá trénink, což nechtěně nepřeruší minulý streak.
                skippedCurrentWeek = true
                checkWeek = calendar.date(byAdding: .day, value: -7, to: checkWeek) ?? checkWeek
            } else {
                // Přerušený řetězec
                break
            }
        }
        
        return streak
    }
}
