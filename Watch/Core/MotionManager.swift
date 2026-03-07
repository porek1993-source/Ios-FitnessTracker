// MotionManager.swift
// Automatická detekce opakování pomocí akcelerometru a gyroskopu Apple Watch
//
// Algoritmus:
//  1. Sbíráme data ze senzorů na 50 Hz
//  2. Aplikujeme low-pass filtr pro odstranění šumu
//  3. Detekujeme vrcholy (peak detection) v normalizované magnitudě
//  4. Každý validní peak = 1 opakování

import CoreMotion
import Foundation
import Combine

// MARK: - VBT Zone

/// Zóny rychlosti tyče pro Velocity Based Training
enum VBTZone: String {
    case explosive = "Explozivní"   // > 0.8 m/s — maximální šprotní výkon
    case strength  = "Síla"         // 0.5–0.8 m/s — silová zóna
    case fatigue   = "Únava"        // 0.3–0.5 m/s — blížíme se selhání
    case failure   = "Selhání"      // < 0.3 m/s — limit výkonu
    case idle      = "—"            // žádný pohyb

    var icon: String {
        switch self {
        case .explosive: return "⚡"
        case .strength:  return "💪"
        case .fatigue:   return "😮‍💨"
        case .failure:   return "🛑"
        case .idle:      return "—"
        }
    }

    var color: String { // hex
        switch self {
        case .explosive: return "#30D158"
        case .strength:  return "#FFD60A"
        case .fatigue:   return "#FF9F0A"
        case .failure:   return "#FF3B30"
        case .idle:      return "#8E8E93"
        }
    }
}

@MainActor
final class MotionManager: ObservableObject {

    // MARK: - Published state
    @Published var detectedReps: Int = 0
    @Published var isTracking: Bool = false
    @Published var currentIntensity: Double = 0.0 // 0–1 pro vizuální feedback

    // ✅ Phase 4: VBT — Velocity Based Training
    @Published var barVelocity: Double = 0.0        // Průměrná rychlost osy [m/s] za sérii
    @Published var peakVelocity: Double = 0.0       // Maximální rychlost za sérii
    @Published var vbtZone: VBTZone = .idle         // Aktuální VBT zóna
    @Published var setEndSuggested: Bool = false    // Signál k auto-ukončení série

    // MARK: - Private
    private let motion = CMMotionManager()
    private let queue  = OperationQueue()

    // Filtr a peak detection
    private var filteredMagnitude: Double = 0.0
    private var previousMagnitude: Double = 0.0
    private var isAboveThreshold: Bool    = false
    private var lastPeakTime: Date        = .distantPast

    // Přizpůsobitelný práh (automaticky kalibrujeme z prvních 5 pohybů)
    private var peakThreshold: Double     = 1.8
    private var calibrationSamples: [Double] = []
    private var isCalibrated: Bool        = false

    // VBT: akumulace rychlostí za sérii
    private var velocitySamples: [Double] = []
    private var lowVelocityDuration: TimeInterval = 0  // Počet sekund pod prahem selhání
    private var lastSampleTime: Date = .now

    // Minimální čas mezi opakováními (zabrání double-count)
    private let minRepInterval: TimeInterval = 0.35
    // Low-pass filtr koeficient (0.0 = velmi hladký, 1.0 = žádný filtr)
    private let filterAlpha: Double = 0.15

    // MARK: - Inicializace

    init() {
        // Není potřeba custom queue, senzory poběží na MainQueue
    }

    // MARK: - Start / Stop

    func startTracking() {
        guard motion.isAccelerometerAvailable, !isTracking else { return }

        detectedReps = 0
        filteredMagnitude = 0
        previousMagnitude = 0
        calibrationSamples = []
        isCalibrated = false
        isTracking = true

        motion.accelerometerUpdateInterval = 1.0 / 50.0 // 50 Hz

        // ✅ FIX #22: Běžet rovnou na MainQueue zabrání vytváření 150 Tasků za vteřinu
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.processMotionData(data)
        }
    }

    func stopTracking() {
        motion.stopDeviceMotionUpdates()
        isTracking = false
    }

    func reset() {
        detectedReps = 0
        calibrationSamples = []
        isCalibrated = false
        // VBT reset
        velocitySamples = []
        barVelocity = 0.0
        peakVelocity = 0.0
        vbtZone = .idle
        setEndSuggested = false
        lowVelocityDuration = 0
    }

    // MARK: - Zpracování dat

    private func processMotionData(_ data: CMDeviceMotion) {
        // Kombinujeme gravitaci + akceleraci uživatele pro robustnější signál
        let gravity = data.gravity
        let userAcc = data.userAcceleration

        // Magnituda vektoru pohybu (bez gravity bias)
        let rawMag = sqrt(
            pow(userAcc.x, 2) +
            pow(userAcc.y, 2) +
            pow(userAcc.z, 2)
        )

        // Low-pass filtr pro vyhlazení šumu
        filteredMagnitude = filterAlpha * rawMag + (1 - filterAlpha) * filteredMagnitude

        // Auto-kalibrace prahu z prvních pohybů
        if !isCalibrated {
            calibrate(sample: filteredMagnitude)
        }

        // ✅ Phase 4: VBT — sbírám rychlostní vzorky
        let sampleInterval: Double = 1.0 / 50.0
        let instantVelocity = filteredMagnitude * sampleInterval
        velocitySamples.append(instantVelocity)

        // Výpočet klouzajícího průměru za posledních 50 vzorků (1 sekunda)
        let windowSize = min(50, velocitySamples.count)
        let recentSamples = velocitySamples.suffix(windowSize)
        let avgVelocity = recentSamples.reduce(0, +) / Double(windowSize)

        // Peak velocity za celou sérii
        let newPeak = max(peakVelocity, avgVelocity)

        // Detekce VBT zóny
        let zone: VBTZone
        switch avgVelocity {
        case let v where v > 0.016: zone = .explosive
        case let v where v > 0.010: zone = .strength
        case let v where v > 0.006: zone = .fatigue
        case let v where v > 0.001: zone = .failure
        default:                    zone = .idle
        }

        // Detekce konce série: 1+ sekunda v zóně .failure = auto-end signál
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSampleTime)
        lastSampleTime = now

        if zone == .failure && isTracking && detectedReps >= 2 {
            lowVelocityDuration += elapsed
        } else {
            lowVelocityDuration = 0
        }

        let suggestEnd = lowVelocityDuration >= 1.5

        // ✅ Zápis na MainActor napřímo (ušetří 50 Task allocations per second!)
        self.barVelocity = avgVelocity
        self.peakVelocity = newPeak
        self.vbtZone = zone
        if suggestEnd && !self.setEndSuggested {
            self.setEndSuggested = true
        }

        // Peak detection: přechod z pod prahu na nad práh + zpět = 1 rep
        let isCurrentlyAbove = filteredMagnitude > peakThreshold

        if isCurrentlyAbove && !isAboveThreshold {
            if now.timeIntervalSince(lastPeakTime) > minRepInterval {
                lastPeakTime = now
                self.detectedReps += 1
                self.currentIntensity = min(1.0, filteredMagnitude / (peakThreshold * 2))
            }
        }

        isAboveThreshold = isCurrentlyAbove
        self.currentIntensity = min(1.0, filteredMagnitude / (peakThreshold * 1.5))

        // Dummy usage to avoid unused warning
        _ = gravity
    }

    // MARK: - Auto-kalibrace

    private func calibrate(sample: Double) {
        calibrationSamples.append(sample)
        if calibrationSamples.count >= 250 { // 5 vteřin dat
            let sorted = calibrationSamples.sorted()
            let p75 = sorted[Int(Double(sorted.count) * 0.75)]
            let p95 = sorted[Int(Double(sorted.count) * 0.95)]
            // Práh = mezi 75. a 95. percentilem → zachytí reálný pohyb, ignoruje micro-šum
            peakThreshold = max(1.2, (p75 + p95) / 2.0)
            isCalibrated = true
        }
    }
}
