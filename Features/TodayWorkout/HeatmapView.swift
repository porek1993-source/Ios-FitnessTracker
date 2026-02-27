// HeatmapView.swift

import SwiftUI

struct HeatmapView: View {
    @StateObject private var vm = HeatmapViewModel()
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
                Text("kondice").font(.system(size: 8)).foregroundStyle(.white.opacity(0.4))
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
                    ForEach(areas) { area in
                        let state = vm.state(for: area)
                        RoundedRectangle(cornerRadius: area.cornerRadius)
                            .fill(heatmapFillColor(for: state))
                            .frame(width: area.relativeRect(in: geo.size).width,
                                   height: area.relativeRect(in: geo.size).height)
                            .position(x: area.relativeRect(in: geo.size).midX,
                                      y: area.relativeRect(in: geo.size).midY)
                            .animation(.easeInOut(duration: 0.25), value: state)
                    }

                    // Gamifikace overlay
                    ForEach(areas) { area in
                        if vm.muscleProgress(for: area) > 0 {
                            MuscleGrowthOverlay(
                                area: area,
                                progress: vm.muscleProgress(for: area),
                                canvasSize: geo.size
                            )
                        }
                    }

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
            .frame(width: 220, height: 420)
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
        p.addEllipse(in: CGRect(x: w*0.35, y: 0, width: w*0.30, height: w*0.30))
        p.addRect(CGRect(x: w*0.44, y: w*0.28, width: w*0.12, height: h*0.04))
        p.addRoundedRect(in: CGRect(x: w*0.22, y: h*0.17, width: w*0.56, height: h*0.33), cornerSize: .init(width: 12, height: 12))
        p.addRoundedRect(in: CGRect(x: w*0.04, y: h*0.17, width: w*0.16, height: h*0.28), cornerSize: .init(width: 8, height: 8))
        p.addRoundedRect(in: CGRect(x: w*0.80, y: h*0.17, width: w*0.16, height: h*0.28), cornerSize: .init(width: 8, height: 8))
        p.addRoundedRect(in: CGRect(x: w*0.05, y: h*0.47, width: w*0.14, height: h*0.22), cornerSize: .init(width: 7, height: 7))
        p.addRoundedRect(in: CGRect(x: w*0.81, y: h*0.47, width: w*0.14, height: h*0.22), cornerSize: .init(width: 7, height: 7))
        p.addRoundedRect(in: CGRect(x: w*0.20, y: h*0.49, width: w*0.60, height: h*0.10), cornerSize: .init(width: 8, height: 8))
        p.addRoundedRect(in: CGRect(x: w*0.22, y: h*0.58, width: w*0.24, height: h*0.24), cornerSize: .init(width: 10, height: 10))
        p.addRoundedRect(in: CGRect(x: w*0.54, y: h*0.58, width: w*0.24, height: h*0.24), cornerSize: .init(width: 10, height: 10))
        p.addRoundedRect(in: CGRect(x: w*0.24, y: h*0.83, width: w*0.20, height: h*0.17), cornerSize: .init(width: 8, height: 8))
        p.addRoundedRect(in: CGRect(x: w*0.56, y: h*0.83, width: w*0.20, height: h*0.17), cornerSize: .init(width: 8, height: 8))
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
    @Published var readinessScore: Double = 78
    @Published var muscleProgressMap: [String: Double] = [:]

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
        .init(id: "chest",         slug: "pecs",        displayName: "Hrudník",          isFrontSide: true,  relX: 0.50, relY: 0.25, relW: 0.38, relH: 0.10),
        .init(id: "left_shoulder", slug: "left_delt",   displayName: "Levé rameno",      isFrontSide: true,  relX: 0.22, relY: 0.22, relW: 0.14, relH: 0.08, cornerRadius: 20),
        .init(id: "right_shoulder",slug: "right_delt",  displayName: "Pravé rameno",     isFrontSide: true,  relX: 0.78, relY: 0.22, relW: 0.14, relH: 0.08, cornerRadius: 20),
        .init(id: "left_bicep",    slug: "left_bicep",  displayName: "Levý biceps",      isFrontSide: true,  relX: 0.11, relY: 0.31, relW: 0.12, relH: 0.11, cornerRadius: 10),
        .init(id: "right_bicep",   slug: "right_bicep", displayName: "Pravý biceps",     isFrontSide: true,  relX: 0.89, relY: 0.31, relW: 0.12, relH: 0.11, cornerRadius: 10),
        .init(id: "abs",           slug: "abs",         displayName: "Břicho",           isFrontSide: true,  relX: 0.50, relY: 0.38, relW: 0.24, relH: 0.12),
        .init(id: "left_quad",     slug: "left_quad",   displayName: "Levý kvadriceps",  isFrontSide: true,  relX: 0.34, relY: 0.68, relW: 0.20, relH: 0.16, cornerRadius: 10),
        .init(id: "right_quad",    slug: "right_quad",  displayName: "Pravý kvadriceps", isFrontSide: true,  relX: 0.66, relY: 0.68, relW: 0.20, relH: 0.16, cornerRadius: 10),
        .init(id: "left_calf_f",   slug: "left_calf",   displayName: "Levé lýtko",       isFrontSide: true,  relX: 0.34, relY: 0.91, relW: 0.16, relH: 0.10, cornerRadius: 8),
        .init(id: "right_calf_f",  slug: "right_calf",  displayName: "Pravé lýtko",      isFrontSide: true,  relX: 0.66, relY: 0.91, relW: 0.16, relH: 0.10, cornerRadius: 8),
    ]

    static let backAreas: [MuscleArea] = [
        .init(id: "traps",            slug: "traps",           displayName: "Trapézy",           isFrontSide: false, relX: 0.50, relY: 0.21, relW: 0.36, relH: 0.07),
        .init(id: "upper_back",       slug: "lats_upper",      displayName: "Záda (Lats)",        isFrontSide: false, relX: 0.50, relY: 0.28, relW: 0.44, relH: 0.10),
        .init(id: "lower_back",       slug: "lower_back",      displayName: "Spodní záda",        isFrontSide: false, relX: 0.50, relY: 0.42, relW: 0.30, relH: 0.08),
        .init(id: "left_tricep",      slug: "left_tricep",     displayName: "Levý triceps",       isFrontSide: false, relX: 0.11, relY: 0.31, relW: 0.12, relH: 0.11, cornerRadius: 10),
        .init(id: "right_tricep",     slug: "right_tricep",    displayName: "Pravý triceps",      isFrontSide: false, relX: 0.89, relY: 0.31, relW: 0.12, relH: 0.11, cornerRadius: 10),
        .init(id: "glutes",           slug: "glutes",          displayName: "Hýždě (Glutes)",     isFrontSide: false, relX: 0.50, relY: 0.53, relW: 0.40, relH: 0.09),
        .init(id: "left_hamstring",   slug: "left_hamstring",  displayName: "Levý hamstring",     isFrontSide: false, relX: 0.34, relY: 0.68, relW: 0.20, relH: 0.15, cornerRadius: 10),
        .init(id: "right_hamstring",  slug: "right_hamstring", displayName: "Pravý hamstring",    isFrontSide: false, relX: 0.66, relY: 0.68, relW: 0.20, relH: 0.15, cornerRadius: 10),
        .init(id: "left_calf_b",      slug: "left_calf",       displayName: "Levé lýtko",         isFrontSide: false, relX: 0.34, relY: 0.91, relW: 0.16, relH: 0.10, cornerRadius: 8),
        .init(id: "right_calf_b",     slug: "right_calf",      displayName: "Pravé lýtko",        isFrontSide: false, relX: 0.66, relY: 0.91, relW: 0.16, relH: 0.10, cornerRadius: 8),
    ]
}
