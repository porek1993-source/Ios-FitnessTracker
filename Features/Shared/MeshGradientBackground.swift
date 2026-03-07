// MeshGradientBackground.swift
// Agilní Fitness Trenér — Organicky dýchající MeshGradient pozadí
//
// Princip:
//  • iOS 18+: MeshGradient se 9 kontrolními body (3×3 mřížka)
//  • Kontrolní body se pomalu posunují pomocí sin/cos časových offset
//    → vytváří dojem, že pozadí "dýchá" nebo "pulzuje" jako živý organismus
//  • iOS 17 fallback: RadialGradient (jako dříve) — aplikace zůstane funkční
//  • Výkon: TimelineView s .animation cadence (60fps kde hardware dovolí)
//  • Žádné GPU-intenzivní shadery — MeshGradient je nativně optimalizovaný Metal shader

import SwiftUI

struct MeshGradientBackground: View {

    var body: some View {
        if #available(iOS 18.0, *) {
            AnimatedMeshBackground()
                .ignoresSafeArea()
        } else {
            // iOS 17 fallback
            LegacyGradientBackground()
                .ignoresSafeArea()
        }
    }
}

// MARK: - iOS 18+ Animated Mesh

@available(iOS 18.0, *)
private struct AnimatedMeshBackground: View {

    // Offset poháněný časem (TimelineView → phase.date)
    @State private var phase: Double = 0

    // Základní barvy mřížky — tmavé, organické
    private let baseColors: [Color] = [
        // Řádek 1 (top)
        Color(red: 0.06, green: 0.08, blue: 0.15),
        Color(red: 0.08, green: 0.05, blue: 0.20),
        Color(red: 0.04, green: 0.08, blue: 0.18),
        // Řádek 2 (střed)
        Color(red: 0.10, green: 0.12, blue: 0.22),
        Color(red: 0.22, green: 0.28, blue: 0.55).opacity(0.35),   // Akcent — modrý glow
        Color(red: 0.05, green: 0.10, blue: 0.16),
        // Řádek 3 (bottom)
        Color(red: 0.05, green: 0.05, blue: 0.10),
        Color(red: 0.08, green: 0.06, blue: 0.14),
        Color(red: 0.04, green: 0.05, blue: 0.10),
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3, height: 3,
                points: animatedPoints(t: t),
                colors: animatedColors(t: t)
            )
        }
    }

    // MARK: Body body body — Animace pozic kontrolních bodů
    // Každý bod dostane malý offset přes sin/cos s různou frekvencí.
    // Výsledek: nenásilné "plovoucí" pohyby, žádné ostré skoky.
    private func animatedPoints(t: Double) -> [SIMD2<Float>] {
        let s: Double = 0.025  // Amplituda výkyvu (jak daleko se bod pohne)
        let spd: Double = 0.12 // Základní rychlost (nižší = pomalejší dýchání)

        return [
            // Řádek 1
            [0.0,       0.0      ],
            [Float(0.5 + s * sin(t * spd * 1.1)),          Float(0.0   + s * 0.5 * cos(t * spd * 0.9))],
            [1.0,       0.0      ],
            // Řádek 2
            [Float(0.0 + s * 0.6 * sin(t * spd * 0.8)),    Float(0.5   + s * cos(t * spd * 1.3))],
            [Float(0.5 + s * cos(t * spd * 1.0)),           Float(0.5   + s * sin(t * spd * 0.7))],
            [Float(1.0 - s * 0.6 * sin(t * spd * 1.2)),    Float(0.5   + s * cos(t * spd * 0.8))],
            // Řádek 3
            [0.0,       1.0      ],
            [Float(0.5 + s * sin(t * spd * 0.6)),           Float(1.0   - s * 0.4 * cos(t * spd * 1.4))],
            [1.0,       1.0      ],
        ].map { SIMD2<Float>(Float($0[0]), Float($0[1])) }
    }

    // Barvy se také jemně mění — centrální glow pulzuje
    private func animatedColors(t: Double) -> [Color] {
        let glowIntensity = 0.25 + 0.12 * sin(t * 0.15)
        var colors = baseColors
        colors[4] = Color(red: 0.22, green: 0.28, blue: 0.55).opacity(glowIntensity)
        return colors
    }
}

// MARK: - iOS 17 Fallback

private struct LegacyGradientBackground: View {
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            RadialGradient(
                colors: [AppColors.primaryAccent.opacity(0.20), .clear],
                center: .init(x: 0.75, y: 0.0),
                startRadius: 0, endRadius: 380
            )
            .ignoresSafeArea()
        }
    }
}
