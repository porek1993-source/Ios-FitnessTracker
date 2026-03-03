// HealthKitWorkoutWriter.swift
// Agilní Fitness Trenér — Zápis tréninku do Apple Health
//
// Přidej do HealthKitTypes.swift:
//   static let shareTypes: Set<HKSampleType> = [
//       .workoutType(),
//       HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
//   ]
//
// Přidej do HealthKitService.requestAuthorization():
//   try await store.requestAuthorization(
//       toShare: HealthKitWriteTypes.share,
//       read: HealthKitReadTypes.all
//   )

import HealthKit
import Foundation

// MARK: - Result

struct HealthKitWriteResult {
    let success: Bool
    let hkWorkoutID: UUID?
    let caloriesWritten: Double?
    let error: Error?

    static func failure(_ error: Error) -> Self {
        HealthKitWriteResult(success: false, hkWorkoutID: nil, caloriesWritten: nil, error: error)
    }
}

// MARK: - Writer

/// Zapíše `WorkoutSession` jako `HKWorkout` (Traditional Strength Training) do Apple Health.
/// Pokud máme oprávnění, zapíše také aktivní kalorie jako `HKQuantitySample`.
@MainActor
final class HealthKitWorkoutWriter {

    private let store = HKHealthStore()

    // MARK: - Public API

    /// Hlavní metoda — zavolej po dokončení tréninku.
    /// `bodyWeightKg` — reálná váha uživatele z `UserProfile.weightKg` pro přesný odhad kalorií.
    func write(session: WorkoutSession, bodyWeightKg: Double = 75.0) async -> HealthKitWriteResult {
        guard HKHealthStore.isHealthDataAvailable() else {
            return HealthKitWriteResult.failure(WriterError.healthKitUnavailable)
        }

        // Kontrola oprávnění k zápisu
        guard canWrite(.workoutType()) else {
            return HealthKitWriteResult.failure(WriterError.notAuthorized)
        }

        let start    = session.startedAt
        let end      = session.finishedAt ?? .now
        let duration = end.timeIntervalSince(start)

        // Spočítej kalorie z odjetých sérií
        let estimatedCalories = estimateCalories(
            session: session,
            durationSeconds: duration,
            bodyWeightKg: bodyWeightKg
        )

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        do {
            try await builder.beginCollection(at: start)
            
            // Přidáme kalorie jako vzorky ( samples)
            if let kcal = estimatedCalories, canWrite(HKQuantityType(.activeEnergyBurned)) {
                let calType   = HKQuantityType(.activeEnergyBurned)
                let calQty    = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
                let calSample = HKQuantitySample(
                    type:     calType,
                    quantity: calQty,
                    start:    start,
                    end:      end,
                    metadata: [HKMetadataKeyWasUserEntered: false]
                )
                try await builder.addSamples([calSample])
            }
            
            try await builder.endCollection(at: end)
            
            let metadata: [String: Any] = [
                HKMetadataKeyWorkoutBrandName: "Agilní Fitness Trenér",
                HKMetadataKeyIndoorWorkout: true
            ]
            // ✅ FIX: NSDictionary bridge pro Swift 6 asynchronní bezpečnost
            try await builder.addMetadata(metadata as NSDictionary as! [String: Any])
            
            let workout = try await builder.finishWorkout()
            
            return HealthKitWriteResult(
                success: true,
                hkWorkoutID: workout?.uuid,
                caloriesWritten: estimatedCalories,
                error: nil
            )
        } catch {
            return HealthKitWriteResult.failure(error)
        }
    }

    // MARK: - Calorie Estimation

    /// MET-based odhad kalorií pro silový trénink.
    /// MET ~5.0 pro střední intenzitu, ~6.0 pro vysokou.
    private func estimateCalories(session: WorkoutSession, durationSeconds: TimeInterval, bodyWeightKg: Double) -> Double? {
        // Pokud nemáme žádné sety, nezapisujeme kalorie
        let totalSets = session.exercises.reduce(0) { $0 + $1.completedSets.count }
        guard totalSets > 0 else { return nil }

        // MET závisí na intenzitě — více setů = vyšší intenzita
        let met: Double = totalSets > 15 ? 6.0 : 5.0
        let durationHours = durationSeconds / 3600.0

        let calories = met * bodyWeightKg * durationHours
        return max(calories, 50)  // minimum 50 kcal
    }

    // MARK: - Static Helpers (kompatibilita s HealthWorkoutWriter API)

    /// Jednoduchý odhad spálených kalorií podle délky tréninku.
    /// Použij `estimateCalories(session:durationSeconds:bodyWeightKg:)` pro přesnější výsledek.
    static func estimateBurnedCalories(durationSeconds: TimeInterval) -> Double {
        let minutes = durationSeconds / 60.0
        return max(0, minutes * 5.0)
    }

    /// Convenience wrapper — vytvoří dočasnou instanci a zapíše trénink.
    /// Používej pokud nemáš přístup k `WorkoutSession` objektu (legacy API).
    static func saveStrengthWorkout(
        startDate: Date,
        endDate: Date,
        activeEnergyBurnedKcal: Double? = nil,
        metadata: [String: Any]? = nil
    ) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: startDate)
        // ✅ Bezpečné: HKQuantityType(.activeEnergyBurned) je dostupný od iOS 17 bez force-unwrap
        if let kcal = activeEnergyBurnedKcal {
            let energyType = HKQuantityType(.activeEnergyBurned)
            let energy = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
            let sample = HKQuantitySample(type: energyType, quantity: energy, start: startDate, end: endDate)
            try await builder.addSamples([sample])
        }
        if let metadata = metadata {
            // ✅ FIX: NSDictionary bridge pro Swift 6 asynchronní bezpečnost
            try await builder.addMetadata(metadata as NSDictionary as! [String: Any])
        }
        try await builder.endCollection(at: endDate)
        try await builder.finishWorkout()
        AppLogger.success("[HealthKitWorkoutWriter] Trénink zapsán do Apple Health (\(Int((endDate.timeIntervalSince(startDate)) / 60)) min, \(Int(activeEnergyBurnedKcal ?? 0)) kcal)")
    }

    // MARK: - Auth Check

    private func canWrite(_ type: HKSampleType) -> Bool {
        store.authorizationStatus(for: type) == .sharingAuthorized
    }
}

// MARK: - Errors

enum WriterError: LocalizedError {
    case healthKitUnavailable
    case notAuthorized
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .healthKitUnavailable: return "Apple Health není na tomto zařízení dostupný."
        case .notAuthorized:        return "Aplikace nemá oprávnění zapisovat do Apple Health."
        case .saveFailed(let msg):  return "Ukládání selhalo: \(msg)"
        }
    }
}
