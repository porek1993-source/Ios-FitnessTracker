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

enum WarmupCalculator {
    /// Generuje 3 zahřívací série vypočítané na základě cílové pracovní váhy.
    /// Pokud je váha příliš nízká (pod 30 kg), vrací méně sérií nebo upravená procenta.
    static func generateWarmups(targetWeight: Double, targetRepsMin: Int) -> [SetState] {
        var warmups: [SetState] = []
        
        // 1. Série (Prázdná osa nebo lehká váha pro prokrvení)
        // Osa má obvykle 20kg, u jednoruček/strojů můžeme volit minimální.
        let firstSetWeight = targetWeight <= 30 ? targetWeight * 0.3 : 20.0
        let firstSet = SetState(
            targetRepsMin: max(8, targetRepsMin + 4),
            targetRepsMax: max(12, targetRepsMin + 6),
            weightKg: WeightRounder.roundToNearestPlates(weight: firstSetWeight),
            reps: max(8, targetRepsMin + 4), // Vyšší opakování na zahřátí
            rpe: nil,
            isCompleted: false,
            isWarmup: true,
            previousWeightKg: nil
        )
        warmups.append(firstSet)
        
        if targetWeight > 30 {
            // 2. Série (Zhruba 50 % pracovní váhy)
            let secondSet = SetState(
                targetRepsMin: max(5, targetRepsMin),
                targetRepsMax: max(8, targetRepsMin + 2),
                weightKg: WeightRounder.roundToNearestPlates(weight: targetWeight * 0.5),
                reps: max(5, targetRepsMin),
                rpe: nil,
                isCompleted: false,
                isWarmup: true,
                previousWeightKg: nil
            )
            warmups.append(secondSet)
        }
        
        if targetWeight > 50 {
            // 3. Série (Zhruba 75 % pracovní váhy, méně opakování - adaptace CNS)
            let thirdSet = SetState(
                targetRepsMin: max(2, targetRepsMin - 2),
                targetRepsMax: max(4, targetRepsMin),
                weightKg: WeightRounder.roundToNearestPlates(weight: targetWeight * 0.75),
                reps: max(2, targetRepsMin - 2),
                rpe: nil,
                isCompleted: false,
                isWarmup: true,
                previousWeightKg: nil
            )
            warmups.append(thirdSet)
        }
        
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
    /// - Parameters:
    ///   - previousSets: Dokončené série stejného cviku z minulého tréninku.
    ///   - programRepsMin: Dolní hranice opakování stanovená tréninkovým plánem.
    ///   - programRepsMax: Horní hranice opakování stanovená tréninkovým plánem.
    /// - Returns: Doporučené hodnoty. Pokud není historie, vrací `nil`.
    static func calculateNextTarget(previousSets: [CompletedSet], programRepsMin: Int, programRepsMax: Int) -> Target? {
        guard !previousSets.isEmpty else { return nil }
        
        // Zajímají nás jen skutečné pracovní série
        let workingSets = previousSets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty else { return nil }
        
        // Zkontrolujeme, zda uživatel splnil ve všech pracovních sériích horní hranici (repsMax)
        let didCompleteAllMaxReps = workingSets.allSatisfy { set in
            set.reps >= programRepsMax
        }
        
        // Zjistíme na jaké váze pracoval
        // Vezmeme nejčastější nebo maximální váhu z minulého tréninku
        let lastWeight = workingSets.max(by: { $0.weightKg < $1.weightKg })?.weightKg ?? 0
        
        if didCompleteAllMaxReps {
            // SPLNĚNO: Zvýšit váhu, spadnout na spodní hranici opakování
            let newWeight = WeightRounder.roundToNearestPlates(weight: lastWeight + 2.5) // Zvýší o "standardní" krok
            return Target(weight: newWeight, repsMin: programRepsMin, repsMax: programRepsMax)
        } else {
            // NESPLNĚNO: Nechat váhu, cílem pro dnešek je přidat opakování směrem k repsMax
            // Uživatel zůstává na stejné váze, ale budeme chtít, aby naplnil rozsah.
            return Target(weight: lastWeight, repsMin: programRepsMin, repsMax: programRepsMax)
        }
    }
}
