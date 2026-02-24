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

// MARK: - Write Types

enum HealthKitWriteTypes {
    static let share: Set<HKSampleType> = [
        .workoutType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    ]
}

// MARK: - Result

struct WorkoutWriteResult {
    let success: Bool
    let hkWorkoutID: UUID?
    let caloriesWritten: Double?
    let error: Error?

    static func failure(_ error: Error) -> Self {
        WorkoutWriteResult(success: false, hkWorkoutID: nil, caloriesWritten: nil, error: error)
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
    func write(session: WorkoutSession) async -> WorkoutWriteResult {
        guard HKHealthStore.isHealthDataAvailable() else {
            return WorkoutWriteResult.failure(WriterError.healthKitUnavailable)
        }

        // Kontrola oprávnění k zápisu
        guard canWrite(.workoutType()) else {
            return WorkoutWriteResult.failure(WriterError.notAuthorized)
        }

        let start    = session.startedAt
        let end      = session.finishedAt ?? .now
        let duration = end.timeIntervalSince(start)

        // Spočítej kalorie z odjetých sérií
        let estimatedCalories = estimateCalories(
            session: session,
            durationSeconds: duration
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
            try await builder.addMetadata(metadata)
            
            let workout = try await builder.finishWorkout()
            
            return WorkoutWriteResult(
                success: true,
                hkWorkoutID: workout?.uuid,
                caloriesWritten: estimatedCalories,
                error: nil
            )
        } catch {
            return WorkoutWriteResult.failure(error)
        }
    }

    // MARK: - Calorie Estimation

    /// MET-based odhad kalorií pro silový trénink.
    /// MET ~5.0 pro střední intenzitu, váha odhadnuta z objemu.
    private func estimateCalories(session: WorkoutSession, durationSeconds: TimeInterval) -> Double? {
        // Pokud nemáme žádné sety, nezapisujeme kalorie
        let totalSets = session.exercises.reduce(0) { $0 + $1.completedSets.count }
        guard totalSets > 0 else { return nil }

        // Průměrné MET pro silový trénink (ACSM standard)
        let met: Double = 5.0
        // Odhadneme váhu uživatele — ideálně z UserProfile, zde default 80 kg
        let bodyWeightKg: Double = 80.0
        let durationHours = durationSeconds / 3600.0

        let calories = met * bodyWeightKg * durationHours
        return max(calories, 50)  // minimum 50 kcal
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
