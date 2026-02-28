// HeatmapView.swift

import SwiftUI

struct HeatmapView: View {
    @StateObject private var vm = HeatmapViewModel()
    @EnvironmentObject private var healthKit: HealthKitService
    @State private var showConfirmation = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HeatmapHeaderView(vm: vm)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // ✅ OPRAVENO: MuscleMapView (prémiová organická silueta) nahrazuje BodyFigureView
                        MuscleMapView(vm: vm) { area in
                            vm.lastTappedArea = area
                            showConfirmation   = true
                        }
                        .padding(.top, 8)

                        if !vm.affectedAreas.isEmpty {
                            ActiveRestrictionsView(vm: vm)
                                .padding(.horizontal, 20)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        InstructionsBanner()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }
            }

            if showConfirmation, let area = vm.lastTappedArea {
                FatigueConfirmationSheet(
                    area: area,
                    isPresented: $showConfirmation,
                    onConfirm: { severity, isJoint in
                        vm.confirmFatigue(area: area, severity: severity, isJointPain: isJoint)
                    }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: vm.affectedAreas.count)
        .onAppear { vm.loadReadiness(healthKit: healthKit) }
    }
}

// MARK: - Header

struct HeatmapHeaderView: View {
    @ObservedObject var vm: HeatmapViewModel
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Jak se cítíš?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("Ťukni na oblast, která tě omezuje")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            ReadinessRingView(score: vm.readinessScore)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
}

struct ReadinessRingView: View {
    let score: Double
    private var color: Color { score > 75 ? .green : score > 50 ? .yellow : .red }

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6), value: score)
            VStack(spacing: 0) {
                Text("\(Int(score))").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                Text("připravenost").font(.system(size: 7)).foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: 64, height: 64)
    }
}

// MARK: - Body Figure

struct BodyFigureView: View {
    @ObservedObject var vm: HeatmapViewModel
    let onTap: (MuscleArea) -> Void
    @State private var showingFront = true

    var body: some View {
        VStack(spacing: 16) {
            Picker("Pohled", selection: $showingFront) {
                Text("Přední").tag(true)
                Text("Zadní").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 60)

            GeometryReader { geo in
                let areas = showingFront ? MuscleArea.frontAreas : MuscleArea.backAreas
                ZStack {
                    BodySilhouette(isFront: showingFront)
                        .fill(Color.white.opacity(0.06))
                        .overlay(BodySilhouette(isFront: showingFront)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1))

                    // Barevné overlay (jen vizuál, žádná tap logika)
                    ZStack {
                        ForEach(areas) { area in
                            let state = vm.state(for: area)
                            Capsule()
                                .fill(heatmapFillColor(for: state))
                                .frame(width: area.relativeRect(in: geo.size).width,
                                       height: area.relativeRect(in: geo.size).height)
                                .position(x: area.relativeRect(in: geo.size).midX,
                                          y: area.relativeRect(in: geo.size).midY)
                                .animation(.easeInOut(duration: 0.25), value: state)
                        }
                    }
                    .clipShape(BodySilhouette(isFront: showingFront))

                    // Gamifikace overlay
                    ZStack {
                        ForEach(areas) { area in
                            if vm.muscleProgress(for: area) > 0 {
                                MuscleGrowthOverlay(
                                    area: area,
                                    progress: vm.muscleProgress(for: area),
                                    canvasSize: geo.size
                                )
                            }
                        }
                    }
                    .clipShape(BodySilhouette(isFront: showingFront))

                    // OPRAVA: Jediný tap handler přes celý canvas.
                    // Místo contentShape(Rectangle()) na každé zone (kde vždy vyhrál
                    // poslední ve ForEach = right_calf) ručně detekujeme oblast.
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    handleCanvasTap(at: value.startLocation,
                                                    canvasSize: geo.size,
                                                    areas: areas)
                                }
                        )
                }
            }
            .frame(width: 250, height: 390)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Body Silhouette Shape

struct BodySilhouette: Shape {
    let isFront: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let cx = w * 0.5

        // ── Hlava ──
        p.addEllipse(in: CGRect(x: cx - w*0.11, y: h*0.005, width: w*0.22, height: h*0.10))

        // ── Krk ──
        p.addRoundedRect(
            in: CGRect(x: cx - w*0.045, y: h*0.09, width: w*0.09, height: h*0.035),
            cornerSize: CGSize(width: 6, height: 6), style: .continuous
        )

        // ── Trup (ramena → pas) — Bézier ──
        p.move(to: CGPoint(x: cx - w*0.26, y: h*0.125))
        // Levé rameno zaoblení
        p.addQuadCurve(to: CGPoint(x: cx - w*0.28, y: h*0.18),
                       control: CGPoint(x: cx - w*0.29, y: h*0.125))
        // Levý bok dolů k pasu
        p.addCurve(to: CGPoint(x: cx - w*0.18, y: h*0.44),
                   control1: CGPoint(x: cx - w*0.28, y: h*0.30),
                   control2: CGPoint(x: cx - w*0.22, y: h*0.40))
        // Pánev spodek
        p.addQuadCurve(to: CGPoint(x: cx + w*0.18, y: h*0.44),
                       control: CGPoint(x: cx, y: h*0.46))
        // Pravý bok nahoru
        p.addCurve(to: CGPoint(x: cx + w*0.28, y: h*0.18),
                   control1: CGPoint(x: cx + w*0.22, y: h*0.40),
                   control2: CGPoint(x: cx + w*0.28, y: h*0.30))
        // Pravé rameno zaoblení
        p.addQuadCurve(to: CGPoint(x: cx + w*0.26, y: h*0.125),
                       control: CGPoint(x: cx + w*0.29, y: h*0.125))
        // Uzavření přes hrudník nahoře
        p.addQuadCurve(to: CGPoint(x: cx - w*0.26, y: h*0.125),
                       control: CGPoint(x: cx, y: h*0.115))
        p.closeSubpath()

        // ── Levá paže (horní = biceps/triceps) ──
        let armTopPath = makeArmPath(cx: cx, w: w, h: h, side: -1)
        p.addPath(armTopPath)

        // ── Pravá paže ──
        let armTopPathR = makeArmPath(cx: cx, w: w, h: h, side: 1)
        p.addPath(armTopPathR)

        // ── Levé předloktí ──
        let forearmL = makeForearmPath(cx: cx, w: w, h: h, side: -1)
        p.addPath(forearmL)

        // ── Pravé předloktí ──
        let forearmR = makeForearmPath(cx: cx, w: w, h: h, side: 1)
        p.addPath(forearmR)

        // ── Levá noha (stehno) ──
        let thighL = makeThighPath(cx: cx, w: w, h: h, side: -1)
        p.addPath(thighL)

        // ── Pravá noha (stehno) ──
        let thighR = makeThighPath(cx: cx, w: w, h: h, side: 1)
        p.addPath(thighR)

        // ── Levé lýtko ──
        let calfL = makeCalfPath(cx: cx, w: w, h: h, side: -1)
        p.addPath(calfL)

        // ── Pravé lýtko ──
        let calfR = makeCalfPath(cx: cx, w: w, h: h, side: 1)
        p.addPath(calfR)

        return p
    }

    // MARK: - Limb Helpers

    private func makeArmPath(cx: CGFloat, w: CGFloat, h: CGFloat, side: CGFloat) -> Path {
        var p = Path()
        let ox = cx + side * w * 0.32
        let topY = h * 0.16
        let botY = h * 0.38
        let armW: CGFloat = w * 0.065

        p.addRoundedRect(
            in: CGRect(x: ox - armW, y: topY, width: armW * 2, height: botY - topY),
            cornerSize: CGSize(width: armW * 0.8, height: armW * 0.8), style: .continuous
        )
        return p
    }

    private func makeForearmPath(cx: CGFloat, w: CGFloat, h: CGFloat, side: CGFloat) -> Path {
        var p = Path()
        let ox = cx + side * w * 0.32
        let topY = h * 0.39
        let botY = h * 0.56
        let fW: CGFloat = w * 0.048

        p.addRoundedRect(
            in: CGRect(x: ox - fW, y: topY, width: fW * 2, height: botY - topY),
            cornerSize: CGSize(width: fW * 0.8, height: fW * 0.8), style: .continuous
        )
        return p
    }

    private func makeThighPath(cx: CGFloat, w: CGFloat, h: CGFloat, side: CGFloat) -> Path {
        var p = Path()
        let ox = cx + side * w * 0.115
        let topY = h * 0.445
        let botY = h * 0.72
        let topW: CGFloat = w * 0.10
        let botW: CGFloat = w * 0.065

        // Tapered shape — wider at top, narrower at knee
        p.move(to: CGPoint(x: ox - topW, y: topY))
        p.addLine(to: CGPoint(x: ox + topW, y: topY))
        p.addQuadCurve(to: CGPoint(x: ox + botW, y: botY),
                       control: CGPoint(x: ox + topW * 0.9, y: (topY + botY) * 0.55))
        p.addQuadCurve(to: CGPoint(x: ox - botW, y: botY),
                       control: CGPoint(x: ox, y: botY + h * 0.012))
        p.addQuadCurve(to: CGPoint(x: ox - topW, y: topY),
                       control: CGPoint(x: ox - topW * 0.9, y: (topY + botY) * 0.55))
        p.closeSubpath()
        return p
    }

    private func makeCalfPath(cx: CGFloat, w: CGFloat, h: CGFloat, side: CGFloat) -> Path {
        var p = Path()
        let ox = cx + side * w * 0.115
        let topY = h * 0.73
        let botY = h * 0.93
        let topW: CGFloat = w * 0.058
        let midW: CGFloat = w * 0.065
        let botW: CGFloat = w * 0.042

        // Calf: slim at knee, wider at muscle belly, tapers to ankle
        p.move(to: CGPoint(x: ox - topW, y: topY))
        p.addLine(to: CGPoint(x: ox + topW, y: topY))
        p.addQuadCurve(to: CGPoint(x: ox + midW, y: topY + (botY - topY) * 0.35),
                       control: CGPoint(x: ox + midW * 1.05, y: topY + (botY - topY) * 0.15))
        p.addQuadCurve(to: CGPoint(x: ox + botW, y: botY),
                       control: CGPoint(x: ox + midW * 0.8, y: topY + (botY - topY) * 0.7))
        // Foot hint
        p.addQuadCurve(to: CGPoint(x: ox - botW, y: botY),
                       control: CGPoint(x: ox, y: botY + h * 0.015))
        p.addQuadCurve(to: CGPoint(x: ox - midW, y: topY + (botY - topY) * 0.35),
                       control: CGPoint(x: ox - midW * 0.8, y: topY + (botY - topY) * 0.7))
        p.addQuadCurve(to: CGPoint(x: ox - topW, y: topY),
                       control: CGPoint(x: ox - midW * 1.05, y: topY + (botY - topY) * 0.15))
        p.closeSubpath()
        return p
    }
}

extension BodyFigureView {
    // MARK: - Hit-test logic

    private func handleCanvasTap(at point: CGPoint, canvasSize: CGSize, areas: [MuscleArea]) {
        // Seřaď zóny vzestupně podle plochy — menší oblast = přesnější cíl, vyšší priorita
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

    private func heatmapFillColor(for state: MuscleState) -> Color {
        switch state {
        case .healthy:   return .clear
        case .sore:      return .orange.opacity(0.35)
        case .fatigued:  return .red.opacity(0.45)
        case .jointPain: return .red.opacity(0.70)
        }
    }
}

// MARK: - (Legacy stub kept for compilation; no longer used for tap logic)
struct MuscleZoneTapArea: View {
    let area: MuscleArea
    let state: MuscleState
    let canvasSize: CGSize
    let onTap: () -> Void
    @State private var isPressed = false

    private var rect: CGRect { area.relativeRect(in: canvasSize) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: area.cornerRadius)
                .fill(fillColor).opacity(state == .healthy ? 0 : 1)
                .animation(.easeInOut(duration: 0.25), value: state)
            RoundedRectangle(cornerRadius: area.cornerRadius)
                .strokeBorder(strokeColor, lineWidth: isPressed ? 2 : 0)
            if state == .healthy {
                RoundedRectangle(cornerRadius: area.cornerRadius)
                    .fill(Color.white.opacity(isPressed ? 0.08 : 0))
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.2)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { isPressed = false }
                onTap()
            }
        }
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
    }

    private var fillColor: Color {
        switch state {
        case .healthy:    return .clear
        case .sore:       return .orange.opacity(0.35)
        case .fatigued:   return .red.opacity(0.45)
        case .jointPain:  return .red.opacity(0.70)
        }
    }
    private var strokeColor: Color {
        switch state {
        case .healthy:    return .white.opacity(0.3)
        case .sore:       return .orange.opacity(0.6)
        case .fatigued:   return .red.opacity(0.7)
        case .jointPain:  return .red
        }
    }
}

// MARK: - Muscle Growth Overlay (gamifikace)

struct MuscleGrowthOverlay: View {
    let area: MuscleArea
    let progress: Double
    let canvasSize: CGSize
    private var rect: CGRect { area.relativeRect(in: canvasSize) }

    var body: some View {
        RoundedRectangle(cornerRadius: area.cornerRadius)
            .fill(LinearGradient(
                colors: [Color.blue.opacity(0.15 * progress), Color.cyan.opacity(0.10 * progress)],
                startPoint: .top, endPoint: .bottom
            ))
            .overlay(
                RoundedRectangle(cornerRadius: area.cornerRadius)
                    .strokeBorder(Color.cyan.opacity(0.3 * progress), lineWidth: 1)
            )
            .frame(
                width:  rect.width  * (1 + 0.08 * progress),
                height: rect.height * (1 + 0.06 * progress)
            )
            .position(x: rect.midX, y: rect.midY)
            .animation(.spring(response: 0.6), value: progress)
    }
}

// MARK: - Fatigue Confirmation Sheet

struct FatigueConfirmationSheet: View {
    let area: MuscleArea
    @Binding var isPresented: Bool
    let onConfirm: (Int, Bool) -> Void
    @State private var severity = 3
    @State private var isJointPain = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.5).ignoresSafeArea().onTapGesture { isPresented = false }

            VStack(spacing: 20) {
                Capsule().fill(Color.white.opacity(0.25)).frame(width: 36, height: 4).padding(.top, 12)
                Text(area.displayName).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Intenzita omezení").font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text(severityLabel).font(.system(size: 14, weight: .semibold)).foregroundStyle(severityColor)
                    }
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { i in
                            Button {
                                withAnimation(.spring(response: 0.2)) { severity = i }
                            } label: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(i <= severity ? severityColorFor(i) : Color.white.opacity(0.1))
                                    .frame(height: 36)
                                    .overlay(Text("\(i)").font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(i <= severity ? .black : .white.opacity(0.4)))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 20)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Bolest kloubu nebo šlachy?")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        Text("Ne jen svalová horečka (DOMS)")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    Toggle("", isOn: $isJointPain).tint(.red)
                }
                .padding(.horizontal, 20)

                if isJointPain {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                        Text("iKorba cvik z dnešního tréninku vyjme")
                            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.1)))
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                HStack(spacing: 12) {
                    Button { isPresented = false } label: {
                        Text("Zrušit").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                    }
                    Button {
                        onConfirm(severity, isJointPain)
                        isPresented = false
                    } label: {
                        Text("Potvrdit").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(colors: [.blue, .blue.opacity(0.7)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 36)
            }
            .background(RoundedRectangle(cornerRadius: 28).fill(Color(white: 0.1)).ignoresSafeArea(edges: .bottom))
        }
    }

    private var severityLabel: String {
        switch severity {
        case 1: return "Minimální"; case 2: return "Mírné"; case 3: return "Střední"
        case 4: return "Výrazné";   default: return "Silná bolest"
        }
    }
    private var severityColor: Color { severityColorFor(severity) }
    private func severityColorFor(_ i: Int) -> Color {
        switch i { case 1, 2: return .yellow; case 3: return .orange; default: return .red }
    }
}

// MARK: - Active Restrictions

struct ActiveRestrictionsView: View {
    @ObservedObject var vm: HeatmapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AKTIVNÍ OMEZENÍ")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.4)).kerning(1.4)
            ForEach(vm.affectedAreas) { entry in
                HStack(spacing: 12) {
                    Circle().fill(entry.isJointPain ? Color.red : Color.orange).frame(width: 8, height: 8)
                    Text(entry.area.displayName).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    Text(entry.isJointPain ? "Kloub/šlacha" : "Únava \(entry.severity)/5")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                    Button { withAnimation { vm.removeFatigue(area: entry.area) } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(entry.isJointPain ? Color.red.opacity(0.12) : Color.orange.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(entry.isJointPain ? Color.red.opacity(0.3) : Color.orange.opacity(0.25), lineWidth: 1))
                )
            }
        }
    }
}

struct InstructionsBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap.fill").font(.system(size: 20)).foregroundStyle(.blue.opacity(0.7))
            Text("Ťukni na část těla, která tě omezuje. iKorba trénink okamžitě přeskládá.")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.45)).multilineTextAlignment(.leading)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }
}

// MARK: - ViewModel

@MainActor
final class HeatmapViewModel: ObservableObject {
    @Published var affectedAreas: [FatigueEntry] = []
    @Published var lastTappedArea: MuscleArea?
    @Published var readinessScore: Double = 0
    @Published var muscleProgressMap: [String: Double] = [:]

    /// Načte readiness z HealthKit — stejný výpočet jako Dashboard
    func loadReadiness(healthKit: HealthKitService) {
        Task {
            guard let summary = try? await healthKit.fetchDailySummary(for: .now) else {
                await MainActor.run { readinessScore = 65 }
                return
            }
            var score = 70.0
            if let sleep = summary.sleepDurationHours {
                if sleep >= 8   { score += 15 }
                else if sleep >= 7 { score += 8 }
                else if sleep >= 6 { score += 0 }
                else if sleep >= 5 { score -= 15 }
                else { score -= 25 }
            }
            if let hrv = summary.hrv {
                if hrv > 60  { score += 10 }
                else if hrv > 40  { score += 3 }
                else { score -= 5 }
            }
            if let rhr = summary.restingHeartRate {
                if rhr < 55  { score += 5 }
                else if rhr < 65  { score += 2 }
                else if rhr > 80  { score -= 10 }
            }
            let final = max(10, min(100, score))
            await MainActor.run {
                withAnimation(.spring(response: 0.8)) {
                    readinessScore = final
                }
            }
        }
    }

    func state(for area: MuscleArea) -> MuscleState {
        guard let entry = affectedAreas.first(where: { $0.area.id == area.id }) else { return .healthy }
        if entry.isJointPain   { return .jointPain }
        if entry.severity >= 4 { return .fatigued }
        return .sore
    }

    func muscleProgress(for area: MuscleArea) -> Double {
        muscleProgressMap[area.slug] ?? 0
    }

    func confirmFatigue(area: MuscleArea, severity: Int, isJointPain: Bool) {
        withAnimation(.spring(response: 0.4)) {
            if let idx = affectedAreas.firstIndex(where: { $0.area.id == area.id }) {
                affectedAreas[idx] = FatigueEntry(area: area, severity: severity, isJointPain: isJointPain)
            } else {
                affectedAreas.append(FatigueEntry(area: area, severity: severity, isJointPain: isJointPain))
            }
        }
        FatigueStore.save(affectedAreas)
    }

    func removeFatigue(area: MuscleArea) {
        affectedAreas.removeAll { $0.area.id == area.id }
        FatigueStore.save(affectedAreas)
    }
}

// MARK: - Domain Models

enum MuscleState { case healthy, sore, fatigued, jointPain }

struct FatigueEntry: Identifiable {
    let id = UUID()
    let area: MuscleArea
    let severity: Int
    let isJointPain: Bool
}

struct MuscleArea: Identifiable {
    let id: String
    let slug: String
    let displayName: String
    let isFrontSide: Bool
    let relX, relY, relW, relH: Double
    var cornerRadius: CGFloat = 8

    func relativeRect(in size: CGSize) -> CGRect {
        CGRect(
            x: relX * size.width  - (relW * size.width  / 2),
            y: relY * size.height - (relH * size.height / 2),
            width:  relW * size.width,
            height: relH * size.height
        )
    }

    static let frontAreas: [MuscleArea] = [
        // Hrudník
        .init(id: "chest",           slug: "chest",           displayName: "Hrudník",            isFrontSide: true,  relX: 0.50, relY: 0.22, relW: 0.36, relH: 0.10),
        // Přední ramena
        .init(id: "l_front_shoulder",slug: "front-shoulders", displayName: "L. přední rameno",   isFrontSide: true,  relX: 0.22, relY: 0.15, relW: 0.12, relH: 0.08, cornerRadius: 16),
        .init(id: "r_front_shoulder",slug: "front-shoulders", displayName: "P. přední rameno",   isFrontSide: true,  relX: 0.78, relY: 0.15, relW: 0.12, relH: 0.08, cornerRadius: 16),
        // Bicepsy
        .init(id: "left_bicep",      slug: "biceps",          displayName: "Levý biceps",         isFrontSide: true,  relX: 0.18, relY: 0.24, relW: 0.09, relH: 0.14, cornerRadius: 10),
        .init(id: "right_bicep",     slug: "biceps",          displayName: "Pravý biceps",        isFrontSide: true,  relX: 0.82, relY: 0.24, relW: 0.09, relH: 0.14, cornerRadius: 10),
        // Předloktí
        .init(id: "left_forearm",    slug: "forearms",        displayName: "Levé předloktí",      isFrontSide: true,  relX: 0.18, relY: 0.415, relW: 0.07, relH: 0.13, cornerRadius: 8),
        .init(id: "right_forearm",   slug: "forearms",        displayName: "Pravé předloktí",     isFrontSide: true,  relX: 0.82, relY: 0.415, relW: 0.07, relH: 0.13, cornerRadius: 8),
        // Šikmé svaly břišní
        .init(id: "left_oblique",    slug: "obliques",        displayName: "Levé šikmé svaly",   isFrontSide: true,  relX: 0.35, relY: 0.36, relW: 0.06, relH: 0.10, cornerRadius: 8),
        .init(id: "right_oblique",   slug: "obliques",        displayName: "Pravé šikmé svaly",  isFrontSide: true,  relX: 0.65, relY: 0.36, relW: 0.06, relH: 0.10, cornerRadius: 8),
        // Břicho
        .init(id: "abs",             slug: "abdominals",      displayName: "Břicho",              isFrontSide: true,  relX: 0.50, relY: 0.35, relW: 0.24, relH: 0.12),
        // Přední stehna
        .init(id: "left_quad",       slug: "quads",           displayName: "Levý kvadriceps",     isFrontSide: true,  relX: 0.36, relY: 0.57, relW: 0.12, relH: 0.20, cornerRadius: 12),
        .init(id: "right_quad",      slug: "quads",           displayName: "Pravý kvadriceps",    isFrontSide: true,  relX: 0.64, relY: 0.57, relW: 0.12, relH: 0.20, cornerRadius: 12),
        // Lýtka (přední)
        .init(id: "left_calf_f",     slug: "calves",          displayName: "Levé lýtko",          isFrontSide: true,  relX: 0.36, relY: 0.79, relW: 0.10, relH: 0.16, cornerRadius: 10),
        .init(id: "right_calf_f",    slug: "calves",          displayName: "Pravé lýtko",         isFrontSide: true,  relX: 0.64, relY: 0.79, relW: 0.10, relH: 0.16, cornerRadius: 10),
    ]

    static let backAreas: [MuscleArea] = [
        // Trapézy (vrchní)
        .init(id: "traps",            slug: "traps",           displayName: "Trapézy",             isFrontSide: false, relX: 0.50, relY: 0.14, relW: 0.30, relH: 0.06),
        // Zadní ramena
        .init(id: "l_rear_shoulder",  slug: "rear-shoulders",  displayName: "L. zadní rameno",    isFrontSide: false, relX: 0.22, relY: 0.15, relW: 0.12, relH: 0.08, cornerRadius: 16),
        .init(id: "r_rear_shoulder",  slug: "rear-shoulders",  displayName: "P. zadní rameno",    isFrontSide: false, relX: 0.78, relY: 0.15, relW: 0.12, relH: 0.08, cornerRadius: 16),
        // Tricepsy
        .init(id: "left_tricep",      slug: "triceps",         displayName: "Levý triceps",        isFrontSide: false, relX: 0.18, relY: 0.24, relW: 0.09, relH: 0.14, cornerRadius: 10),
        .init(id: "right_tricep",     slug: "triceps",         displayName: "Pravý triceps",       isFrontSide: false, relX: 0.82, relY: 0.24, relW: 0.09, relH: 0.14, cornerRadius: 10),
        // Latissimus dorsi (boční záda)
        .init(id: "left_lat",         slug: "lats",            displayName: "Lats (levé záda)",    isFrontSide: false, relX: 0.34, relY: 0.26, relW: 0.12, relH: 0.12, cornerRadius: 8),
        .init(id: "right_lat",        slug: "lats",            displayName: "Lats (pravé záda)",   isFrontSide: false, relX: 0.66, relY: 0.26, relW: 0.12, relH: 0.12, cornerRadius: 8),
        // Střední záda (rhomboid + mid-trap)
        .init(id: "traps_middle",     slug: "traps-middle",    displayName: "Střední záda",        isFrontSide: false, relX: 0.50, relY: 0.26, relW: 0.20, relH: 0.10),
        // Spodní záda
        .init(id: "lower_back",       slug: "lowerback",       displayName: "Spodní záda",         isFrontSide: false, relX: 0.50, relY: 0.36, relW: 0.22, relH: 0.08),
        // Hýždě
        .init(id: "glutes",           slug: "glutes",          displayName: "Hýždě",               isFrontSide: false, relX: 0.50, relY: 0.44, relW: 0.30, relH: 0.08),
        // Zadní stehna
        .init(id: "left_hamstring",   slug: "hamstrings",      displayName: "Levý hamstring",      isFrontSide: false, relX: 0.36, relY: 0.57, relW: 0.12, relH: 0.20, cornerRadius: 12),
        .init(id: "right_hamstring",  slug: "hamstrings",      displayName: "Pravý hamstring",     isFrontSide: false, relX: 0.64, relY: 0.57, relW: 0.12, relH: 0.20, cornerRadius: 12),
        // Lýtka (zadní)
        .init(id: "left_calf_b",      slug: "calves",          displayName: "Levé lýtko",          isFrontSide: false, relX: 0.36, relY: 0.79, relW: 0.10, relH: 0.16, cornerRadius: 10),
        .init(id: "right_calf_b",     slug: "calves",          displayName: "Pravé lýtko",         isFrontSide: false, relX: 0.64, relY: 0.79, relW: 0.10, relH: 0.16, cornerRadius: 10),
    ]
}
