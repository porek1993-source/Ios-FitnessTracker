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
        let reason: String
    }
    
    /// Spočítá doporučenou pracovní váhu a opakování metodou Dvojité Progrese s RPE korekci.
    /// - Pokud uživatel splnil maximální reps ve všech sériích → +2.5 kg
    /// - Pokud RPE bylo příliš vysoké (≥9.5) → udrž váhu i přes splněná reps
    /// - Pokud RPE bylo nízké (≤6) → +5 kg (příliš lehké)
    /// - Jinak → udrž váhu, přidej reps
    static func calculateNextTarget(previousSets: [CompletedSet], programRepsMin: Int, programRepsMax: Int) -> Target? {
        guard !previousSets.isEmpty else { return nil }
        
        let workingSets = previousSets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty else { return nil }
        
        let didCompleteAllMaxReps = workingSets.allSatisfy { $0.reps >= programRepsMax }
        let lastWeight = workingSets.max(by: { $0.weightKg < $1.weightKg })?.weightKg ?? 0
        
        // RPE analýza (průměr ze všech sérií kde je RPE zadán)
        let rpeValues = workingSets.compactMap { $0.rpe }
        let avgRpe = rpeValues.isEmpty ? nil : rpeValues.reduce(0, +) / Double(rpeValues.count)
        
        if let avgRpe, avgRpe >= 9.5 {
            // Bylo příliš těžké → drž váhu, nepřidávej
            return Target(
                weight: lastWeight,
                repsMin: programRepsMin,
                repsMax: programRepsMax,
                reason: "RPE \(String(format: "%.1f", avgRpe)) → váha je na hranici, drž ji"
            )
        }
        
        if let avgRpe, avgRpe <= 6.0, didCompleteAllMaxReps {
            // Bylo příliš lehké → přidej 5 kg
            let newWeight = WeightRounder.roundToNearestPlates(weight: lastWeight + 5.0)
            return Target(
                weight: newWeight,
                repsMin: programRepsMin,
                repsMax: programRepsMax,
                reason: "RPE \(String(format: "%.1f", avgRpe)) — příliš lehké, +5 kg"
            )
        }
        
        if didCompleteAllMaxReps {
            // Standardní progrese: +2.5 kg
            let newWeight = WeightRounder.roundToNearestPlates(weight: lastWeight + 2.5)
            return Target(
                weight: newWeight,
                repsMin: programRepsMin,
                repsMax: programRepsMax,
                reason: "Splněna max. reps → +2.5 kg"
            )
        } else {
            // Nesplněno: váha zůstává, cílem je přidat opakování
            return Target(
                weight: lastWeight,
                repsMin: programRepsMin,
                repsMax: programRepsMax,
                reason: "Max. reps nesplněny → drž váhu, přidej reps"
            )
        }
    }
}
