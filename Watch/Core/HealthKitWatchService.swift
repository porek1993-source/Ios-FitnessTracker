// HealthKitWatchService.swift
// HealthKit na hodinkách — HKWorkoutSession + živý tep

import HealthKit
import Foundation

@MainActor
final class HealthKitWatchService: NSObject, ObservableObject {

    // MARK: - Published state
    @Published var heartRate: Int      = 0
    @Published var heartRateZone: HeartRateZone = .rest
    @Published var activeCalories: Double = 0.0
    @Published var isSessionActive: Bool = false
    @Published var authorizationStatus: HealthAuthStatus = .unknown

    // MARK: - Private
    private let store          = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    // Odhadnutá Max TF (220 - věk) — výchozí 35 let pokud neznáme profil
    var estimatedMaxHR: Double = 185

    // MARK: - Autorizace a spuštění

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .unavailable
            return
        }

        let toShare: Set<HKSampleType> = [HKQuantityType(.activeEnergyBurned),
                                          HKObjectType.workoutType()]
        let toRead: Set<HKObjectType> = [HKQuantityType(.heartRate),
                                         HKQuantityType(.activeEnergyBurned)]
        do {
            try await store.requestAuthorization(toShare: toShare, read: toRead)
            authorizationStatus = .authorized
        } catch {
            authorizationStatus = .denied
        }
    }

    func startWorkoutSession() async {
        guard authorizationStatus == .authorized else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        do {
            let ws = try HKWorkoutSession(healthStore: store, configuration: config)
            let lb = ws.associatedWorkoutBuilder()
            lb.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

            ws.delegate  = self
            lb.delegate  = self

            self.session = ws
            self.builder = lb

            ws.startActivity(with: Date())
            try await lb.beginCollection(at: Date())
            isSessionActive = true
        } catch {
            print("[Watch] HKWorkoutSession chyba: \(error)")
        }
    }

    func endWorkoutSession() async {
        guard let session, let builder else { return }
        session.end()
        do {
            try await builder.endCollection(at: Date())
            _ = try await builder.finishWorkout()
        } catch { /* logujeme ale nespadneme */ }
        // ✅ FIX: Uvolni reference na ukončenou session/builder (prevence resource leak a konfliktu při dalším tréninku)
        self.session = nil
        self.builder = nil
        isSessionActive = false
    }

    // MARK: - Tepové pásmo

    enum HeartRateZone: String {
        case rest       = "Klid"
        case warmup     = "Zahřívání"       // < 60% max
        case fatBurn    = "Spalování"       // 60–70% max
        case cardio     = "Kardio"          // 70–80% max
        case peak       = "Maximum"         // 80–90% max
        case red        = "Přetížení"       // > 90% max (REST!)

        var color: String {                              // Vrátíme názvy preset barev
            switch self {
            case .rest:    return "gray"
            case .warmup:  return "green"
            case .fatBurn: return "mint"
            case .cardio:  return "yellow"
            case .peak:    return "orange"
            case .red:     return "red"
            }
        }

        var icon: String {
            switch self {
            case .rest:    return "heart.fill"
            case .warmup:  return "heart.fill"
            case .fatBurn: return "heart.fill"
            case .cardio:  return "heart.fill"
            case .peak:    return "flame.fill"
            case .red:     return "exclamationmark.heart.fill"
            }
        }
    }

    enum HealthAuthStatus { case unknown, authorized, denied, unavailable }
}

// MARK: - HKWorkoutSessionDelegate

extension HealthKitWatchService: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) { /* state management handled via builder */ }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.isSessionActive = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension HealthKitWatchService: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }
                let stats = workoutBuilder.statistics(for: quantityType)

                switch quantityType {
                case HKQuantityType(.heartRate):
                    if let bpm = stats?.mostRecentQuantity()?.doubleValue(for: .init(from: "count/min")) {
                        self.heartRate = Int(bpm)
                        self.heartRateZone = self.zone(for: bpm)
                    }
                case HKQuantityType(.activeEnergyBurned):
                    if let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        self.activeCalories = kcal
                    }
                default: break
                }
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    private func zone(for bpm: Double) -> HeartRateZone {
        let pct = bpm / estimatedMaxHR
        switch pct {
        case ..<0.50: return .rest
        case 0.50..<0.60: return .warmup
        case 0.60..<0.70: return .fatBurn
        case 0.70..<0.80: return .cardio
        case 0.80..<0.90: return .peak
        default: return .red
        }
    }
}
