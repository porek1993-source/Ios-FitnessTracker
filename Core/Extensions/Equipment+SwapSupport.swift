// Equipment+SwapSupport.swift
// Agilní Fitness Trenér — Equipment enum extensions pro SwapExerciseSheet a filtry
//
// OPRAVY v3.0:
//  ✅ Odstraněn mrtvý kód (komentáře s copy-paste fragmenty)
//  ✅ Přidány praktické extension metody pro Equipment enum
//  ✅ Přidána lokalizace Equipment pro UI zobrazení
//  ✅ Přidán helper pro mapování z MuscleWikiExercise.equipment (CZ string) na enum

import SwiftUI
import SwiftData

// MARK: - Equipment Display Helpers

extension Equipment {

    /// Český název vybavení pro UI
    var czechName: String {
        switch self {
        case .barbell:       return "Velká činka"
        case .dumbbell:      return "Jednoručka"
        case .cable:         return "Kladka"
        case .machine:       return "Stroj"
        case .bodyweight:    return "Vlastní váha"
        case .resistanceBand,.band: return "Odporová guma"
        case .kettlebell:    return "Kettlebell"
        case .pullupBar:     return "Hrazda"
        case .trx:           return "TRX"
        }
    }

    /// SF Symbol ikona kompatibilní s iOS 17+
    var systemIcon: String {
        switch self {
        case .barbell:        return "figure.strengthtraining.traditional"
        case .dumbbell:       return "scalemass.fill"
        case .cable:          return "arrow.up.and.down.circle.fill"
        case .machine:        return "gearshape.fill"
        case .bodyweight:     return "figure.walk"
        case .resistanceBand, .band: return "arrow.left.and.right.circle.fill"
        case .kettlebell:     return "circle.fill"
        case .pullupBar:      return "figure.gymnastics"
        case .trx:            return "rectangle.and.arrow.up.right.and.arrow.down.left"
        }
    }

    /// Zda je toto vybavení dostupné bez tělocvičny (pro home workout filtraci)
    var isHomeCompatible: Bool {
        switch self {
        case .bodyweight, .resistanceBand, .band, .dumbbell, .kettlebell, .trx: return true
        default: return false
        }
    }

    /// Mapuje český název z muscle_wiki_data_full na Equipment enum
    static func from(czechName: String) -> Equipment? {
        switch czechName {
        case "Jednoručka":    return .dumbbell
        case "Velká činka":   return .barbell
        case "Vlastní váha":  return .bodyweight
        case "Stroj":         return .machine
        case "Kladka":        return .cable
        case "Kettlebell":    return .kettlebell
        case "Odporová guma": return .resistanceBand
        case "TRX":           return .trx
        case "Hrazda":        return .pullupBar
        case "Kotouč":        return .barbell
        case "Bosu":          return .bodyweight
        case "Medicimbal":    return .kettlebell
        default:              return nil
        }
    }
}

// MARK: - Equipment Set Helpers

extension Set where Element == Equipment {

    /// Vrátí seznam česky pojmenovaných položek seřazených abecedně
    var czechNames: [String] {
        self.map(\.czechName).sorted()
    }

    /// Zkontroluje, zda dané vybavení vyhovuje filtru (nil = no restriction)
    func allows(_ equipment: [Equipment]) -> Bool {
        guard !equipment.isEmpty else { return true }  // cvik bez vybavení = bodyweight → vždy OK
        return !self.isDisjoint(with: Set(equipment))
    }
}
