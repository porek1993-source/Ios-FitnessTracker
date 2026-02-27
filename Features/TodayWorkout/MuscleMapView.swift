// MuscleMapView.swift
// Agilní Fitness Trenér — Prémiová svalová mapa (kompletní refaktoring v2)
//
// ✅ Anatomická silueta kreslená Bézierovými křivkami (žádné obdélníky)
// ✅ Svaly mají organické tvary (ellipsy, klopené Capsule, zakřivené Path)
// ✅ Prémiový "halo" neonový glow efekt při tapnutí nebo únavě
// ✅ Gamifikační glow (modrý/cyan) pro trénované svaly
// ✅ Drop-in náhrada — zachovává MuscleArea model z HeatmapView

import SwiftUI

/// Prémiová svalová mapa jako drop-in náhrada za původní BodyFigureView.
struct MuscleMapView: View {

    @ObservedObject var vm: HeatmapViewModel
    let onTap: (MuscleArea) -> Void

    @State private var showingFront: Bool = true
    @State private var silhouetteAppeared: Bool = false

    var body: some View {
        VStack(spacing: 20) {

            // ── Přepínač přední / zadní pohled ──────────────────────────────
            ViewTogglePill(showingFront: $showingFront)

            // ── Svalová mapa ─────────────────────────────────────────────────
            GeometryReader { geo in
                ZStack {

                    // Anatomická silueta na pozadí
                    AnatomicalSilhouette(isFront: showingFront)
                        .fill(silhouetteGradient)
                        .overlay(
                            AnatomicalSilhouette(isFront: showingFront)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                        .scaleEffect(silhouetteAppeared ? 1 : 0.92)
                        .opacity(silhouetteAppeared ? 1 : 0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: silhouetteAppeared)

                    // Organické svalové zóny
                    let areas = showingFront ? MuscleArea.frontAreas : MuscleArea.backAreas
                    ForEach(areas) { area in
                        AnatomicMuscleZone(
                            area:     area,
                            state:    vm.state(for: area),
                            progress: vm.muscleProgress(for: area),
                            canvas:   geo.size
                        )
                    }

                    // TapCatcher — přesný hit-test přes celý canvas
                    TapCatcherView(
                        areas: areas,
                        canvasSize: geo.size,
                        onTap: { area in
                            HapticManager.shared.playSelection()
                            vm.lastTappedArea = area
                            onTap(area)
                        }
                    )
                }
            }
            .frame(width: 220, height: 430)
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.38, dampingFraction: 0.80), value: showingFront)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                silhouetteAppeared = true
            }
        }
    }

    // MARK: Silueta gradient

    private var silhouetteGradient: some ShapeStyle {
        LinearGradient(
            colors: [
                Color.white.opacity(0.07),
                Color.white.opacity(0.03),
                AppColors.primaryAccent.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ViewTogglePill — přepínač Přední / Zadní
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct ViewTogglePill: View {
    @Binding var showingFront: Bool

    var body: some View {
        HStack(spacing: 0) {
            toggleButton(title: "Přední", isActive: showingFront)  { showingFront = true }
            toggleButton(title: "Zadní",  isActive: !showingFront) { showingFront = false }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private func toggleButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                action()
            }
        }) {
            Text(title)
                .font(.system(size: 13, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? .white : .white.opacity(0.35))
                .padding(.horizontal, 22)
                .padding(.vertical, 9)
                .background(
                    Group {
                        if isActive {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isActive)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: AnatomicMuscleZone — ORGANICKÝ tvar svalu s HALO efektem
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct AnatomicMuscleZone: View {

    let area:     MuscleArea
    let state:    MuscleState
    let progress: Double
    let canvas:   CGSize

    @State private var glowPulse: Bool = false

    private var rect: CGRect {
        area.relativeRect(in: canvas).insetBy(dx: 1, dy: 1)
    }

    // Anatomický tvar: Elipsa nebo organicky zkosená Capsule
    private var musclePath: Path {
        AnatomicMuscleShape.path(for: area, in: rect)
    }

    var body: some View {
        ZStack {
            // ─── Layer 1: Hlavní výplň svalu ───────────────────────
            musclePath
                .fill(primaryFill)

            // ─── Layer 2: Subtilní vnitřní světlo (horní okraj) ─────
            musclePath
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // ─── Layer 3: Obrys svalu ───────────────────────────────
            musclePath
                .stroke(outlineColor, lineWidth: outlineWidth)

            // ─── Layer 4: HALO efekt (neonový glow) ─────────────────
            // Aktivní při: tap (sore/fatigued/jointPain) NEBO gamifikace (progress > 0)
            if state != .healthy || progress > 0.05 {
                // Vnější halo — velký, rozmazaný
                musclePath
                    .fill(haloColor.opacity(0.35 * (glowPulse ? 1.0 : 0.6)))
                    .blur(radius: 12)
                    .scaleEffect(1.15)

                // Střední halo — jemnější vrstva
                musclePath
                    .fill(haloColor.opacity(0.25 * (glowPulse ? 0.9 : 0.5)))
                    .blur(radius: 6)
                    .scaleEffect(1.08)

                // Vnitřní neonový okraj
                musclePath
                    .stroke(
                        haloColor.opacity(0.75 * (glowPulse ? 1.0 : 0.55)),
                        lineWidth: state == .jointPain ? 2.5 : 1.8
                    )
                    .blur(radius: 2)
            }

            // ─── Layer 5: Gamifikace overlay (trénované svaly = modro-cyan glow) ──
            if progress > 0.05 && state == .healthy {
                musclePath
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(0.25 * progress),
                                Color.blue.opacity(0.15 * progress),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: max(rect.width, rect.height) * 0.7
                        )
                    )

                musclePath
                    .stroke(
                        Color.cyan.opacity(0.5 * progress * (glowPulse ? 1.0 : 0.6)),
                        lineWidth: 1.2
                    )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
        .onAppear {
            if state != .healthy || progress > 0.05 {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(Double.random(in: 0...0.8))) {
                    glowPulse = true
                }
            }
        }
        .onChange(of: state) { _, newState in
            if newState != .healthy && !glowPulse {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }
        }
        .onChange(of: progress) { _, newVal in
            if newVal > 0.05 && !glowPulse {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }
        }
    }

    // MARK: Barvy podle stavu

    private var primaryFill: AnyShapeStyle {
        switch state {
        case .healthy:
            return AnyShapeStyle(Color.white.opacity(0.06))
        case .sore:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.55, blue: 0.12).opacity(0.50),
                        Color(red: 1.0, green: 0.40, blue: 0.10).opacity(0.28)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        case .fatigued:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.20, blue: 0.22).opacity(0.55),
                        Color(red: 0.85, green: 0.15, blue: 0.18).opacity(0.32)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        case .jointPain:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.10, blue: 0.10).opacity(0.78),
                        Color(red: 0.90, green: 0.08, blue: 0.08).opacity(0.55)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }

    private var outlineColor: Color {
        switch state {
        case .healthy:   return .white.opacity(0.08)
        case .sore:      return AppColors.warning.opacity(0.60)
        case .fatigued:  return AppColors.error.opacity(0.65)
        case .jointPain: return AppColors.error
        }
    }

    private var outlineWidth: CGFloat {
        switch state {
        case .healthy:   return 0.6
        case .sore:      return 1.0
        case .fatigued:  return 1.3
        case .jointPain: return 1.8
        }
    }

    /// Barva halo závisí na stavu: oranžová pro sore, červená pro fatigued/jointPain,
    /// cyan pro gamifikaci (trénovaný sval)
    private var haloColor: Color {
        switch state {
        case .healthy:   return .cyan      // gamifikační glow
        case .sore:      return .orange
        case .fatigued:  return .red
        case .jointPain: return Color(red: 1.0, green: 0.15, blue: 0.15)
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: AnatomicMuscleShape — generátor organických Path tvarů pro každý sval
// MARK: ═══════════════════════════════════════════════════════════════════════

private enum AnatomicMuscleShape {
    /// Vrátí organický Path pro danou svalovou zónu (elipsa, zakřivená capsule, atd.)
    static func path(for area: MuscleArea, in rect: CGRect) -> Path {
        let slug = area.slug

        // Jednotlivé svaly podle slug → speciální anatomické tvary
        switch slug {
        // ── Hrudník (pecs): široká, mírně konvexní elipsa ──
        case "pecs":
            return pectoralPath(rect)

        // ── Ramena (deltoidy): oválné kupole ──
        case "left_delt", "right_delt":
            return deltoidPath(rect, isLeft: slug.hasPrefix("left"))

        // ── Bicepsy: vertikální elipsa s mírným zaoblením ──
        case "left_bicep", "right_bicep":
            return armMusclePath(rect)

        // ── Tricepsy: podobné jako biceps ale subtilněji tvarované ──
        case "left_tricep", "right_tricep":
            return armMusclePath(rect)

        // ── Břicho (abs): obrys přizpůsobený „sixpacku" ──
        case "abs":
            return absPath(rect)

        // ── Kvadricepsy: kapkovitý tvar ──
        case "left_quad", "right_quad":
            return quadPath(rect, isLeft: slug.hasPrefix("left"))

        // ── Hamstringy: vertikální elipsa ──
        case "left_hamstring", "right_hamstring":
            return hamstringPath(rect)

        // ── Lýtka: kapkovitá elipsa (širší nahoře) ──
        case "left_calf", "right_calf":
            return calfPath(rect)

        // ── Trapézy: šíjový lichoběžník ──
        case "traps":
            return trapeziusPath(rect)

        // ── Záda (lats): široký V-tvar ──
        case "lats_upper":
            return latPath(rect)

        // ── Spodní záda: mírně zaoblený obdélník ──
        case "lower_back":
            return lowerBackPath(rect)

        // ── Hýždě (glutes): široká, plochá elipsa ──
        case "glutes":
            return glutePath(rect)

        // Fallback: organická elipsa
        default:
            return Path(ellipseIn: rect)
        }
    }

    // MARK: - Anatomické tvary

    private static func pectoralPath(_ r: CGRect) -> Path {
        // Široká konvexní elipsa s mírným zploštěním dole
        var p = Path()
        let cx = r.midX, cy = r.midY
        let hw = r.width * 0.52, hh = r.height * 0.48
        p.addEllipse(in: CGRect(x: cx - hw, y: cy - hh, width: hw * 2, height: hh * 2))
        return p
    }

    private static func deltoidPath(_ r: CGRect, isLeft: Bool) -> Path {
        // Kupolovitý tvar ramene
        var p = Path()
        let cx = r.midX, cy = r.midY
        p.move(to: CGPoint(x: cx - r.width * 0.42, y: cy + r.height * 0.35))
        p.addCurve(
            to: CGPoint(x: cx + r.width * 0.42, y: cy + r.height * 0.35),
            control1: CGPoint(x: cx - r.width * 0.50, y: cy - r.height * 0.55),
            control2: CGPoint(x: cx + r.width * 0.50, y: cy - r.height * 0.55)
        )
        p.addCurve(
            to: CGPoint(x: cx - r.width * 0.42, y: cy + r.height * 0.35),
            control1: CGPoint(x: cx + r.width * 0.25, y: cy + r.height * 0.50),
            control2: CGPoint(x: cx - r.width * 0.25, y: cy + r.height * 0.50)
        )
        p.closeSubpath()
        return p
    }

    private static func armMusclePath(_ r: CGRect) -> Path {
        // Vřetenovitý tvar (širší uprostřed, užší na koncích)
        var p = Path()
        let cx = r.midX, cy = r.midY
        let hw = r.width * 0.44, hh = r.height * 0.50
        p.move(to: CGPoint(x: cx, y: cy - hh))
        p.addCurve(
            to: CGPoint(x: cx, y: cy + hh),
            control1: CGPoint(x: cx + hw * 1.4, y: cy - hh * 0.3),
            control2: CGPoint(x: cx + hw * 1.4, y: cy + hh * 0.3)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: cy - hh),
            control1: CGPoint(x: cx - hw * 1.4, y: cy + hh * 0.3),
            control2: CGPoint(x: cx - hw * 1.4, y: cy - hh * 0.3)
        )
        p.closeSubpath()
        return p
    }

    private static func absPath(_ r: CGRect) -> Path {
        // Skupina zaoblených segmentů (připomíná sixpack)
        var p = Path()
        let segW = r.width * 0.40
        let segH = r.height * 0.28
        let gap:  CGFloat = 3
        let cx = r.midX

        for row in 0..<3 {
            let y = r.minY + CGFloat(row) * (segH + gap)
            // Levý segment
            p.addRoundedRect(
                in: CGRect(x: cx - segW - gap/2, y: y, width: segW, height: segH),
                cornerSize: CGSize(width: 5, height: 5),
                style: .continuous
            )
            // Pravý segment
            p.addRoundedRect(
                in: CGRect(x: cx + gap/2, y: y, width: segW, height: segH),
                cornerSize: CGSize(width: 5, height: 5),
                style: .continuous
            )
        }
        return p
    }

    private static func quadPath(_ r: CGRect, isLeft: Bool) -> Path {
        // Kapkovitý tvar: širší nahoře, užší u kolena
        var p = Path()
        let cx = r.midX, cy = r.midY
        p.move(to: CGPoint(x: cx, y: r.minY))
        p.addCurve(
            to: CGPoint(x: cx + r.width * 0.35, y: r.maxY),
            control1: CGPoint(x: cx + r.width * 0.55, y: cy - r.height * 0.15),
            control2: CGPoint(x: cx + r.width * 0.48, y: cy + r.height * 0.2)
        )
        p.addCurve(
            to: CGPoint(x: cx - r.width * 0.35, y: r.maxY),
            control1: CGPoint(x: cx + r.width * 0.10, y: r.maxY + 4),
            control2: CGPoint(x: cx - r.width * 0.10, y: r.maxY + 4)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: r.minY),
            control1: CGPoint(x: cx - r.width * 0.48, y: cy + r.height * 0.2),
            control2: CGPoint(x: cx - r.width * 0.55, y: cy - r.height * 0.15)
        )
        p.closeSubpath()
        return p
    }

    private static func hamstringPath(_ r: CGRect) -> Path {
        // Vertikální vřeteno
        return armMusclePath(r) // Stejný tvar, jiný kontext
    }

    private static func calfPath(_ r: CGRect) -> Path {
        // Kapkovitý tvar — širší nahoře
        var p = Path()
        let cx = r.midX
        p.move(to: CGPoint(x: cx, y: r.minY))
        p.addCurve(
            to: CGPoint(x: cx + r.width * 0.25, y: r.maxY),
            control1: CGPoint(x: cx + r.width * 0.55, y: r.minY + r.height * 0.2),
            control2: CGPoint(x: cx + r.width * 0.40, y: r.midY)
        )
        p.addCurve(
            to: CGPoint(x: cx - r.width * 0.25, y: r.maxY),
            control1: CGPoint(x: cx + r.width * 0.08, y: r.maxY + 2),
            control2: CGPoint(x: cx - r.width * 0.08, y: r.maxY + 2)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: r.minY),
            control1: CGPoint(x: cx - r.width * 0.40, y: r.midY),
            control2: CGPoint(x: cx - r.width * 0.55, y: r.minY + r.height * 0.2)
        )
        p.closeSubpath()
        return p
    }

    private static func trapeziusPath(_ r: CGRect) -> Path {
        // Lichoběžníkový tvar: široký nahoře, zúžený dole
        var p = Path()
        let insetX = r.width * 0.10
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addCurve(
            to: CGPoint(x: r.maxX, y: r.minY),
            control1: CGPoint(x: r.midX - r.width * 0.15, y: r.minY - r.height * 0.25),
            control2: CGPoint(x: r.midX + r.width * 0.15, y: r.minY - r.height * 0.25)
        )
        p.addLine(to: CGPoint(x: r.maxX - insetX, y: r.maxY))
        p.addCurve(
            to: CGPoint(x: r.minX + insetX, y: r.maxY),
            control1: CGPoint(x: r.midX + r.width * 0.1, y: r.maxY + r.height * 0.1),
            control2: CGPoint(x: r.midX - r.width * 0.1, y: r.maxY + r.height * 0.1)
        )
        p.closeSubpath()
        return p
    }

    private static func latPath(_ r: CGRect) -> Path {
        // Široký V-tvar (latissimus dorsi)
        var p = Path()
        let cx = r.midX
        p.move(to: CGPoint(x: cx, y: r.minY))
        p.addCurve(
            to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.35),
            control1: CGPoint(x: cx + r.width * 0.15, y: r.minY),
            control2: CGPoint(x: r.maxX, y: r.minY + r.height * 0.1)
        )
        p.addCurve(
            to: CGPoint(x: cx + r.width * 0.15, y: r.maxY),
            control1: CGPoint(x: r.maxX, y: r.midY),
            control2: CGPoint(x: cx + r.width * 0.35, y: r.maxY)
        )
        p.addCurve(
            to: CGPoint(x: cx - r.width * 0.15, y: r.maxY),
            control1: CGPoint(x: cx + r.width * 0.05, y: r.maxY + 3),
            control2: CGPoint(x: cx - r.width * 0.05, y: r.maxY + 3)
        )
        p.addCurve(
            to: CGPoint(x: r.minX, y: r.minY + r.height * 0.35),
            control1: CGPoint(x: cx - r.width * 0.35, y: r.maxY),
            control2: CGPoint(x: r.minX, y: r.midY)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: r.minY),
            control1: CGPoint(x: r.minX, y: r.minY + r.height * 0.1),
            control2: CGPoint(x: cx - r.width * 0.15, y: r.minY)
        )
        p.closeSubpath()
        return p
    }

    private static func lowerBackPath(_ r: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(
            in: r,
            cornerSize: CGSize(width: r.width * 0.3, height: r.height * 0.4),
            style: .continuous
        )
        return p
    }

    private static func glutePath(_ r: CGRect) -> Path {
        // Dva překrývající se oválovité segmenty = realistické hýždě
        var p = Path()
        let gap = r.width * 0.03
        let hw = (r.width - gap) / 2
        // Levá
        p.addEllipse(in: CGRect(x: r.minX, y: r.minY, width: hw, height: r.height))
        // Pravá
        p.addEllipse(in: CGRect(x: r.minX + hw + gap, y: r.minY, width: hw, height: r.height))
        return p
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: TapCatcherView — transparentní hit-test vrstva
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct TapCatcherView: View {
    let areas: [MuscleArea]
    let canvasSize: CGSize
    let onTap: (MuscleArea) -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        hitTest(at: value.startLocation)
                    }
            )
    }

    private func hitTest(at point: CGPoint) {
        let sorted = areas.sorted {
            let a0 = $0.relativeRect(in: canvasSize)
            let a1 = $1.relativeRect(in: canvasSize)
            return (a0.width * a0.height) < (a1.width * a1.height)
        }
        for area in sorted {
            let rect = area.relativeRect(in: canvasSize).insetBy(dx: -8, dy: -8)
            if rect.contains(point) {
                onTap(area)
                return
            }
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: AnatomicalSilhouette — Bézierová anatomická silueta (přední i zadní)
// MARK: ═══════════════════════════════════════════════════════════════════════

struct AnatomicalSilhouette: Shape {

    let isFront: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let cx = w * 0.5

        // ── Hlava ──────────────────────────────────────────
        p.addEllipse(in: CGRect(
            x: cx - w * 0.148, y: h * 0.005,
            width: w * 0.296, height: h * 0.125
        ))

        // ── Krk ────────────────────────────────────────────
        p.addEllipse(in: CGRect(
            x: cx - w * 0.06, y: h * 0.12,
            width: w * 0.12, height: h * 0.055
        ))

        // ── Torso: hlavní obrys pomocí Bézier ──────────────
        var torso = Path()
        // Horní obrys — ramena
        torso.move(to: CGPoint(x: w * 0.14, y: h * 0.175))
        torso.addCurve(
            to: CGPoint(x: w * 0.86, y: h * 0.175),
            control1: CGPoint(x: w * 0.28, y: h * 0.155),
            control2: CGPoint(x: w * 0.72, y: h * 0.155)
        )
        // Pravá strana — od ramene po bok
        torso.addCurve(
            to: CGPoint(x: w * 0.76, y: h * 0.46),
            control1: CGPoint(x: w * 0.88, y: h * 0.22),
            control2: CGPoint(x: w * 0.82, y: h * 0.38)
        )
        // Spodek — přes boky
        torso.addCurve(
            to: CGPoint(x: w * 0.24, y: h * 0.46),
            control1: CGPoint(x: w * 0.70, y: h * 0.48),
            control2: CGPoint(x: w * 0.30, y: h * 0.48)
        )
        // Levá strana — od boku po rameno
        torso.addCurve(
            to: CGPoint(x: w * 0.14, y: h * 0.175),
            control1: CGPoint(x: w * 0.18, y: h * 0.38),
            control2: CGPoint(x: w * 0.12, y: h * 0.22)
        )
        torso.closeSubpath()
        p.addPath(torso)

        // ── Ramena (oválné kupolky) ────────────────────────
        addCapsule(&p, cx: w * 0.11, cy: h * 0.195,   halfW: w * 0.085, halfH: h * 0.050)
        addCapsule(&p, cx: w * 0.89, cy: h * 0.195,   halfW: w * 0.085, halfH: h * 0.050)

        // ── Paže horní ─────────────────────────────────────
        addCapsule(&p, cx: w * 0.065, cy: h * 0.295,  halfW: w * 0.062, halfH: h * 0.100)
        addCapsule(&p, cx: w * 0.935, cy: h * 0.295,  halfW: w * 0.062, halfH: h * 0.100)

        // ── Předloktí ──────────────────────────────────────
        addCapsule(&p, cx: w * 0.055, cy: h * 0.430,  halfW: w * 0.050, halfH: h * 0.088)
        addCapsule(&p, cx: w * 0.945, cy: h * 0.430,  halfW: w * 0.050, halfH: h * 0.088)

        // ── Ruce ───────────────────────────────────────────
        addCapsule(&p, cx: w * 0.050, cy: h * 0.545,  halfW: w * 0.042, halfH: h * 0.035)
        addCapsule(&p, cx: w * 0.950, cy: h * 0.545,  halfW: w * 0.042, halfH: h * 0.035)

        // ── Pánev / boky ───────────────────────────────────
        var pelvis = Path()
        pelvis.addRoundedRect(
            in: CGRect(x: w * 0.20, y: h * 0.455, width: w * 0.60, height: h * 0.075),
            cornerSize: CGSize(width: 18, height: 18),
            style: .continuous
        )
        p.addPath(pelvis)

        // ── Stehna ─────────────────────────────────────────
        addCapsule(&p, cx: w * 0.32, cy: h * 0.63,    halfW: w * 0.105, halfH: h * 0.120)
        addCapsule(&p, cx: w * 0.68, cy: h * 0.63,    halfW: w * 0.105, halfH: h * 0.120)

        // ── Kolena ─────────────────────────────────────────
        addCapsule(&p, cx: w * 0.32, cy: h * 0.775,   halfW: w * 0.085, halfH: h * 0.035)
        addCapsule(&p, cx: w * 0.68, cy: h * 0.775,   halfW: w * 0.085, halfH: h * 0.035)

        // ── Lýtka ──────────────────────────────────────────
        addCapsule(&p, cx: w * 0.315, cy: h * 0.855,  halfW: w * 0.075, halfH: h * 0.098)
        addCapsule(&p, cx: w * 0.685, cy: h * 0.855,  halfW: w * 0.075, halfH: h * 0.098)

        // ── Chodidla ───────────────────────────────────────
        p.addRoundedRect(
            in: CGRect(x: w * 0.21, y: h * 0.955, width: w * 0.21, height: h * 0.040),
            cornerSize: CGSize(width: 10, height: 10),
            style: .continuous
        )
        p.addRoundedRect(
            in: CGRect(x: w * 0.58, y: h * 0.955, width: w * 0.21, height: h * 0.040),
            cornerSize: CGSize(width: 10, height: 10),
            style: .continuous
        )

        return p
    }

    private func addCapsule(_ p: inout Path, cx: CGFloat, cy: CGFloat, halfW: CGFloat, halfH: CGFloat) {
        let r = min(halfW, halfH)
        p.addRoundedRect(
            in: CGRect(x: cx - halfW, y: cy - halfH, width: halfW * 2, height: halfH * 2),
            cornerSize: CGSize(width: r, height: r),
            style: .continuous
        )
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Preview
// MARK: ═══════════════════════════════════════════════════════════════════════

#Preview("Svalová mapa — prémiová v2") {
    ZStack {
        AppColors.background.ignoresSafeArea()

        ScrollView {
            VStack(spacing: 24) {

                Text("Svalová mapa")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 32)

                let vm: HeatmapViewModel = {
                    let m = HeatmapViewModel()
                    m.muscleProgressMap = [
                        "pecs":       0.85,
                        "left_delt":  0.60,
                        "right_delt": 0.60,
                        "abs":        0.45
                    ]
                    return m
                }()

                MuscleMapView(vm: vm) { area in
                    print("Klepnuto: \(area.displayName)")
                }
                .padding(.horizontal, 16)

            }
            .padding(.bottom, 40)
        }
    }
    .preferredColorScheme(.dark)
}
