import SwiftUI
import HealthKit

// MARK: - LiveHeartRateManager
//
// ✅ OPRAVA: Nahrazuje mock Timer skutečným HKAnchoredObjectQuery pro live HR ze Apple Watch.
//
// Jak to funguje:
//   • HKAnchoredObjectQuery s `updateHandler` — systém zavolá handler pokaždé, kdy
//     Apple Watch zapíše nový HR sample (typicky každých 5s během aktivity).
//   • Fallback: Pokud HealthKit není autorizován nebo Apple Watch není spárovaná,
//     zobrazí se placeholder "– –" bez havárie.
//   • Query se spustí na startMonitoring() a zastaví na stopMonitoring().

@MainActor
final class LiveHeartRateManager: ObservableObject {

    @Published var currentBPM: Double?       // nil = dosud nepřečteno / nedostupné
    @Published var isMonitoring: Bool = false

    private let store    = HKHealthStore()
    private var query:    HKAnchoredObjectQuery?
    private var anchor:   HKQueryAnchor?

    private let hrType = HKQuantityType(.heartRate)
    private let hrUnit = HKUnit(from: "count/min")

    // MARK: - Public API

    func startMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else {
            AppLogger.warning("[HRZonedRestTimer] HealthKit není dostupný na tomto zařízení.")
            return
        }
        guard store.authorizationStatus(for: hrType) != .sharingDenied else {
            AppLogger.warning("[HRZonedRestTimer] Přístup k HR dat byl odepřen — nelze monitorovat tep.")
            return
        }

        // Initial fetch: HR vzorky z posledních 60 sekund
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-60),
            end: nil,
            options: .strictStartDate
        )

        let anchoredQuery = HKAnchoredObjectQuery(
            type: hrType,
            predicate: predicate,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samplesOrNil, _, newAnchor, error in
            guard let self else { return }
            if let error {
                AppLogger.error("[HRZonedRestTimer] Chyba počátečního dotazu: \(error.localizedDescription)")
                return
            }
            self.anchor = newAnchor
            self.process(samples: samplesOrNil)
        }

        // Live update handler — volaný při každém novém HR samplu z Apple Watch
        anchoredQuery.updateHandler = { [weak self] _, samplesOrNil, _, newAnchor, error in
            guard let self else { return }
            if let error {
                AppLogger.error("[HRZonedRestTimer] Update handler chyba: \(error.localizedDescription)")
                return
            }
            self.anchor = newAnchor
            self.process(samples: samplesOrNil)
        }

        store.execute(anchoredQuery)
        query = anchoredQuery
        isMonitoring = true
        AppLogger.info("[HRZonedRestTimer] Live HR monitoring spuštěn.")
    }

    func stopMonitoring() {
        if let q = query {
            store.stop(q)
            query = nil
        }
        isMonitoring = false
        AppLogger.info("[HRZonedRestTimer] Live HR monitoring zastaven.")
    }

    // MARK: - Private

    private func process(samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample],
              let latest = quantitySamples.sorted(by: { $0.startDate < $1.startDate }).last
        else { return }

        let bpm = latest.quantity.doubleValue(for: hrUnit)
        Task { @MainActor in
            self.currentBPM = bpm
        }
    }
}

// MARK: - HRZonedRestTimer View

struct HRZonedRestTimer: View {
    let targetBPM: Double
    let onTargetReached: () -> Void

    @StateObject private var hrManager = LiveHeartRateManager()
    @State private var hasReachedTarget = false
    @State private var peakBPM: Double = 160.0  // Zachytíme nejvyšší tep pro progress výpočet

    private var displayBPM: String {
        guard let bpm = hrManager.currentBPM else { return "– –" }
        return "\(Int(bpm))"
    }

    private var progress: Double {
        guard let bpm = hrManager.currentBPM else { return 0 }
        let range = peakBPM - targetBPM
        guard range > 0 else { return 1.0 }
        return min(max((peakBPM - bpm) / range, 0), 1)
    }

    private var statusColor: Color {
        if hasReachedTarget { return .green }
        if hrManager.currentBPM == nil { return .gray }
        return .red
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: progress)
                    .shadow(color: statusColor.opacity(0.4), radius: 8)

                VStack(spacing: 2) {
                    Image(systemName: hrManager.currentBPM == nil ? "applewatch" : "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(statusColor)
                        .symbolEffect(.pulse, options: .repeating, isActive: !hasReachedTarget)

                    Text(displayBPM)
                        .font(.system(size: hrManager.currentBPM == nil ? 28 : 38,
                                      weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.default, value: displayBPM)

                    Text("BPM")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            VStack(spacing: 4) {
                Group {
                    if hasReachedTarget {
                        Text("MŮŽEŠ JET!")
                            .foregroundStyle(.green)
                    } else if hrManager.currentBPM == nil {
                        Text("ČEKÁM NA APPLE WATCH")
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Text("ZKLIDŇOVÁNÍ")
                            .foregroundStyle(.white)
                    }
                }
                .font(.system(size: 16, weight: .black))

                Text("Cíl: Pod \(Int(targetBPM)) BPM")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .onAppear { hrManager.startMonitoring() }
        .onDisappear { hrManager.stopMonitoring() }
        .onChange(of: hrManager.currentBPM) { _, newBPM in
            guard let bpm = newBPM else { return }
            // Aktualizuj peak BPM (zachytíme nejvyšší hodnotu pro správný progress bar)
            if bpm > peakBPM { peakBPM = bpm }
            if bpm <= targetBPM && !hasReachedTarget {
                hasReachedTarget = true
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                onTargetReached()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HRZonedRestTimer(targetBPM: 110.0, onTargetReached: {
            AppLogger.info("[HRZonedRestTimer] Zóna dosažena!")
        })
    }
}
