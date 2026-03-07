// HealthKitNutritionService.swift
// Opt-in čtení nutričních a spánkových dat z Apple HealthKit
// Používá se POUZE pokud uživatel udělí oprávnění (health.healthKitAuthorized = true).
// AI trenér tyto data vkládá do kontextu pro úpravu objemu tréninku.

import Foundation
import HealthKit

/// Denní biomarkery získané z HealthKit (opt-in).
struct DailyReadiness {
    var proteinG:        Double = 0      // Celkový příjem bílkovin [g] za posledních 24h
    var kcalConsumed:    Double = 0      // Příjem kalorií [kcal] za posledních 24h
    var sleepHours:      Double = 0      // Celkový spánek [hod] za poslední noc
    var deepSleepHours:  Double = 0      // Hluboký spánek [hod]
    var isDataAvailable: Bool   = false  // false = uživatel nedal oprávnění nebo data nejsou

    /// Textový popis pro AI kontext
    var aiContextBlock: String {
        guard isDataAvailable else { return "" }
        var lines: [String] = ["--- BIOMARKERS (HealthKit, opt-in) ---"]
        if proteinG > 0   { lines.append("Protein: \(Int(proteinG))g za 24h") }
        if kcalConsumed > 0 { lines.append("Kalorie: \(Int(kcalConsumed)) kcal za 24h") }
        if sleepHours > 0 { lines.append("Spánek: \(String(format: "%.1f", sleepHours))h (hluboký: \(String(format: "%.1f", deepSleepHours))h)") }

        // Varování při deficitu / špatném spánku
        if proteinG > 0 && proteinG < 80 {
            lines.append("⚠️ NÍZKÝ PŘÍJEM BÍLKOVIN — doporučuji snížit celkový objem tréninku o 10–15%")
        }
        if sleepHours < 6 {
            lines.append("⚠️ NEDOSTATEK SPÁNKU — eliminuj doplňkové série, zameř se pouze na základní pohyby")
        }
        lines.append("---")
        return lines.joined(separator: "\n")
    }
}

@MainActor
final class HealthKitNutritionService: ObservableObject {

    static let shared = HealthKitNutritionService()

    @Published var readiness: DailyReadiness = DailyReadiness()

    private let store = HKHealthStore()

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let p = HKQuantityType.quantityType(forIdentifier: .dietaryProtein)       { types.insert(p) }
        if let k = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed){ types.insert(k) }
        if let s = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)         { types.insert(s) }
        return types
    }()

    private init() {}

    // MARK: - Autorizace

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            await fetchAll()
            return true
        } catch {
            AppLogger.warning("[HealthKitNutrition] Autorizace selhala: \(error)")
            return false
        }
    }

    // MARK: - Fetch vše

    func fetchAll() async {
        async let protein  = fetchNutrient(.dietaryProtein, unit: .gram())
        async let calories = fetchNutrient(.dietaryEnergyConsumed, unit: .kilocalorie())
        async let sleep    = fetchSleep()

        var r = DailyReadiness()
        r.proteinG     = await protein
        r.kcalConsumed = await calories
        (r.sleepHours, r.deepSleepHours) = await sleep
        r.isDataAvailable = r.proteinG > 0 || r.kcalConsumed > 0 || r.sleepHours > 0

        readiness = r
        AppLogger.info("[HealthKitNutrition] Readiness: protein=\(Int(r.proteinG))g, kcal=\(Int(r.kcalConsumed)), sleep=\(String(format: "%.1f", r.sleepHours))h")
    }

    // MARK: - Helpers

    private func fetchNutrient(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let val = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: val)
            }
            store.execute(query)
        }
    }

    private func fetchSleep() async -> (total: Double, deep: Double) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (0, 0)
        }
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 50, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                var totalSeconds: Double = 0
                var deepSeconds:  Double = 0
                for sample in (samples as? [HKCategorySample]) ?? [] {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    // ✅ FIX: Počítáme jen fáze spánku, ne "v posteli" (eliminuje double-count iPhone + Watch)
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        totalSeconds += duration
                        deepSeconds += duration
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                         HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                         HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        totalSeconds += duration
                    default:
                        break // inBed — nezapočítáváme (duplicátní data)
                    }
                }
                continuation.resume(returning: (totalSeconds / 3600, deepSeconds / 3600))
            }
            self.store.execute(query)
        }
    }
}
