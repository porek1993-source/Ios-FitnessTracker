// FluidBackground.swift
// Prémiové "Liquid Design" pozadí využívající MeshGradient (iOS 18+).
// Vytváří organický, plynulý efekt inspirovaný Apple Fitness+.

import SwiftUI

struct FluidBackground: View {
    @State private var t: Float = 0
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ].map { .init(x: $0[0] + sin(t + Float($0[0])) * 0.1, y: $0[1] + cos(t + Float($0[1])) * 0.1) },
                colors: [
                    AppColors.background, AppColors.background.opacity(0.8), AppColors.secondaryBg,
                    AppColors.primaryAccent.opacity(0.15), AppColors.secondaryBg, AppColors.background,
                    AppColors.background, AppColors.accentCyan.opacity(0.1), AppColors.background
                ]
            )
            .ignoresSafeArea()
            .onReceive(timer) { _ in
                t += 0.02
            }
        } else {
            // Fallback pro starší iOS — plynulý lineární gradient s animací
            ZStack {
                AppColors.background.ignoresSafeArea()
                LinearGradient(
                    colors: [
                        AppColors.primaryAccent.opacity(0.12),
                        AppColors.accentCyan.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .hueRotation(.degrees(Double(t) * 10))
                .onReceive(timer) { _ in
                    t += 0.05
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    FluidBackground()
}
