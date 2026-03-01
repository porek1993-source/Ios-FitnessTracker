import SwiftUI
import HealthKit

// MARK: - HealthKit HR Manager (Mocked for Demo / real implementation needs HKHealthStore)
@MainActor
class LiveHeartRateManager: ObservableObject {
    @Published var currentBPM: Double = 135.0 // Fake initial
    private var timer: Timer?
    
    func startMocking() {
        // Simulujeme postupný pokles tepu během odpočinku
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.currentBPM > 90 {
                    // Klesání o náhodný krok
                    self.currentBPM -= Double.random(in: 0.5...2.5)
                }
            }
        }
    }
    
    func stopMocking() {
        timer?.invalidate()
        timer = nil
    }
}

struct HRZonedRestTimer: View {
    let targetBPM: Double
    let onTargetReached: () -> Void
    
    @StateObject private var hrManager = LiveHeartRateManager()
    @State private var hasReachedTarget = false
    
    var progress: Double {
        // Výpočet pro kruhový ukazatel (1.0 = úplně v klidu)
        // Předpokládáme max tep 180, cíl např 110.
        // Chceme, aby timer ukazoval postup k cíli.
        let startingBPM = 160.0
        let range = startingBPM - targetBPM
        if range <= 0 { return 1.0 }
        
        let currentDrop = startingBPM - hrManager.currentBPM
        var p = currentDrop / range
        if p < 0 { p = 0 }
        if p > 1 { p = 1 }
        return p
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Pozadí kruhu
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 150, height: 150)
                
                // Aktivní kruh (Zezelená po dosažení)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(hasReachedTarget ? Color.green : Color.red, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: progress)
                    .shadow(color: hasReachedTarget ? Color.green.opacity(0.5) : Color.red.opacity(0.3), radius: 8)
                
                // Hodnoty uvnitř kruhu
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(hasReachedTarget ? .green : .red)
                        .symbolEffect(.pulse, options: .repeating, isActive: !hasReachedTarget)
                    
                    Text("\(Int(hrManager.currentBPM))")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.default, value: Int(hrManager.currentBPM))
                    
                    Text("BPM")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            VStack(spacing: 4) {
                Text(hasReachedTarget ? "MŮŽEŠ JET!" : "ZKLIDŇOVÁNÍ")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(hasReachedTarget ? .green : .white)
                
                Text("Cíl: Pod \(Int(targetBPM)) BPM")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
        .onAppear {
            hrManager.startMocking()
        }
        .onDisappear {
            hrManager.stopMocking()
        }
        .onChange(of: hrManager.currentBPM) { _, newBPM in
            if newBPM <= targetBPM && !hasReachedTarget {
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
            print("Zóna dosažena!")
        })
    }
}
