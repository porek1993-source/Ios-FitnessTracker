// DetailedBodyFigureView.swift
// ✅ REWRITE v3: Figurína kreslena přes MuscleArea souřadnice — jeden zdroj pravdy, vždy vycentrovaná.

import SwiftUI

// MARK: - BodySilhouette (tělní kontura jako pozadí)

private struct BodySilhouette: View {
    let size: CGSize
    private let fill = Color(white: 0.16)
    private let stroke = Color.white.opacity(0.12)

    var body: some View {
        let w = size.width
        let h = size.height
        Canvas { ctx, _ in
            // Hlava
            let head = Path(ellipseIn: CGRect(x: w*0.38, y: h*0.01, width: w*0.24, height: h*0.075))
            ctx.fill(head, with: .color(fill))
            ctx.stroke(head, with: .color(stroke), lineWidth: 1)
            // Krk
            let neck = Path { p in
                p.move(to:    CGPoint(x: w*0.44, y: h*0.082))
                p.addLine(to: CGPoint(x: w*0.56, y: h*0.082))
                p.addLine(to: CGPoint(x: w*0.57, y: h*0.12))
                p.addLine(to: CGPoint(x: w*0.43, y: h*0.12))
                p.closeSubpath()
            }
            ctx.fill(neck, with: .color(fill))
            // Trup
            let torso = Path(roundedRect: CGRect(x: w*0.30, y: h*0.12, width: w*0.40, height: h*0.33), cornerRadius: 8)
            ctx.fill(torso, with: .color(fill))
            ctx.stroke(torso, with: .color(stroke), lineWidth: 1)
            // Pas
            let waist = Path(roundedRect: CGRect(x: w*0.33, y: h*0.44, width: w*0.34, height: h*0.05), cornerRadius: 4)
            ctx.fill(waist, with: .color(fill))
            // Boky
            let hips = Path(roundedRect: CGRect(x: w*0.27, y: h*0.47, width: w*0.46, height: h*0.08), cornerRadius: 6)
            ctx.fill(hips, with: .color(fill))
            ctx.stroke(hips, with: .color(stroke), lineWidth: 1)
            // Stehna L/P
            let lThigh = Path(roundedRect: CGRect(x: w*0.28, y: h*0.54, width: w*0.18, height: h*0.22), cornerRadius: 10)
            let rThigh = Path(roundedRect: CGRect(x: w*0.54, y: h*0.54, width: w*0.18, height: h*0.22), cornerRadius: 10)
            ctx.fill(lThigh, with: .color(fill)); ctx.stroke(lThigh, with: .color(stroke), lineWidth: 1)
            ctx.fill(rThigh, with: .color(fill)); ctx.stroke(rThigh, with: .color(stroke), lineWidth: 1)
            // Holeně L/P
            let lShin = Path(roundedRect: CGRect(x: w*0.30, y: h*0.77, width: w*0.14, height: h*0.19), cornerRadius: 8)
            let rShin = Path(roundedRect: CGRect(x: w*0.56, y: h*0.77, width: w*0.14, height: h*0.19), cornerRadius: 8)
            ctx.fill(lShin, with: .color(fill)); ctx.stroke(lShin, with: .color(stroke), lineWidth: 1)
            ctx.fill(rShin, with: .color(fill)); ctx.stroke(rShin, with: .color(stroke), lineWidth: 1)
            // Paže L/P (horní)
            let lArm = Path(roundedRect: CGRect(x: w*0.14, y: h*0.13, width: w*0.13, height: h*0.28), cornerRadius: 8)
            let rArm = Path(roundedRect: CGRect(x: w*0.73, y: h*0.13, width: w*0.13, height: h*0.28), cornerRadius: 8)
            ctx.fill(lArm, with: .color(fill)); ctx.stroke(lArm, with: .color(stroke), lineWidth: 1)
            ctx.fill(rArm, with: .color(fill)); ctx.stroke(rArm, with: .color(stroke), lineWidth: 1)
            // Předloktí L/P
            let lFA = Path(roundedRect: CGRect(x: w*0.15, y: h*0.41, width: w*0.10, height: h*0.18), cornerRadius: 6)
            let rFA = Path(roundedRect: CGRect(x: w*0.75, y: h*0.41, width: w*0.10, height: h*0.18), cornerRadius: 6)
            ctx.fill(lFA, with: .color(fill)); ctx.stroke(lFA, with: .color(stroke), lineWidth: 1)
            ctx.fill(rFA, with: .color(fill)); ctx.stroke(rFA, with: .color(stroke), lineWidth: 1)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - DetailedBodyFigureView

struct DetailedBodyFigureView: View {
    let muscleStates: [MuscleGroup: Double]
    let isFront: Bool
    var highlightColor: Color = AppColors.primaryAccent
    var onTapMuscle: ((MuscleGroup) -> Void)? = nil

    private var areas: [MuscleArea] { isFront ? MuscleArea.frontAreas : MuscleArea.backAreas }
    private let baseColor = Color(white: 0.28)
    private let strokeColor = Color.white.opacity(0.32)

    // Map MuscleArea slug → MuscleGroup
    private let slugToGroup: [String: MuscleGroup] = {
        var d: [String: MuscleGroup] = [:]
        for g in MuscleGroup.allCases { d[g.rawValue] = g }
        return d
    }()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // 1. Kontura těla jako pozadí
                BodySilhouette(size: size)

                // 2. Zvýrazněné svalové oblasti přes MuscleArea souřadnice
                ForEach(areas) { area in
                    let rect = area.relativeRect(in: size)
                    let group = slugToGroup[area.slug]
                    let intensity = group.flatMap { muscleStates[$0] } ?? 0

                    RoundedRectangle(cornerRadius: area.cornerRadius)
                        .fill(intensity > 0
                              ? highlightColor.opacity(0.30 + intensity * 0.60)
                              : baseColor.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: area.cornerRadius)
                                .stroke(intensity > 0
                                        ? highlightColor.opacity(0.5 + intensity * 0.4)
                                        : strokeColor,
                                        lineWidth: intensity > 0 ? 1.5 : 0.8)
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .onTapGesture {
                            guard let g = group else { return }
                            HapticManager.shared.playSelection()
                            onTapMuscle?(g)
                        }
                        // Pulzující animace pro aktivní svaly
                        .scaleEffect(intensity > 0.7 ? 1.03 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double.random(in: 0...0.5)), value: intensity)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 20) {
            DetailedBodyFigureView(
                muscleStates: [.chest: 0.9, .biceps: 0.6, .abdominals: 0.4, .quads: 0.8],
                isFront: true,
                highlightColor: .blue
            )
            .frame(width: 160, height: 380)

            DetailedBodyFigureView(
                muscleStates: [.lats: 0.8, .hamstrings: 0.5, .glutes: 0.9, .lowerback: 0.3],
                isFront: false,
                highlightColor: .orange
            )
            .frame(width: 160, height: 380)
        }
    }
}
