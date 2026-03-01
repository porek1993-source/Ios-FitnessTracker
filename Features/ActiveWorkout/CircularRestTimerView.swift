// CircularRestTimerView.swift
// Agilní Fitness Trenér — Pohlcující animovaný časovač odpočinku

import SwiftUI

struct CircularRestTimerView: View {
    let progress: Double
    let timeFormatted: String
    let secondsRemaining: Int
    
    let onAdjust: (Int) -> Void
    let onSkip: () -> Void
    
    @State private var breathScale: CGFloat = 1.0
    @State private var breathOpacity: Double = 0.4
    
    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                // Background breathable glow
                Circle()
                    .fill(Color.cyan.opacity(breathOpacity))
                    .frame(width: 220, height: 220)
                    .scaleEffect(breathScale)
                    .blur(radius: 20)
                
                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 14)
                    .frame(width: 200, height: 200)
                
                // Animated progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [Color(red: 0.20, green: 0.52, blue: 1.0).opacity(0.6), Color.cyan, Color.cyan.opacity(0.8)],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: progress)
                
                // Text content in the center
                VStack(spacing: 4) {
                    Text(timeFormatted)
                        .font(.system(size: 64, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.spring(response: 0.25), value: secondsRemaining)
                    
                    Text("NÁDECH / VÝDECH")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.35))
                        .kerning(3)
                }
            }
            .padding(.top, 16)
            .onAppear {
                startBreathingAnimation()
            }
            .onChange(of: secondsRemaining) { oldValue, newValue in
                // Keep animation alive or sync it if needed, but repeatForever is usually enough
            }
            
            // Controls
            HStack(spacing: 16) {
                AdjustButton(label: "−15s", action: { onAdjust(-15) })
                
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSkip()
                } label: {
                    Text("Přeskočit pauzu")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: .white.opacity(0.25), radius: 16, y: 6)
                        )
                }
                .buttonStyle(.plain)
                
                AdjustButton(label: "+15s", action: { onAdjust(+15) })
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    private func startBreathingAnimation() {
        // Typical breathing cycle: 4s inhale, 4s exhale
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            breathScale = 1.15
            breathOpacity = 0.15
        }
    }
}

private struct AdjustButton: View {
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(label)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 72, height: 56)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}
