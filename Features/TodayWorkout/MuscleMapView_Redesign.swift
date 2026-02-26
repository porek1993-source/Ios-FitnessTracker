// MuscleMapView_Redesign.swift
// Agilní Fitness Trenér — Prémiová svalová mapa
//
// ✅ Organické Capsule / zaoblené tvary místo ostrých obdélníků
// ✅ Jemné mezery mezi svalovými partiemi
// ✅ Moderní silueta s gradientem a glow efektem
// ✅ Plná zpětná kompatibilita s HeatmapViewModel a MuscleArea

import SwiftUI

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: OrganicBodyFigureView  (drop-in náhrada za BodyFigureView)
// MARK: ═══════════════════════════════════════════════════════════════════════

struct OrganicBodyFigureView: View {
    @ObservedObject var vm: HeatmapViewModel
    let onTap: (MuscleArea) -> Void
    @State private var showingFront = true

    var body: some View {
        VStack(spacing: 16) {
            // Přepínač přední/zadní pohled
            Picker("Pohled", selection: $showingFront) {
                Text("Přední").tag(true)
                Text("Zadní").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 60)

            GeometryReader { geo in
                let areas = showingFront ? MuscleArea.frontAreas : MuscleArea.backAreas

                ZStack {
                    // ── Organická silueta na pozadí ──────────────────────────
                    OrganicBodySilhouette(isFront: showingFront)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.07),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            OrganicBodySilhouette(isFront: showingFront)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                    // ── Organické svalové zóny ────────────────────────────────
                    ForEach(areas) { area in
                        let state = vm.state(for: area)
                        OrganicMuscleZone(
                            area:     area,
                            state:    state,
                            progress: vm.muscleProgress(for: area),
                            canvas:   geo.size
                        )
                        .animation(.easeInOut(duration: 0.28), value: state)
                    }

                    // ── Jednotný tap handler (zachován původní pattern) ───────
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    handleCanvasTap(
                                        at: value.startLocation,
                                        canvasSize: geo.size,
                                        areas: areas
                                    )
                                }
                        )
                }
            }
            .frame(width: 220, height: 420)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Hit-test
    private func handleCanvasTap(at point: CGPoint, canvasSize: CGSize, areas: [MuscleArea]) {
        let sorted = areas.sorted { ($0.relW * $0.relH) < ($1.relW * $1.relH) }
        for area in sorted {
            let rect = area.relativeRect(in: canvasSize).insetBy(dx: -6, dy: -6)
            if rect.contains(point) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                vm.lastTappedArea = area
                onTap(area)
                return
            }
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: OrganicMuscleZone  — jednotlivá svalová partie
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct OrganicMuscleZone: View {
    let area:     MuscleArea
    let state:    MuscleState
    let progress: Double
    let canvas:   CGSize

    private var rect: CGRect { area.relativeRect(in: canvas) }

    /// Dynamický cornerRadius: velké partie = více zaoblené, malé (lýtka) = Capsule
    private var cornerRadius: CGFloat {
        let minDim = min(rect.width, rect.height)
        // Pokud je oblast blízká čtverci / spíše vertikální → plná Capsule
        return minDim * 0.50
    }

    var body: some View {
        ZStack {
            // ─ Výplň: zdravá / sore / fatigued / jointPain
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fillGradient)

            // ─ Outline (vždy jemný, u poranění výraznější)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(strokeColor, lineWidth: state == .healthy ? 0.8 : 1.5)

            // ─ Gamifikační glow (modrý overlay při tréninkovém pokroku)
            if progress > 0 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.18 * progress),
                                Color.cyan.opacity(0.10 * progress)
                            ],
                            startPoint: .top,
                            endPoint:   .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.cyan.opacity(0.35 * progress), lineWidth: 1)
                    )
            }
        }
        // Jemné mezery od okolí pomocí padding (inset)
        .frame(
            width:  rect.width  - 4,
            height: rect.height - 4
        )
        .position(x: rect.midX, y: rect.midY)
        .animation(.spring(response: 0.6), value: progress)
    }

    // MARK: Barvy

    private var fillGradient: AnyShapeStyle {
        switch state {
        case .healthy:
            return AnyShapeStyle(Color.white.opacity(0.07))
        case .sore:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.orange.opacity(0.50), Color.orange.opacity(0.28)],
                    startPoint: .top, endPoint: .bottom
                )
            )
        case .fatigued:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.red.opacity(0.55), Color.red.opacity(0.32)],
                    startPoint: .top, endPoint: .bottom
                )
            )
        case .jointPain:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.red.opacity(0.78), Color.red.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }

    private var strokeColor: Color {
        switch state {
        case .healthy:   return .white.opacity(0.12)
        case .sore:      return .orange.opacity(0.65)
        case .fatigued:  return .red.opacity(0.70)
        case .jointPain: return .red
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: OrganicBodySilhouette  — prémiová organická silueta postavy
// ═══════════════════════════════════════════════════════════════════════════════
//
// Silueta je složena z překrývajících se zaoblených tvarů (Capsule-like)
// místo ostrých obdélníků. Výsledek působí jako skutečná lidská postava.

struct OrganicBodySilhouette: Shape {
    let isFront: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        // ── Hlava ────────────────────────────────────────────────────────────
        p.addEllipse(in: CGRect(
            x: w * 0.345, y: h * 0.00,
            width: w * 0.31, height: h * 0.145
        ))

        // ── Krk ──────────────────────────────────────────────────────────────
        p.addRoundedRect(
            in: CGRect(x: w * 0.435, y: h * 0.130, width: w * 0.13, height: h * 0.045),
            cornerSize: CGSize(width: 8, height: 8)
        )

        // ── Trup (zaoblený obdélník — organický tvar) ────────────────────────
        p.addRoundedRect(
            in: CGRect(x: w * 0.215, y: h * 0.165, width: w * 0.575, height: h * 0.335),
            cornerSize: CGSize(width: 20, height: 20)
        )

        // ── Levé rameno (capsule — klíček) ────────────────────────────────────
        addCapsuleSegment(&p, cx: w * 0.155, cy: h * 0.200, halfW: w * 0.09, halfH: h * 0.055)

        // ── Pravé rameno ──────────────────────────────────────────────────────
        addCapsuleSegment(&p, cx: w * 0.845, cy: h * 0.200, halfW: w * 0.09, halfH: h * 0.055)

        // ── Levá paže (horní + předloktí — dvě capsule) ──────────────────────
        addCapsuleSegment(&p, cx: w * 0.085, cy: h * 0.295, halfW: w * 0.075, halfH: h * 0.110)
        addCapsuleSegment(&p, cx: w * 0.072, cy: h * 0.430, halfW: w * 0.065, halfH: h * 0.095)

        // ── Pravá paže ────────────────────────────────────────────────────────
        addCapsuleSegment(&p, cx: w * 0.915, cy: h * 0.295, halfW: w * 0.075, halfH: h * 0.110)
        addCapsuleSegment(&p, cx: w * 0.928, cy: h * 0.430, halfW: w * 0.065, halfH: h * 0.095)

        // ── Boky / pánev ──────────────────────────────────────────────────────
        p.addRoundedRect(
            in: CGRect(x: w * 0.205, y: h * 0.488, width: w * 0.595, height: h * 0.095),
            cornerSize: CGSize(width: 18, height: 18)
        )

        // ── Levé stehno ───────────────────────────────────────────────────────
        addCapsuleSegment(&p, cx: w * 0.330, cy: h * 0.650, halfW: w * 0.115, halfH: h * 0.135)

        // ── Pravé stehno ──────────────────────────────────────────────────────
        addCapsuleSegment(&p, cx: w * 0.670, cy: h * 0.650, halfW: w * 0.115, halfH: h * 0.135)

        // ── Levá holeň ────────────────────────────────────────────────────────
        addCapsuleSegment(&p, cx: w * 0.320, cy: h * 0.828, halfW: w * 0.090, halfH: h * 0.115)

        // ── Pravá holeň ───────────────────────────────────────────────────────
        addCapsuleSegment(&p, cx: w * 0.680, cy: h * 0.828, halfW: w * 0.090, halfH: h * 0.115)

        // ── Levá chodidlo ─────────────────────────────────────────────────────
        p.addRoundedRect(
            in: CGRect(x: w * 0.215, y: h * 0.950, width: w * 0.215, height: h * 0.048),
            cornerSize: CGSize(width: 10, height: 10)
        )

        // ── Pravé chodidlo ────────────────────────────────────────────────────
        p.addRoundedRect(
            in: CGRect(x: w * 0.572, y: h * 0.950, width: w * 0.215, height: h * 0.048),
            cornerSize: CGSize(width: 10, height: 10)
        )

        return p
    }

    /// Přidá Capsule-like elipsu (pro organické ramena, paže, stehna)
    private func addCapsuleSegment(
        _ path: inout Path,
        cx: CGFloat, cy: CGFloat,
        halfW: CGFloat, halfH: CGFloat
    ) {
        let r = min(halfW, halfH)
        path.addRoundedRect(
            in: CGRect(x: cx - halfW, y: cy - halfH, width: halfW * 2, height: halfH * 2),
            cornerSize: CGSize(width: r, height: r)
        )
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Preview  (samostatná ukázka nové mapy)
// ═══════════════════════════════════════════════════════════════════════════════

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OrganicBodyFigureView(vm: HeatmapViewModel()) { _ in }
            .padding(.top, 40)
    }
    .preferredColorScheme(.dark)
}
