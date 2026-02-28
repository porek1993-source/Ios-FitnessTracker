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

// ViewModel přesunut do HeatmapViewModel.swift

// MARK: - Domain Models

// Modely přesunuty do Data/Models/
