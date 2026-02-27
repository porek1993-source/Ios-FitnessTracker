// HealthKitTypes.swift

import HealthKit

enum HealthKitReadTypes {
    static let all: Set<HKObjectType> = {
        let identifiers: [Any] = [
            HKCategoryTypeIdentifier.sleepAnalysis,
            HKQuantityTypeIdentifier.heartRate,
            HKQuantityTypeIdentifier.restingHeartRate,
            HKQuantityTypeIdentifier.heartRateVariabilitySDNN,
            HKQuantityTypeIdentifier.respiratoryRate,
            HKQuantityTypeIdentifier.oxygenSaturation,
            HKQuantityTypeIdentifier.activeEnergyBurned,
            HKQuantityTypeIdentifier.basalEnergyBurned,
            HKQuantityTypeIdentifier.stepCount,
            HKQuantityTypeIdentifier.appleExerciseTime,
            HKQuantityTypeIdentifier.appleStandTime,
            HKQuantityTypeIdentifier.bodyMass
        ]
        
        var types: Set<HKObjectType> = []
        for id in identifiers {
            if let qId = id as? HKQuantityTypeIdentifier, let type = HKQuantityType.quantityType(forIdentifier: qId) {
                types.insert(type)
            } else if let cId = id as? HKCategoryTypeIdentifier, let type = HKObjectType.categoryType(forIdentifier: cId) {
                types.insert(type)
            }
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()
}

enum HealthKitWriteTypes {
    static let share: Set<HKSampleType> = {
        var types: Set<HKSampleType> = []
        if let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(type)
        }
        types.insert(HKObjectType.workoutType())
        return types
    }()
}
