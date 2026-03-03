// SprintGoalsCard.swift
// Dashboard karta zobrazující cíle aktuálního sprintu
// ✅ deepanal.pdf bod 9: "User Stories — Definice cílů se Sprint Planning"

import SwiftUI
import SwiftData

struct SprintGoalsCard: View {
    @Query private var goals: [SprintGoal]
    let sprintNumber: Int
    
    private var sprintGoals: [SprintGoal] {
        goals.filter { $0.sprintNumber == sprintNumber }
             .sorted { !$0.isCompleted && $1.isCompleted }
    }
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        if sprintGoals.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.orange)
                        Text("SPRINT #\(sprintNumber) CÍLE")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white.opacity(0.3))
                            .kerning(1.5)
                    }
                    
                    Spacer()
                    
                    let doneCount = sprintGoals.filter(\.isCompleted).count
                    Text("\(doneCount)/\(sprintGoals.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(doneCount == sprintGoals.count ? .green : .orange)
                }
                
                // Cíle
                VStack(spacing: 10) {
                    ForEach(sprintGoals.prefix(3)) { goal in
                        GoalRow(goal: goal) {
                            withAnimation(.spring(response: 0.3)) {
                                goal.isCompleted.toggle()
                                goal.completedAt = goal.isCompleted ? .now : nil
                                try? modelContext.save()
                            }
                            if goal.isCompleted {
                                HapticPatternEngine.shared.playSetComplete()
                            }
                        }
                    }
                }
                
                // Progres bar
                let progress = Double(sprintGoals.filter(\.isCompleted).count) / Double(sprintGoals.count)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.08))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(progress == 1 ?
                                  LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing) :
                                  LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress, height: 4)
                            .animation(.spring(response: 0.5), value: progress)
                    }
                }
                .frame(height: 4)
            }
            .padding(18)
            .glassCardStyle(cornerRadius: 20)
        }
    }
}

// MARK: - Goal Row

private struct GoalRow: View {
    let goal: SprintGoal
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    Circle()
                        .stroke(goal.isCompleted ? Color.green : Color.white.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if goal.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(goal.isCompleted ? .white.opacity(0.4) : .white)
                        .strikethrough(goal.isCompleted, color: .white.opacity(0.4))
                    
                    if !goal.metricTarget.isEmpty {
                        Text(goal.metricTarget)
                            .font(.system(size: 11))
                            .foregroundStyle(.orange.opacity(0.7))
                    }
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goal.title), \(goal.isCompleted ? "splněno" : "nesplněno")")
        .accessibilityHint("Klepnutím změníš stav cíle")
    }
}
