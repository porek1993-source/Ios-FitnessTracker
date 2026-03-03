// HapticPatternEngine.swift
// Pokročilé haptické vzory pomocí Core Haptics (CHHapticEngine)
// ✅ Dle deepanal.pdf: "Prémiové haptické zážitky přesahující obyčejné vibrace"

import CoreHaptics
import Foundation

/// Prémiový haptický engine — synchronizace zvuku a haptiky pro workout UX.
@MainActor
final class HapticPatternEngine {
    static let shared = HapticPatternEngine()
    
    private var engine: CHHapticEngine?
    private var isAvailable: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }
    
    private init() {
        prepareEngine()
    }
    
    // MARK: - Engine Lifecycle
    
    private func prepareEngine() {
        guard isAvailable else { return }
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine?.stoppedHandler = { _ in }
            try engine?.start()
        } catch {
            AppLogger.warning("HapticPatternEngine: Nelze inicializovat: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Tempo Haptics (pro AudioCoach tempo systém)
    
    /// Rytmický haptický pulz simulující srdeční tep — pro udržení tempa cvičení.
    /// - Parameters:
    ///   - bpm: Tempo v úderech za minutu (např. 60 = 1 úder za sekundu)
    ///   - duration: Celková délka v sekundách
    func playTempoPulse(bpm: Int = 60, duration: TimeInterval = 4.0) {
        guard isAvailable, let engine else { return }
        
        let interval = 60.0 / Double(bpm)
        let beatCount = Int(duration / interval)
        
        var events: [CHHapticEvent] = []
        for i in 0..<beatCount {
            let time = Double(i) * interval
            
            // Hlavní úder — silný
            let mainBeat = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: time
            )
            events.append(mainBeat)
            
            // Sekundární echo — lehký (simuluje srdeční "dub")
            let echo = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: time + 0.15
            )
            events.append(echo)
        }
        
        playPattern(events: events, engine: engine)
    }
    
    /// Excentrická fáze tempa — pomalý, tažný haptický vzor.
    func playEccentricPhase(durationSeconds: Double = 3.0) {
        guard isAvailable, let engine else { return }
        
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ],
            relativeTime: 0,
            duration: durationSeconds
        )
        
        // Decrescendo — intenzita klesá
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.6),
                .init(relativeTime: durationSeconds, value: 0.15)
            ],
            relativeTime: 0
        )
        
        playPattern(events: [event], curves: [curve], engine: engine)
    }
    
    /// Koncentrická fáze — krátký, ostřejší vzor (zdvih).
    func playConcentricPhase(durationSeconds: Double = 1.5) {
        guard isAvailable, let engine else { return }
        
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ],
            relativeTime: 0,
            duration: durationSeconds
        )
        
        // Crescendo — intenzita stoupá
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.3),
                .init(relativeTime: durationSeconds, value: 1.0)
            ],
            relativeTime: 0
        )
        
        playPattern(events: [event], curves: [curve], engine: engine)
    }
    
    // MARK: - Celebration Haptics
    
    /// 🏆 Crescendo burst pro dosažení osobního rekordu (PR).
    /// Výrazný, prodloužený haptický vzor — 3 stupňující se údery zakončené triumfálním úderem.
    func playPersonalRecordCelebration() {
        guard isAvailable, let engine else { return }
        
        var events: [CHHapticEvent] = []
        
        // 3 stupňující se údery
        let intensities: [Float] = [0.4, 0.6, 0.85]
        for (i, intensity) in intensities.enumerated() {
            let time = Double(i) * 0.2
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5 + Float(i) * 0.15)
                ],
                relativeTime: time
            ))
        }
        
        // Krátká pauza
        // Triumfální finální úder — plná intenzita
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ],
            relativeTime: 0.8
        ))
        
        // Doznívající vibrace
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ],
            relativeTime: 0.85,
            duration: 0.6
        ))
        
        let fadeOut = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.85, value: 0.5),
                .init(relativeTime: 1.45, value: 0.0)
            ],
            relativeTime: 0
        )
        
        playPattern(events: events, curves: [fadeOut], engine: engine)
    }
    
    /// ✅ Dokončení série — jemný potvrzovací tap.
    func playSetComplete() {
        guard isAvailable, let engine else { return }
        
        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0.08
            )
        ]
        
        playPattern(events: events, engine: engine)
    }
    
    /// 🎉 Velkolepé dokončení celého tréninku — exploze energie a uvolnění.
    func playWorkoutComplete() {
        guard isAvailable, let engine else { return }
        
        var events: [CHHapticEvent] = []
        
        // Rychlý rozběh
        for i in 0..<5 {
            let time = Double(i) * 0.1
            let intensity = Float(i) * 0.2 + 0.2
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: time
            ))
        }
        
        // Hlavní exploze!
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 0.55
        ))
        
        // Dlouhá vlna uvolnění (endorfin burst)
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
            ],
            relativeTime: 0.6,
            duration: 1.5
        ))
        
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.6, value: 0.7),
                .init(relativeTime: 2.1, value: 0.0)
            ],
            relativeTime: 0
        )
        
        playPattern(events: events, curves: [curve], engine: engine)
    }
    
    // MARK: - Internal
    
    private func playPattern(
        events: [CHHapticEvent],
        curves: [CHHapticParameterCurve] = [],
        engine: CHHapticEngine
    ) {
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            AppLogger.warning("HapticPatternEngine: Nelze přehrát vzor: \(error.localizedDescription)")
        }
    }
}
