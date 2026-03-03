// SprintRetroViewModel.swift
// ViewModel pro Sprint Retrospektivu
// ✅ deepanal.pdf bod 8: Křížová analýza subjektivních vstupů s kvantitativními daty

import Foundation
import SwiftData

@MainActor
final class SprintRetroViewModel: ObservableObject {
    // Statistiky
    @Published var completedSessions: Int = 0
    @Published var missedSessions: Int = 0
    @Published var totalVolume: Double = 0
    
    // Subjektivní vstupy
    @Published var whatWorked: String = ""
    @Published var whatFailed: String = ""
    @Published var obstacles: String = ""
    
    // AI výstup
    @Published var retroSummary: String?
    @Published var isGenerating: Bool = false
    
    // Cíle pro další sprint
    @Published var nextSprintGoals: [String] = [""]
    
    // MARK: - Load Stats
    
    func loadSprintStats(plan: WorkoutPlan) {
        let sprintStart = plan.sprintStartDate
        
        let sprintSessions = plan.sessions.filter { $0.startedAt >= sprintStart }
        completedSessions = sprintSessions.filter { $0.status == .completed }.count
        
        // Spočítáme vynechané: celkový počet plánovaných tréninkových dnů - splněné
        let totalPlannedDays = plan.scheduledDays.filter { !$0.isRestDay }.count
        let weeksSinceSprint = max(1, Calendar.current.dateComponents([.weekOfYear], from: sprintStart, to: .now).weekOfYear ?? 1)
        let expectedTotal = totalPlannedDays * weeksSinceSprint
        missedSessions = max(0, expectedTotal - completedSessions)
        
        // Celkový objem (suma kg * reps přes všechny kompletované sessions)
        let completed = sprintSessions.filter { $0.status == .completed }
        var vol: Double = 0
        for session in completed {
            for exercise in session.exercises {
                for set in exercise.completedSets {
                    vol += (set.weightKg * Double(set.reps))
                }
            }
        }
        totalVolume = vol
    }
    
    // MARK: - AI Retrospective
    
    func generateRetrospective(ai: AITrainerService, plan: WorkoutPlan) async {
        isGenerating = true
        defer { isGenerating = false }
        
        let prompt = """
        Jsi fitness trenér iKorba. Uživatel právě dokončil Sprint #\(plan.sprintNumber) (\(plan.durationWeeks) týdnů).
        
        STATISTIKY SPRINTU:
        - Splněné tréninky: \(completedSessions)
        - Vynechané: \(missedSessions)
        - Celkový objem: \(String(format: "%.0f", totalVolume)) kg
        - Split: \(plan.splitType.displayName)
        
        SUBJEKTIVNÍ HODNOCENÍ UŽIVATELE:
        - Co fungovalo: \(whatWorked.isEmpty ? "neuvedeno" : whatWorked)
        - Co nefungovalo: \(whatFailed.isEmpty ? "neuvedeno" : whatFailed)
        - Překážky: \(obstacles.isEmpty ? "neuvedeno" : obstacles)
        
        Na základě těchto dat:
        1. Krátce shrň výkonnost sprintu (2-3 věty)
        2. Doporuč úpravu pro další sprint (objem/intenzita/frekvence)
        3. Navrhni 2-3 konkrétní cíle pro další sprint
        
        Odpověz česky, stručně a motivačně. Max 150 slov.
        """
        
        do {
            let response = try await ai.sendRawPrompt(prompt)
            retroSummary = response
        } catch {
            retroSummary = "Nepodařilo se vygenerovat analýzu: \(error.localizedDescription)"
        }
    }
    
    // MARK: - New Sprint
    
    func startNewSprint(plan: WorkoutPlan?, modelContext: ModelContext) {
        guard let plan else { return }
        
        plan.sprintNumber += 1
        plan.sprintStartDate = .now
        plan.lastAdaptedAt = .now
        
        // Uložíme cíle
        let goals = nextSprintGoals
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { SprintGoal(title: $0, sprintNumber: plan.sprintNumber) }
        
        for goal in goals {
            modelContext.insert(goal)
        }
        
        try? modelContext.save()
        AppLogger.info("SprintRetroVM: Spuštěn Sprint #\(plan.sprintNumber) s \(goals.count) cíli")
    }
}
