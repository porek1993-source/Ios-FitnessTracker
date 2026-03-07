// HRRecoveryRPE.swift
// Watch — Odhaduje RPE ze srdeční frekvence zotavení (Heart Rate Recovery).
//
// Vědecký základ:
//  • HRR (Heart Rate Recovery) = peak HR těsně po sérii − HR po 60s pauzy
//  • Rychlá regenerace tepu → lehká zátěž (nízké RPE)
//  • Pomalá regenerace → těžká série (vysoké RPE)
//
// Tabulka použitá v kódu (konzervativní odhad):
//  HRR > 35 bpm/min → RPE ≤ 6  (lehce)
//  HRR 25–35        → RPE 7    (mírně těžce)
//  HRR 15–25        → RPE 8    (těžce)
//  HRR  8–15        → RPE 9    (velmi těžce)
//  HRR < 8          → RPE 10   (maximální výkon / selhání)

import Foundation

struct HRRecoveryRPE {

    // MARK: - Výpočet

    /// Odhadne RPE na stupnici 1–10 na základě Heart Rate Recovery.
    /// - Parameters:
    ///   - peakHR:     Tep těsně po ukončení série (bpm)
    ///   - recoveryHR: Tep po 60 sekundách pauzy (bpm)
    /// - Returns:   Odhadované RPE 1–10 (Double pro přesnější zobrazení)
    static func estimate(peakHR: Int, recoveryHR: Int) -> Double {
        guard peakHR > 0, recoveryHR > 0, peakHR >= recoveryHR else { return 7.0 }
        let hrr = Double(peakHR - recoveryHR)

        switch hrr {
        case let x where x > 35: return 5.0
        case let x where x > 28: return 6.0
        case let x where x > 21: return 7.0
        case let x where x > 14: return 8.0
        case let x where x >  7: return 9.0
        default:                  return 10.0
        }
    }

    /// Textový popis odpovídající RPE hodnotě
    static func label(forRPE rpe: Double) -> String {
        switch rpe {
        case ..<6:  return "Lehce 😌"
        case 6..<7: return "Mírně 💪"
        case 7..<8: return "Těžce 😤"
        case 8..<9: return "Velmi těžce 🥵"
        default:    return "Maximum 💀"
        }
    }

    /// Barva pro UI (od zelené po červenou)
    static func colorHex(forRPE rpe: Double) -> String {
        switch rpe {
        case ..<6:  return "#30D158"  // zelená
        case 6..<7: return "#FFD60A"  // žlutá
        case 7..<8: return "#FF9F0A"  // oranžová
        case 8..<9: return "#FF6B35"  // tmavě oranžová
        default:    return "#FF3B30"  // červená
        }
    }
}

// MARK: - WatchKit Message Encoding Helper

extension HRRecoveryRPE {
    /// PřeBalí výsledek RPE a peak HR do WatchConnectivity zprávy
    static func makeMessage(peakHR: Int, recoveryHR: Int, setNumber: Int) -> [String: Any] {
        let rpe = estimate(peakHR: peakHR, recoveryHR: recoveryHR)
        return [
            "type":       "hrRecoveryRPE",
            "peakHR":     peakHR,
            "recoveryHR": recoveryHR,
            "estimatedRPE": rpe,
            "rpeLabel":   label(forRPE: rpe),
            "setNumber":  setNumber
        ]
    }
}
