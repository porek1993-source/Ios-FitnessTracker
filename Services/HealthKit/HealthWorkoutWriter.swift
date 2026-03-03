// HealthWorkoutWriter.swift
// Agilní Fitness Trenér — Zápis silového tréninku do Apple Health
//
// ⚠️ ZASTARALÉ: Tato třída je deprecated. Používej `HealthKitWorkoutWriter` (instance-based,
// zohledňuje váhu uživatele, má lepší kalorie odhad a moderní HKWorkoutBuilder API).
// Ponechána pouze pro zpětnou kompatibilitu — smažeme v příštím refactoringu.
import Foundation
import HealthKit

@available(*, deprecated, renamed: "HealthKitWorkoutWriter", message: "Použij HealthKitWorkoutWriter — viz Services/HealthKit/HealthKitWorkoutWriter.swift")
@MainActor
public final class HealthWorkoutWriter {
    public static let shared = HealthWorkoutWriter()
    private let healthStore = HKHealthStore()

    private init() {}

    /// Uloží trénink do Apple Health
    /// - Parameters:
    ///   - startDate: Začátek tréninku
    ///   - endDate: Konec tréninku
    ///   - activeEnergyBurnedKcal: Odhad spálených kalorií
    ///   - metadata: Dodatečná data (název rozpisu atd.)
    public func saveStrengthWorkout(
        startDate: Date,
        endDate: Date,
        activeEnergyBurnedKcal: Double? = nil,
        metadata: [String: Sendable]? = nil
    ) async throws {
        
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthError.unavailable
        }

        let energyType = HKQuantityType(.activeEnergyBurned)  // ✅ iOS 17+ API bez force-unwrap

        // Kontrola oprávnění (pokud uživatel neschválil write oprávnění, selže to)
        // Oprávnění by se mělo žádat v HealthBackgroundManager při onboardingu
        // try await healthStore.requestAuthorization(toShare: [workoutType, energyType], read: [])

        // ✅ Vytvoření WorkoutBuilderu (moderní iOS 17+ API)
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        
        try await builder.beginCollection(at: startDate)
        
        // ✅ Přidání energie (pokud je)
        if let kcal = activeEnergyBurnedKcal {
            let energy = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
            let sample = HKQuantitySample(type: energyType, quantity: energy, start: startDate, end: endDate)
            try await builder.addSamples([sample])
        }
        
        // ✅ Metadata
        if let metadata = metadata {
            try await builder.addMetadata(metadata)
        }
        
        try await builder.endCollection(at: endDate)
        
        // ✅ Dokončení a uložení
        guard let workout = try await builder.finishWorkout() else {
            throw HealthError.unavailable
        }
        
        AppLogger.success("[HealthWorkoutWriter] Úspěšně uložen HKWorkoutBuilder (.traditionalStrengthTraining), Cas: \(Int(workout.duration / 60)) min, Kcal: \(activeEnergyBurnedKcal ?? 0)")
    }

    /// Pomocná metoda pro jednoduchý odhad spálených kalorií na základě času a průměrné intenzity
    /// - Parameter duration: Délka tréninku v sekundách
    /// - Returns: Odhad spálených kilokalorií
    public static func estimateBurnedCalories(durationSeconds: TimeInterval) -> Double {
        // Zjednodušený odhad: Průměrný člověk pálí silovým tréninkem kolem 5 kcal / min
        let minutes = durationSeconds / 60.0
        return max(0, minutes * 5.0)
    }

    enum HealthError: Error, LocalizedError {
        case unavailable
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Apple Health není na tomto zařízení k dispozici."
            case .unauthorized: return "Aplikace nemá oprávnění k zápisu tréninku."
            }
        }
    }
}
