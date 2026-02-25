// HealthKitService.swift

import HealthKit
import Foundation

// MARK: - Summary structs returned by service

struct HKDailySummary {
    var sleepDurationHours: Double?
    var sleepEfficiencyPct: Double?
    var sleepDeepHours: Double?
    var sleepREMHours: Double?
    var hrv: Double?
    var restingHeartRate: Double?
    var respiratoryRate: Double?
    var activeCaloriesKcal: Double?
    var totalSteps: Int?
}

struct HKWorkoutSummary {
    var activityTypeName: String
    var durationMinutes: Int
    var totalEnergyKcal: Double
    var startDate: Date
}

// MARK: - Service

final class HealthKitService: ObservableObject {

    private let store = HKHealthStore()
    @Published var isAuthorized = false

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw AppError.healthKitUnavailable
        }
        try await store.requestAuthorization(
            toShare: HealthKitWriteTypes.share,
            read: HealthKitReadTypes.all
        )
        isAuthorized = true
    }

    func fetchDailySummary(for date: Date) async throws -> HKDailySummary {
        var summary = HKDailySummary()

        async let sleep   = fetchSleep(for: date)
        // HRV a klidový tep — hledáme i v noci (Apple Watch měří HRV během spánku)
        async let hrv     = fetchLatestQuantityOvernight(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), for: date)
        async let rhr     = fetchLatestQuantityOvernight(.restingHeartRate, unit: HKUnit(from: "count/min"), for: date)
        async let resp    = fetchLatestQuantity(.respiratoryRate, unit: HKUnit(from: "count/min"), for: date)
        async let cals    = fetchSumQuantity(.activeEnergyBurned, unit: .kilocalorie(), for: date)
        async let steps   = fetchSumQuantity(.stepCount, unit: .count(), for: date)

        let sleepResult   = try? await sleep
        summary.sleepDurationHours = sleepResult?.duration
        summary.sleepEfficiencyPct = sleepResult?.efficiency
        summary.sleepDeepHours     = sleepResult?.deepHours
        summary.sleepREMHours      = sleepResult?.remHours
        summary.hrv                = try? await hrv
        summary.restingHeartRate   = try? await rhr
        summary.respiratoryRate    = try? await resp
        summary.activeCaloriesKcal = try? await cals
        summary.totalSteps         = (try? await steps).map { Int($0) }

        return summary
    }

    func fetchExternalActivities(since date: Date) async throws -> [HKWorkoutSummary] {
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: date,
                end: .now,
                options: .strictStartDate
            )
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 20,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let summaries = (samples as? [HKWorkout] ?? []).compactMap { workout -> HKWorkoutSummary? in
                    // Filtruj pouze aktivity mimo posilovnu
                    let type = workout.workoutActivityType
                    guard type != .traditionalStrengthTraining else { return nil }
                    return HKWorkoutSummary(
                        activityTypeName: type.displayName,
                        durationMinutes: Int(workout.duration / 60),
                        totalEnergyKcal: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                        startDate: workout.startDate
                    )
                }
                continuation.resume(returning: summaries)
            }
            store.execute(query)
        }
    }

    // MARK: - Private helpers

    private struct SleepResult {
        var duration: Double
        var efficiency: Double
        var deepHours: Double
        var remHours: Double
    }

    private func fetchSleep(for date: Date) async throws -> SleepResult {
        // Okno spánku: od 18:00 předchozího dne do 12:00 dneška
        // Pokrývá večerní usnutí i ranní probuzení
        let start = date.startOfDay.addingTimeInterval(-6 * 3600)  // 18:00 předchozí den
        let end   = date.startOfDay.addingTimeInterval(12 * 3600)  // 12:00 dneška
        let predicate = HKQuery.predicateForSamples(withStart: start, end: min(end, .now))

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let sleepSamples = samples as? [HKCategorySample] ?? []
                
                // Rozlišení fází spánku
                var coreSeconds: Double = 0
                var deepSeconds: Double = 0
                var remSeconds: Double  = 0
                var totalInBedSeconds: Double = 0
                
                for sample in sleepSamples {
                    let dur = sample.endDate.timeIntervalSince(sample.startDate)
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        coreSeconds += dur
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        deepSeconds += dur
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        remSeconds += dur
                    case HKCategoryValueSleepAnalysis.inBed.rawValue:
                        totalInBedSeconds += dur
                    default:
                        break
                    }
                }
                
                let asleepSeconds = coreSeconds + deepSeconds + remSeconds
                // Pokud nemáme inBed data, použijeme celkový součet všech vzorků
                let bedSeconds = totalInBedSeconds > 0 ? totalInBedSeconds : sleepSamples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                
                let duration   = asleepSeconds / 3600
                let efficiency = bedSeconds > 0 ? (asleepSeconds / bedSeconds) * 100 : 0
                let deep       = deepSeconds / 3600
                let rem        = remSeconds / 3600
                
                continuation.resume(returning: SleepResult(
                    duration: duration,
                    efficiency: efficiency,
                    deepHours: deep,
                    remHours: rem
                ))
            }
            store.execute(query)
        }
    }

    /// Dotaz na nejnovější vzorek — pouze v rámci dnešního dne.
    private func fetchLatestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        for date: Date
    ) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(
            withStart: date.startOfDay,
            end: date.endOfDay
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Dotaz na nejnovější vzorek — rozšířené okno 12h zpátky pro noční měření (HRV, klidový tep).
    /// Apple Watch typicky měří HRV a RHR během spánku, takže data jsou z předchozího dne.
    private func fetchLatestQuantityOvernight(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        for date: Date
    ) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        // Hledáme od 18:00 předchozího dne do konce dnešního dne
        let start = date.startOfDay.addingTimeInterval(-6 * 3600)
        let end   = min(date.endOfDay, .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchSumQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        for date: Date
    ) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(
            withStart: date.startOfDay,
            end: date.endOfDay
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                let value = stats?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}

// MARK: - HKWorkoutActivityType display name

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .soccer:              return "Soccer"
        case .hockey:              return "Hockey"
        case .basketball:          return "Basketball"
        case .running:             return "Running"
        case .cycling:             return "Cycling"
        case .tennis:              return "Tennis"
        case .swimming:            return "Swimming"
        case .volleyball:          return "Volleyball"
        case .handball:            return "Handball"
        default:                   return "Other"
        }
    }
}
