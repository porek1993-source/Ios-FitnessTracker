// MuscleMapView.swift
// Agilní Fitness Trenér — Prémiová svalová mapa (kompletní refaktoring)
//
// ✅ Plně organická silueta (nulové ostré rohy, žádné obdélníkové "panáčky")
// ✅ Prémiový look inspirovaný Apple Fitness+ / Whoop
// ✅ Gradient pozadí siluety + per-sval glow animace
// ✅ Smooth přepínání přední / zadní pohled
// ✅ Drop-in náhrada — zachovává kompatibilitu s HeatmapViewModel a MuscleArea
// ✅ @MainActor safe — veškeré UI updaty na hlavním vlákně
// ✅ Žádné memory leaky — closure callbacks bez retain cycle

import SwiftUI

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: MuscleMapView — veřejné API (použij všude místo BodyFigureView)
// MARK: ═══════════════════════════════════════════════════════════════════════

/// Prémiová svalová mapa jako drop-in náhrada za původní BodyFigureView.
///
/// **Použití:**
/// ```swift
/// MuscleMapView(vm: heatmapViewModel) { tappedArea in
///     print("Klepnuto na: \(tappedArea.displayName)")
/// }
/// ```
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

                    // Prémiová organická silueta na pozadí
                    PremiumBodySilhouette(isFront: showingFront)
                        .fill(silhouetteGradient)
                        .overlay(
                            PremiumBodySilhouette(isFront: showingFront)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.14),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .blue.opacity(0.08), radius: 12, x: 0, y: 4)
                        .opacity(silhouetteAppeared ? 1 : 0)
                        .scaleEffect(silhouetteAppeared ? 1 : 0.96)
                        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: silhouetteAppeared)

                    // Organické svalové zóny
                    let areas = showingFront ? MuscleArea.frontAreas : MuscleArea.backAreas
                    ForEach(areas) { area in
                        OrganicMuscleZoneView(
                            area:     area,
                            state:    vm.state(for: area),
                            progress: vm.muscleProgress(for: area),
                            canvas:   geo.size
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }

                    // Transparentní tap vrstva (přesné hit-testování)
                    TapCatcherView(
                        areas: showingFront ? MuscleArea.frontAreas : MuscleArea.backAreas,
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
                Color.white.opacity(0.065),
                Color.white.opacity(0.028),
                Color.blue.opacity(0.018)
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
                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    private func toggleButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? .white : .white.opacity(0.38))
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isActive {
                            Capsule()
                                .fill(Color.white.opacity(0.13))
                                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.8))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isActive)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: OrganicMuscleZoneView — jednotlivá svalová partie (prémiový look)
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct OrganicMuscleZoneView: View {

    let area:     MuscleArea
    let state:    MuscleState
    let progress: Double
    let canvas:   CGSize

    @State private var glowPulse: Bool = false

    private var rect: CGRect {
        area.relativeRect(in: canvas).insetBy(dx: 2.5, dy: 2.5)
    }

    // Dynamický radius: miniaturní oblasti (lýtka, ruce) = plná Capsule
    private var cornerRadius: CGFloat {
        let minDim = min(rect.width, rect.height)
        return minDim * 0.48
    }

    var body: some View {
        ZStack {

            // Primární výplň (stav svalu)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(primaryFill)

            // Subtilní vnitřní světlo (highlight horní okraj)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // Outline
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(outlineColor, lineWidth: outlineWidth)

            // Gamifikační glow (modrý/tyrkysový — když sval byl trénován)
            if progress > 0.05 {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(0.22 * progress),
                                Color.blue.opacity(0.12 * progress),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: max(rect.width, rect.height) * 0.7
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.cyan.opacity(0.45 * progress * (glowPulse ? 1.0 : 0.65)), lineWidth: 1.2)
                    )
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .animation(.easeInOut(duration: 0.25), value: state)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
        .onAppear {
            if progress > 0.05 {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(Double.random(in: 0...0.8))) {
                    glowPulse = true
                }
            }
        }
        .onChange(of: progress) { _, newVal in
            if newVal > 0.05 && !glowPulse {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }
        }
    }

    // MARK: Barvy podle stavu

    private var primaryFill: AnyShapeStyle {
        switch state {
        case .healthy:
            return AnyShapeStyle(Color.white.opacity(0.072))
        case .sore:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.55, blue: 0.12).opacity(0.55),
                        Color(red: 1.0, green: 0.40, blue: 0.10).opacity(0.30)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        case .fatigued:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.20, blue: 0.22).opacity(0.58),
                        Color(red: 0.85, green: 0.15, blue: 0.18).opacity(0.34)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        case .jointPain:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.10, blue: 0.10).opacity(0.82),
                        Color(red: 0.90, green: 0.08, blue: 0.08).opacity(0.60)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }

    private var outlineColor: Color {
        switch state {
        case .healthy:   return .white.opacity(0.10)
        case .sore:      return Color(red: 1.0, green: 0.55, blue: 0.12).opacity(0.70)
        case .fatigued:  return Color(red: 0.95, green: 0.20, blue: 0.22).opacity(0.75)
        case .jointPain: return Color(red: 1.0, green: 0.10, blue: 0.10)
        }
    }

    private var outlineWidth: CGFloat {
        switch state {
        case .healthy:   return 0.8
        case .sore:      return 1.2
        case .fatigued:  return 1.5
        case .jointPain: return 2.0
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: TapCatcherView — transparentní hit-test vrstva (nejpřesnější přístup)
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

    // Seřazení od nejmenší oblasti (přesnější výběr malých skupin)
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
// MARK: PremiumBodySilhouette — organická prémiová silueta bez ostrých rohů
// MARK: ═══════════════════════════════════════════════════════════════════════
//
// Silueta je postavena výhradně z překrývajících se Capsule-like tvarů.
// Výsledek vypadá jako přirozená lidská figura, ne jako součet obdélníků.
//
// Souřadnicový systém: relativní (0…1) × velikost plátna.

struct PremiumBodySilhouette: Shape {

    let isFront: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height

        // ── Hlava (elipsa) ───────────────────────────────────────────────────
        p.addEllipse(in: CGRect(
            x: w * 0.352, y: h * 0.005,
            width:  w * 0.296,
            height: h * 0.132
        ))

        // ── Krk ──────────────────────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.500, cy: h * 0.147,
            halfW: w * 0.068, halfH: h * 0.030)

        // ── Trup (barrel shape) — dva overlapping rounded rects ──────────────
        // Horní část (ramena → pás)
        addRoundedRect(&p,
            x: w * 0.196, y: h * 0.168,
            width: w * 0.608, height: h * 0.200,
            radius: 22)

        // Spodní část (pás → boky) — trochu užší
        addRoundedRect(&p,
            x: w * 0.220, y: h * 0.330,
            width: w * 0.560, height: h * 0.130,
            radius: 18)

        // ── Levé rameno (deltoid) ─────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.138, cy: h * 0.205,
            halfW: w * 0.098, halfH: h * 0.058)

        // ── Pravé rameno ──────────────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.862, cy: h * 0.205,
            halfW: w * 0.098, halfH: h * 0.058)

        // ── Levá paže — horní (humerus) ───────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.075, cy: h * 0.295,
            halfW: w * 0.070, halfH: h * 0.108)

        // ── Pravá paže — horní ────────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.925, cy: h * 0.295,
            halfW: w * 0.070, halfH: h * 0.108)

        // ── Levé předloktí ────────────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.060, cy: h * 0.436,
            halfW: w * 0.058, halfH: h * 0.095)

        // ── Pravé předloktí ───────────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.940, cy: h * 0.436,
            halfW: w * 0.058, halfH: h * 0.095)

        // ── Levá ruka ─────────────────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.055, cy: h * 0.550,
            halfW: w * 0.050, halfH: h * 0.040)

        // ── Pravá ruka ────────────────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.945, cy: h * 0.550,
            halfW: w * 0.050, halfH: h * 0.040)

        // ── Boky / pánev ──────────────────────────────────────────────────────
        addRoundedRect(&p,
            x: w * 0.196, y: h * 0.458,
            width: w * 0.608, height: h * 0.080,
            radius: 20)

        // ── Levé stehno ───────────────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.316, cy: h * 0.633,
            halfW: w * 0.114, halfH: h * 0.128)

        // ── Pravé stehno ──────────────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.684, cy: h * 0.633,
            halfW: w * 0.114, halfH: h * 0.128)

        // ── Levé koleno (subtilní zaoblení) ───────────────────────────────────
        addCapsule(&p,
            cx: w * 0.314, cy: h * 0.775,
            halfW: w * 0.094, halfH: h * 0.040)

        // ── Pravé koleno ──────────────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.686, cy: h * 0.775,
            halfW: w * 0.094, halfH: h * 0.040)

        // ── Levá holeň ────────────────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.310, cy: h * 0.854,
            halfW: w * 0.082, halfH: h * 0.106)

        // ── Pravá holeň ───────────────────────────────────────────────────────
        addCapsule(&p,
            cx: w * 0.690, cy: h * 0.854,
            halfW: w * 0.082, halfH: h * 0.106)

        // ── Levé chodidlo ─────────────────────────────────────────────────────
        addRoundedRect(&p,
            x: w * 0.200, y: h * 0.954,
            width: w * 0.220, height: h * 0.044,
            radius: 11)

        // ── Pravé chodidlo ────────────────────────────────────────────────────
        addRoundedRect(&p,
            x: w * 0.580, y: h * 0.954,
            width: w * 0.220, height: h * 0.044,
            radius: 11)

        return p
    }

    // MARK: Pomocné kreslicí funkce

    private func addCapsule(_ p: inout Path, cx: CGFloat, cy: CGFloat, halfW: CGFloat, halfH: CGFloat) {
        let r = min(halfW, halfH)
        p.addRoundedRect(
            in: CGRect(x: cx - halfW, y: cy - halfH, width: halfW * 2, height: halfH * 2),
            cornerSize: CGSize(width: r, height: r),
            style: .continuous
        )
    }

    private func addRoundedRect(_ p: inout Path, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) {
        p.addRoundedRect(
            in: CGRect(x: x, y: y, width: width, height: height),
            cornerSize: CGSize(width: radius, height: radius),
            style: .continuous
        )
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Preview
// MARK: ═══════════════════════════════════════════════════════════════════════

#Preview("Svalová mapa — prémiová") {
    ZStack {
        Color(hue: 0.62, saturation: 0.22, brightness: 0.07).ignoresSafeArea()

        ScrollView {
            VStack(spacing: 24) {

                Text("Svalová mapa")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 32)

                // Živá ukázka s mock daty
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
