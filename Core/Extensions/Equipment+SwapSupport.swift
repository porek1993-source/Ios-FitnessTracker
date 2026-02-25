// Equipment+SwapSupport.swift
// Agilní Fitness Trenér — Equipment enum (přidej do Exercise.swift pokud tam chybí)
// + integrace SwapExerciseSheet do WorkoutView

import SwiftUI
import SwiftData

// MARK: - Equipment enum
// Přidej toto do Exercise.swift

// Equipment enum je nyní v Data/Models/Exercise.swift

// MARK: - Integrace do WorkoutView
// Přidej do WorkoutView.swift:

/*

struct WorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var session: WorkoutSessionViewModel  // tvůj VM

    // --- SWAP STATE ---
    @State private var swapTarget: SessionExercise?
    @State private var showSwapSheet = false
    @Query private var allExercises: [Exercise]

    var body: some View {
        ScrollView {
            ForEach(session.exercises) { sessionExercise in
                ExerciseCard(sessionExercise: sessionExercise)
                    .overlay(alignment: .topTrailing) {

                        // ← TLAČÍTKO NAHRADIT
                        Button {
                            swapTarget = sessionExercise
                            showSwapSheet = true
                        } label: {
                            Label("Nahradit", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        .padding(12)
                    }
            }
        }
        .sheet(isPresented: $showSwapSheet) {
            if let target = swapTarget {
                SwapExerciseSheet(
                    sessionExercise: target,
                    allExercises: allExercises,
                    plannedExercises: session.plannedDay?.plannedExercises ?? [],
                    onSwap: { newExercise, reason in
                        performSwap(on: target, with: newExercise, reason: reason)
                    },
                    onApplyTimeOptimization: { plan in
                        applyTimeOptimization(plan)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }

    // MARK: Swap handler
    private func performSwap(
        on sessionExercise: SessionExercise,
        with newExercise: Exercise,
        reason: String
    ) {
        sessionExercise.exercise = newExercise
        sessionExercise.wasSubstituted = true
        sessionExercise.substitutionReason = reason
        // SwiftData automaticky uloží změny při příštím save pointu
    }

    // MARK: Time optimization handler
    private func applyTimeOptimization(_ plan: TimeOptimizationPlan) {
        // Odstraň cviky mimo optimalizovaný plán
        let keptExercises = Set(plan.keptExercises.compactMap { $0.exercise?.id })
        session.exercises.removeAll { ex in
            guard let id = ex.exercise?.id else { return false }
            return !keptExercises.contains(id)
        }

        // Označ supersérie (volitelné — pro UI zobrazení)
        for (a, b) in plan.supersets {
            if let exA = session.exercises.first(where: { $0.exercise?.id == a.exercise?.id }),
               let exB = session.exercises.first(where: { $0.exercise?.id == b.exercise?.id }) {
                exA.substitutionReason = "Supersérie s \(b.exercise?.name ?? "")"
                exB.substitutionReason = "Supersérie s \(a.exercise?.name ?? "")"
            }
        }
    }
}

*/


