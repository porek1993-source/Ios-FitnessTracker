// StreakParticleView.swift
// Agilní Fitness Trenér — Particle Emitter odměna za týdenní streak
//
// Záměr:
//  • Při spuštění aplikace, pokud má uživatel aktivní streak ≥ 1 týden,
//    klesnou plamínky přes celou obrazovku (jako confetti v iMessage).
//  • Zobrazí se pouze jednou za den (AppStorage příznak).
//  • Canvas-based rendering — nulové UIKit závislosti, čistý SwiftUI.
//
// Výkon:
//  • TimelineView s .animation cadence — browser engine (CoreAnimation)
//    řídí refresh rate (ProMotion = 120fps, starší = 60fps).
//  • 16 částic maximum — přijatelné i pro iPhone SE.

import SwiftUI

// MARK: - Datový model jedné částice

private struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat           // Horizontální pozice (0–1 relativně k šířce)
    var y: CGFloat           // Vertikální pozice (0–1 relativně k výšce)
    var scale: CGFloat        // Měřítko (1.0 = plná velikost, zmenšuje se při pádu)
    var opacity: Double        // Průhlednost (fade-out ke konci)
    var speed: CGFloat         // Rychlost pádu (px/s)
    var horizontalDrift: CGFloat // Mírný horizontální drift (houpání)
    let emoji: String          // Emoji ikona (🔥 🟠 ⚡️)
    let rotationDir: Double    // Směr rotace (+1 / -1)
    var rotation: Double       // Aktuální rotace (stupně)
}

// MARK: - StreakParticleView

struct StreakParticleView: View {

    let streakCount: Int
    @AppStorage("streak_particles_shown_date") private var shownDateStr: String = ""
    @State private var particles: [Particle] = []
    @State private var isVisible = false

    private static let emojis = ["🔥", "🔥", "⚡️", "🟠", "✨"]

    var body: some View {
        GeometryReader { geo in
            if isVisible {
                TimelineView(.animation) { (timeline: TimelineViewDefaultContext) in
                    Canvas { ctx, size in
                        let now = timeline.date.timeIntervalSinceReferenceDate
                        for (idx, particle) in particles.enumerated() {
                            // Vykreslíme aktuální pozici přes TimelineView date
                            let yOffset = particle.y * size.height
                            let xOffset = particle.x * size.width + particle.horizontalDrift * sin(now * 2.0 + Double(idx))
                            let scl = max(0.1, particle.scale)
                            let transform = CGAffineTransform(translationX: xOffset, y: yOffset)
                                .scaledBy(x: scl, y: scl)
                                .rotated(by: particle.rotation * .pi / 180.0)
                            
                            var contextCopy = ctx
                            contextCopy.transform = transform
                            
                            if let symbol = contextCopy.resolveSymbol(id: particle.emoji) {
                                contextCopy.draw(
                                    symbol,
                                    at: .zero
                                )
                            }
                        }
                    } symbols: {
                        ForEach(Self.emojis, id: \.self) { emoji in
                            Text(emoji).font(.system(size: 28)).tag(emoji)
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            let today = ISO8601DateFormatter().string(from: .now).prefix(10)
            guard String(today) != shownDateStr else { return }
            guard streakCount >= 1 else { return }
            shownDateStr = String(today)
            spawnParticles()
            isVisible = true
            animateParticles()
        }
    }

    // MARK: - Spawnování částic

    private func spawnParticles() {
        let count = min(16, 8 + streakCount * 2)  // Více plamínků za vyšší streak
        particles = (0..<count).map { _ in
            Particle(
                x: CGFloat.random(in: 0.05...0.95),
                y: CGFloat.random(in: -0.3...0.0),   // Start nad obrazovkou
                scale: CGFloat.random(in: 0.6...1.2),
                opacity: Double.random(in: 0.8...1.0),
                speed: CGFloat.random(in: 220...420),
                horizontalDrift: CGFloat.random(in: -20...20),
                emoji: Self.emojis.randomElement() ?? "🔥",
                rotationDir: Bool.random() ? 1 : -1,
                rotation: Double.random(in: -15...15)
            )
        }
    }

    // MARK: - Animace pádu

    private func animateParticles() {
        for idx in particles.indices {
            let duration = Double.random(in: 1.4...2.8)
            let delay    = Double.random(in: 0.0...0.6)

            withAnimation(.easeIn(duration: duration).delay(delay)) {
                particles[idx].y       = 1.2   // Padnout pod obrazovku
                particles[idx].opacity = 0.0
                particles[idx].scale   = 0.3
                particles[idx].rotation += particles[idx].rotationDir * 180
            }
        }

        // Po dokončení animace skrýt view a uvolnit paměť
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = false
            }
            particles = []
        }
    }
}
