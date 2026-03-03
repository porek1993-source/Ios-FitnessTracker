// HealthKitTypes.swift
// ✅ OPRAVA: Modernizováno na iOS 17+ API — přímé inicializátory místo force-unwrap
//    pattern HKQuantityType.quantityType(forIdentifier:)

import HealthKit

// MARK: - HealthKit Read Types

enum HealthKitReadTypes {
    /// Všechny typy dat, které aplikace čte z Apple Health.
    static let all: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [
            // Srdeční funkce (iOS 17+ přímé inicializátory — bez force-unwrap)
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            // Dýchání & SpO2
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.oxygenSaturation),
            // Aktivita
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.stepCount),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.appleStandTime),
            // Tělesné měření
            HKQuantityType(.bodyMass),
            // Tréninky (pro external activity detection)
            HKObjectType.workoutType(),
        ]
        // Spánek — categoryType vrací Optional (starší API), bezpečně vložíme pokud není nil
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        return types
    }()
}

// MARK: - HealthKit Write Types

enum HealthKitWriteTypes {
    /// Typy dat, do kterých aplikace zapisuje (silový trénink + kalorie).
    static let share: Set<HKSampleType> = [
        HKQuantityType(.activeEnergyBurned),
        HKObjectType.workoutType(),
    ]
}
