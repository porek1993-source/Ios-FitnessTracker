// OneRepMaxCalculator.swift
// Agilní Fitness Trenér — Analytika maximální síly
//
// Kalkulátor využívající Brzyckiho formuli: 1RM = Weight × (36 / (37 - Reps))
// Vhodné pro odhad maximální kapacity u vah a opakování.

import Foundation

public enum OneRepMaxFormula {
    case brzycki
    case epley
    
    // Brzycki: W * (36 / (37 - r))
    // Preferováno pro opakování do 10, vysoce přesné.
    func calculate(weight: Double, reps: Int) -> Double {
        guard reps > 0 && weight > 0 else { return 0 }
        
        if reps == 1 { return weight } // Pokud už zvedl 1 rep, to je realita, ne odhad!
        
        switch self {
        case .brzycki:
            // Limitem Brzyckiho je max 36 opakování, za 10 reps začíná být méně přesný, ale pro standardní trénink ok.
            let effectiveReps = min(Double(reps), 36.0)
            return weight * (36.0 / (37.0 - effectiveReps))
            
        case .epley:
            // Epley: W * (1 + 0.0333 * r)
            return weight * (1.0 + 0.0333 * Double(reps))
        }
    }
}

public struct OneRepMaxCalculator {
    /// Vypočítá odhad maximální zvednuté váhy na 1 opakování z existující série.
    /// Vrací hodnotu v kg zaokrouhlenou na 1 desetinné místo (dle dostupných kotoučů).
    public static func estimate1RM(weightKg: Double, reps: Int, formula: OneRepMaxFormula = .brzycki) -> Double {
        let raw1RM = formula.calculate(weight: weightKg, reps: reps)
        // Zaokrouhli na nejbližších 0.5 nebo 1kg
        // Běžné microplates jsou 1.25kg, takže 2.5kg skoky, pro 1RM odhad stačí krok po 0.5kg
        return round(raw1RM * 2) / 2
    }
    
    /// Pro historickou analýzu (např. do grafů): projde všechny záznamy a pro každý unikátní den najde nejvyšší 1RM.
    /// Vrací chronologicky seřazené pole (Date, Double).
    public static func historical1RM(from entries: [WeightEntry], formula: OneRepMaxFormula = .brzycki) -> [(date: Date, OneRM: Double)] {
        var dailyMaxes: [Date: Double] = [:]
        let calendar = Calendar.current
        
        for entry in entries {
            guard entry.wasSuccessful else { continue } // Neúspěšné série (failed) nepočítáme do progresu
            
            let day = calendar.startOfDay(for: entry.loggedAt)
            let estimatedMax = estimate1RM(weightKg: entry.weightKg, reps: entry.reps, formula: formula)
            
            // Zachováme nejvyšší 1RM odhad za ten daný den
            let currentBest = dailyMaxes[day] ?? 0
            if estimatedMax > currentBest {
                dailyMaxes[day] = estimatedMax
            }
        }
        
        // Seřadíme chronologicky
        let sorted = dailyMaxes.map { (date: $0.key, OneRM: $0.value) }.sorted { $0.date < $1.date }
        return sorted
    }
}
