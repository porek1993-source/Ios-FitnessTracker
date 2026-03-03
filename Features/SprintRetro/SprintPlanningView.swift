// SprintPlanningView.swift
// Definice Sprint Goals (User Stories) — klíčový prvek agilního koučinku
// ✅ deepanal.pdf bod 9: "User Stories — Definice cílů se Sprint Planning"

import SwiftUI
import SwiftData

struct SprintPlanningView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<SprintGoal> { $0.isCompleted == false }) private var activeGoals: [SprintGoal]
    
    @State private var newGoalTitle: String = ""
    @State private var newGoalDescription: String = ""
    @State private var showingAddSheet = false
    
    let sprintNumber: Int
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        
                        if activeGoals.isEmpty {
                            emptyState
                        } else {
                            goalsList
                        }
                    }
                    .padding(20)
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                            Text("Přidat User Story")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(AppColors.primaryAccent)
                                .shadow(color: AppColors.primaryAccent.opacity(0.4), radius: 10, y: 5)
                        )
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Sprint Planning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zavřít") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                addGoalSheet
            }
        }
    }
    
    // MARK: - Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SPRINT #\(sprintNumber)")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.cyan.opacity(0.8))
                .kerning(2)
            
            Text("Definuj své cíle")
                .font(.system(.largeTitle, design: .rounded)).bold()
                .foregroundStyle(.white)
            
            Text("Zaměř se na 2-3 měřitelné výsledky, kterých chceš v tomto bloku dosáhnout.")
                .font(.system(.body))
                .foregroundStyle(.white.opacity(0.6))
                .lineSpacing(4)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.1))
                .padding(.top, 40)
            
            Text("Zatím žádné cíle")
                .font(.system(.headline))
                .foregroundStyle(.white.opacity(0.4))
            
            Text("Naplánuj si úspěch přidáním první User Story.")
                .font(.system(.subheadline))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var goalsList: some View {
        VStack(spacing: 16) {
            ForEach(activeGoals) { goal in
                GoalCard(goal: goal) {
                    deleteGoal(goal)
                }
            }
        }
    }
    
    private var addGoalSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NÁZEV CÍLE")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white.opacity(0.4))
                        
                        TextField("Např. Benčpres 100kg", text: $newGoalTitle)
                            .textFieldStyle(.plain)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.08)))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DETAIL / DEFINITION OF DONE")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white.opacity(0.4))
                        
                        TextEditor(text: $newGoalDescription)
                            .frame(height: 120)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.08)))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: addGoal) {
                        Text("Uložit cíl")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule().fill(AppColors.primaryAccent))
                    }
                    .disabled(newGoalTitle.isEmpty)
                }
                .padding(24)
            }
            .navigationTitle("Nová User Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit") { showingAddSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Actions
    
    private func addGoal() {
        let goal = SprintGoal(
            title: newGoalTitle,
            goalDescription: newGoalDescription,
            sprintNumber: sprintNumber
        )
        modelContext.insert(goal)
        
        newGoalTitle = ""
        newGoalDescription = ""
        showingAddSheet = false
        
        HapticPatternEngine.shared.playSuccess()
    }
    
    private func deleteGoal(_ goal: SprintGoal) {
        modelContext.delete(goal)
    }
}

// MARK: - Goal Card Component

private struct GoalCard: View {
    let goal: SprintGoal
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.orange)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                
                if !goal.goalDescription.isEmpty {
                    Text(goal.goalDescription)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(10)
            }
        }
        .padding(16)
        .glassCardStyle()
    }
}
