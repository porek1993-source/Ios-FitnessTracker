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

        // Spočítej kalorie z odjetých sérií (hrubý odhad: MET × váha × čas)
        let estimatedCalories = estimateCalories(
            session: session,
            durationSeconds: duration
        )

        do {
            let workout = try buildWorkout(start: start, end: end, calories: estimatedCalories)
            try await saveWorkout(workout, calories: estimatedCalories, start: start, end: end)
            return WorkoutWriteResult(
                success: true,
                hkWorkoutID: workout.uuid,
                caloriesWritten: estimatedCalories,
                error: nil
            )
        } catch {
            return WorkoutWriteResult.failure(error)
        }
    }

    // MARK: - Build

    private func buildWorkout(
        start: Date,
        end: Date,
        calories: Double?
    ) throws -> HKWorkout {

        var metadata: [String: Any] = [
            HKMetadataKeyWorkoutBrandName: "Agilní Fitness Trenér",
            HKMetadataKeyIndoorWorkout: true
        ]

        // Kalorie do HKWorkout (deprecated v iOS 18 ale stále funkční pro starší iOS)
        var totalEnergy: HKQuantity?
        if let kcal = calories {
            totalEnergy = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
        }

        // iOS 17+ builder
        if #available(iOS 17.0, *) {
            return buildWithBuilder(start: start, end: end, calories: totalEnergy, metadata: metadata)
        } else {
            // Fallback pro iOS 16
            return HKWorkout(
                activityType: .traditionalStrengthTraining,
                start: start,
                end: end,
                duration: end.timeIntervalSince(start),
                totalEnergyBurned: totalEnergy,
                totalDistance: nil,
                metadata: metadata
            )
        }
    }

    @available(iOS 17.0, *)
    private func buildWithBuilder(
        start: Date,
        end: Date,
        calories: HKQuantity?,
        metadata: [String: Any]
    ) -> HKWorkout {
        var configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        // Pro iOS 17+ použijeme HKWorkoutBuilder async API
        // Ale pro jednoduchost a kompatibilitu vracíme starý inicializátor
        // (builder vyžaduje live session nebo HKWorkoutBuilder, což je mimo scope)
        return HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: start,
            end: end,
            workoutEvents: nil,
            totalEnergyBurned: calories,
            totalDistance: nil,
            metadata: metadata
        )
    }

    // MARK: - Save

    private func saveWorkout(
        _ workout: HKWorkout,
        calories: Double?,
        start: Date,
        end: Date
    ) async throws {
        try await store.save(workout)

        // Zapiš kalorie jako asociovaný sample (přesnější než totalEnergyBurned)
        if let kcal = calories, canWrite(HKQuantityType(.activeEnergyBurned)) {
            let calType   = HKQuantityType(.activeEnergyBurned)
            let calQty    = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
            let calSample = HKQuantitySample(
                type:     calType,
                quantity: calQty,
                start:    start,
                end:      end,
                metadata: [HKMetadataKeyWasUserEntered: false]
            )
            try await store.addSamples([calSample], to: workout)
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
