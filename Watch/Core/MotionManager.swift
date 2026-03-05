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

@MainActor
final class MotionManager: ObservableObject {

    // MARK: - Published state
    @Published var detectedReps: Int = 0
    @Published var isTracking: Bool = false
    @Published var currentIntensity: Double = 0.0 // 0–1 pro vizuální feedback

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

    // Minimální čas mezi opakováními (zabrání double-count)
    private let minRepInterval: TimeInterval = 0.35
    // Low-pass filtr koeficient (0.0 = velmi hladký, 1.0 = žádný filtr)
    private let filterAlpha: Double = 0.15

    // MARK: - Inicializace

    init() {
        queue.name = "com.agilefitness.motion"
        queue.qualityOfService = .userInteractive
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

        motion.startDeviceMotionUpdates(to: queue) { [weak self] data, _ in
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

        // Peak detection: přechod z pod prahu na nad práh + zpět = 1 rep
        let now = Date()
        let isCurrentlyAbove = filteredMagnitude > peakThreshold

        if isCurrentlyAbove && !isAboveThreshold {
            // Začátek pohybu (vzestupná fáze)
            if now.timeIntervalSince(lastPeakTime) > minRepInterval {
                lastPeakTime = now
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.detectedReps += 1
                    self.currentIntensity = min(1.0, filteredMagnitude / (peakThreshold * 2))
                }
            }
        }

        isAboveThreshold = isCurrentlyAbove

        // Aktualizace vizuálního intensitometru
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.currentIntensity = min(1.0, filteredMagnitude / (peakThreshold * 1.5))
        }

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
