// TempoParser.swift
// Agilní Fitness Trenér — Parsování tempa cviku do audio eventů
//
// Formát tempa: "E-P-C-P"
//   E = Eccentric  (fáze spuštění/natažení)  — "3" = 3 sekundy dolů
//   P = Pause      (pauza ve spodní pozici)  — "1" = 1 sekunda výdrž
//   C = Concentric (fáze zdvihu/zkrácení)    — "2" = 2 sekundy nahoru
//   P = Pause      (pauza v horní pozici)    — "0" = žádná pauza
//
// Příklady:
//   "3-1-2-0"  = 3s dolů, 1s výdrž, 2s nahoru, 0s pauza nahoře
//   "2-0-1-0"  = rychlý koncentric, kontrolovaný eccentric
//   "4-2-1-0"  = pomalý TUT styl

import Foundation
import AVFoundation

// MARK: - Tempo Phase

enum TempoPhase: Int, CaseIterable {
    case eccentric   = 0   // spouštění
    case pauseBottom = 1   // pauza dole
    case concentric  = 2   // zdvih
    case pauseTop    = 3   // pauza nahoře

    var voiceCue: String {
        switch self {
        case .eccentric:   return "dolů"
        case .pauseBottom: return "výdrž"
        case .concentric:  return "nahoru"
        case .pauseTop:    return "a"
        }
    }

    var breathingCue: String {
        switch self {
        case .eccentric:   return "nádech"
        case .concentric:  return "výdech"
        default:           return ""
        }
    }
}

// MARK: - Audio Event (přesné časování)

struct TempoAudioEvent {
    let offsetSeconds: Double      // čas od začátku série (kumulativní)
    let phase: TempoPhase
    let beatIndex: Int             // který tik v dané fázi (1-based)
    let totalBeatsInPhase: Int
    let isPhaseStart: Bool

    var shouldSpeakPhase: Bool { isPhaseStart }
    var shouldTick: Bool { totalBeatsInPhase > 1 || phase == .eccentric || phase == .concentric }
}

// MARK: - Parsed Tempo

struct ParsedTempo {
    let eccentric: Int      // sekundy
    let pauseBottom: Int
    let concentric: Int
    let pauseTop: Int

    var totalSeconds: Int { eccentric + pauseBottom + concentric + pauseTop }
    var isValid: Bool { totalSeconds > 0 && totalSeconds <= 30 }

    var displayString: String { "\(eccentric)-\(pauseBottom)-\(concentric)-\(pauseTop)" }

    var description: String {
        "\(eccentric)s dolů · \(pauseBottom)s výdrž · \(concentric)s nahoru"
    }
}

// MARK: - TempoParser

enum TempoParser {

    /// Parsuje string jako "3-1-2-0" nebo "3/1/2/0" na `ParsedTempo`.
    static func parse(_ raw: String?) -> ParsedTempo? {
        guard let raw else { return nil }

        // Normalizuj oddělovač
        let normalized = raw
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = normalized.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 4 else { return nil }

        let tempo = ParsedTempo(
            eccentric:    parts[0],
            pauseBottom:  parts[1],
            concentric:   parts[2],
            pauseTop:     parts[3]
        )

        return tempo.isValid ? tempo : nil
    }

    /// Generuje sekvenci `TempoAudioEvent` pro jednu opakování.
    /// Vrácené eventy jsou seřazeny chronologicky.
    static func buildEventSequence(tempo: ParsedTempo) -> [TempoAudioEvent] {
        var events: [TempoAudioEvent] = []
        var cursor: Double = 0

        let phases: [(TempoPhase, Int)] = [
            (.eccentric,   tempo.eccentric),
            (.pauseBottom, tempo.pauseBottom),
            (.concentric,  tempo.concentric),
            (.pauseTop,    tempo.pauseTop)
        ]

        for (phase, beats) in phases {
            guard beats > 0 else { continue }

            for beat in 1...beats {
                events.append(TempoAudioEvent(
                    offsetSeconds:      cursor,
                    phase:              phase,
                    beatIndex:          beat,
                    totalBeatsInPhase:  beats,
                    isPhaseStart:       beat == 1
                ))
                cursor += 1.0
            }
        }

        return events
    }

    /// Celkový čas jednoho repu v sekundách.
    static func repDuration(_ tempo: ParsedTempo) -> Double {
        Double(tempo.totalSeconds)
    }
}
