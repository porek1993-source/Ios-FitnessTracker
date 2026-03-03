// SprintRetroView.swift
// Sprint Retrospektiva — klíčový diferenciátor agilního fitness koučinku
// ✅ deepanal.pdf bod 8: "AI Sprint Retrospektiva po ukončení 2–4-týdenního bloku"

import SwiftUI
import SwiftData

struct SprintRetroView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var vm = SprintRetroViewModel()
    
    private var profile: UserProfile? { profiles.first }
    private var plan: WorkoutPlan? { profile?.workoutPlans.first(where: \.isActive) }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        sprintHeader
                        statsOverview
                        feedbackSection
                        
                        if vm.isGenerating {
                            generatingView
                        }
                        
                        if let retro = vm.retroSummary {
                            retroSummaryCard(retro)
                        }
                        
                        goalsSection
                        
                        actionButtons
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Sprint Retrospektiva")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zavřít") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .onAppear {
            if let plan {
                vm.loadSprintStats(plan: plan)
            }
        }
    }
    
    // MARK: - Components
    
    private var sprintHeader: some View {
        VStack(spacing: 8) {
            Text("SPRINT #\(plan?.sprintNumber ?? 1)")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.cyan.opacity(0.8))
                .kerning(2)
            
            Text("Retrospektiva")
                .font(.system(.title, design: .rounded)).bold()
                .foregroundStyle(.white)
            
            if let start = plan?.sprintStartDate {
                let weeks = Calendar.current.dateComponents([.weekOfYear], from: start, to: .now).weekOfYear ?? 0
                Text("\(weeks) týdnů tréninku")
                    .font(.system(.callout))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
    
    private var statsOverview: some View {
        HStack(spacing: 12) {
            StatPill(label: "Tréninky", value: "\(vm.completedSessions)", icon: "checkmark.circle.fill", color: .green)
            StatPill(label: "Vynecháno", value: "\(vm.missedSessions)", icon: "xmark.circle.fill", color: .red)
            StatPill(label: "Objem (kg)", value: formatVolume(vm.totalVolume), icon: "scalemass.fill", color: .blue)
        }
    }
    
    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("JAK SE CÍTÍŠ?")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white.opacity(0.3))
                .kerning(1.5)
            
            Text("Co fungovalo?")
                .font(.system(.callout, design: .rounded)).bold()
                .foregroundStyle(.white.opacity(0.8))
            TextField("Např. ranní tréninky, split na 4 dny...", text: $vm.whatWorked)
                .textFieldStyle(.plain)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
                .foregroundStyle(.white)
            
            Text("Co nefungovalo?")
                .font(.system(.callout, design: .rounded)).bold()
                .foregroundStyle(.white.opacity(0.8))
            TextField("Např. únava v pátky, příliš intenzivní...", text: $vm.whatFailed)
                .textFieldStyle(.plain)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
                .foregroundStyle(.white)
            
            Text("Překážky?")
                .font(.system(.callout, design: .rounded)).bold()
                .foregroundStyle(.white.opacity(0.8))
            TextField("Např. málo spánku, práce, zranění...", text: $vm.obstacles)
                .textFieldStyle(.plain)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
                .foregroundStyle(.white)
        }
        .glassCardStyle()
    }
    
    @ViewBuilder
    private var generatingView: some View {
        HStack(spacing: 12) {
            ProgressView().tint(.cyan)
            Text("iKorba analyzuje tvůj sprint...")
                .font(.system(.callout)).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCardStyle()
    }
    
    private func retroSummaryCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.cyan)
                Text("iKorba DOPORUČUJE")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.cyan.opacity(0.8))
                    .kerning(1.5)
            }
            
            Text(summary)
                .font(.system(.body))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCardStyle()
    }
    
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CÍLE PRO DALŠÍ SPRINT")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white.opacity(0.3))
                .kerning(1.5)
            
            ForEach(vm.nextSprintGoals.indices, id: \.self) { i in
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .foregroundStyle(.orange)
                    TextField("Cíl \(i + 1)...", text: $vm.nextSprintGoals[i])
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)))
            }
            
            if vm.nextSprintGoals.count < 3 {
                Button {
                    vm.nextSprintGoals.append("")
                } label: {
                    Label("Přidat cíl", systemImage: "plus.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.cyan.opacity(0.7))
                }
            }
        }
        .glassCardStyle()
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Generovat retrospektivu
            Button {
                Task {
                    if let ai = env.aiTrainerService, let plan {
                        await vm.generateRetrospective(ai: ai, plan: plan)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                    Text("AI Analýza sprintu")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(vm.isGenerating)
            
            // Spustit nový sprint
            Button {
                vm.startNewSprint(plan: plan, modelContext: modelContext)
                HapticPatternEngine.shared.playPersonalRecordCelebration()
                dismiss()
            } label: {
                Text("Spustit Sprint #\((plan?.sprintNumber ?? 1) + 1)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Helpers
    
    private func formatVolume(_ v: Double) -> String {
        if v >= 1000 {
            return String(format: "%.0fk", v / 1000)
        }
        return String(format: "%.0f", v)
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(0.15), lineWidth: 1))
        )
    }
}
