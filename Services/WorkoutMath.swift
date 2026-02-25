// WorkoutMath.swift
// Agilní Fitness Trenér — Lokální výpočty progresivního přetížení a rozcviček

import Foundation
import SwiftData

// MARK: - Weight Rounder

enum WeightRounder {
    /// Zaokrouhlí váhu na nejbližších 2.5 kg (standardní krok na olympijské ose pomocí 1.25kg kotoučů).
    /// Příklad: 51.3 -> 50.0, 51.5 -> 52.5, 53.7 -> 55.0
    static func roundToNearestPlates(weight: Double) -> Double {
        let step = 2.5
        let rounded = round(weight / step) * step
        return rounded
    }
}

// MARK: - Warmup Calculator

struct WarmupCalculator {
    /// Generuje přesně 3 zahřívací série vypočítané na základě cílové pracovní váhy.
    /// Pravidla: 1. série 20kg (osa), 2. série 50%, 3. série 75%.
    static func generateWarmups(targetWeight: Double, targetRepsMin: Int) -> [SetState] {
        var warmups: [SetState] = []
        
        // 1. Série (Vždy 20 kg - standardní osa, nebo pracovní váha pokud je pod 20kg)
        let firstWeight = min(20.0, targetWeight)
        warmups.append(SetState(
            targetRepsMin: 10,
            targetRepsMax: 12,
            weightKg: WeightRounder.roundToNearestPlates(weight: firstWeight),
            reps: 10,
            isCompleted: false,
            isWarmup: true
        ))
        
        // 2. Série (50 % pracovní váhy)
        warmups.append(SetState(
            targetRepsMin: 5,
            targetRepsMax: 5,
            weightKg: WeightRounder.roundToNearestPlates(weight: targetWeight * 0.5),
            reps: 5,
            isCompleted: false,
            isWarmup: true
        ))
        
        // 3. Série (75 % pracovní váhy)
        warmups.append(SetState(
            targetRepsMin: 3,
            targetRepsMax: 3,
            weightKg: WeightRounder.roundToNearestPlates(weight: targetWeight * 0.75),
            reps: 3,
            isCompleted: false,
            isWarmup: true
        ))
        
        return warmups
    }
}

// MARK: - Progression Engine

enum ProgressionEngine {
    
    struct Target {
        let weight: Double
        let repsMin: Int
        let repsMax: Int
    }
    
    /// Spočítá doporučenou pracovní váhu a opakování pro dnešní trénink metodou Dvojité Progrese.
    static func calculateNextTarget(previousSets: [CompletedSet], programRepsMin: Int, programRepsMax: Int) -> Target? {
        guard !previousSets.isEmpty else { return nil }
        
        let workingSets = previousSets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty else { return nil }
        
        // Zkontrolujeme, zda uživatel splnil ve všech sériích horní hranici
        let didCompleteAllMaxReps = workingSets.allSatisfy { $0.reps >= programRepsMax }
        
        // Zjistíme poslední použitou váhu
        let lastWeight = workingSets.max(by: { $0.weightKg < $1.weightKg })?.weightKg ?? 0
        
        if didCompleteAllMaxReps {
            // SPLNĚNO: Zvýšit váhu o 2.5kg, spadnout na spodní hranici opakování
            let newWeight = WeightRounder.roundToNearestPlates(weight: lastWeight + 2.5)
            return Target(weight: newWeight, repsMin: programRepsMin, repsMax: programRepsMax)
        } else {
            // NESPLNĚNO: Váha zůstává, cílem je přidat opakování
            // Pokud posledně dal např. 6, dnes by měl dát aspoň 7.
            // Ale programový rozsah vracíme jako referenci.
            return Target(weight: lastWeight, repsMin: programRepsMin, repsMax: programRepsMax)
        }
    }
}
