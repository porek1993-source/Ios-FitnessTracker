// CustomWorkoutBuilderView.swift
// Agilní Fitness Trenér — Ruční tvorba tréninků (Custom Builder)

import SwiftUI
import SwiftData

struct CustomWorkoutBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Načteme všechny dostupné cviky (od API i lokální)
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    
    // Stav Builderu
    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup? = nil
    
    // Seznam právě tvořených cviků
    @State private var workoutExercises: [BuilderExercise] = []
    
    // Zobrazení modalu pro tvorbu vlastního cviku
    @State private var showAddCustom = false
    
    struct BuilderExercise: Identifiable {
        let id = UUID()
        let exercise: Exercise
        var setsCount: Int = 3
    }
    
    var filteredExercises: [Exercise] {
        var base = allExercises
        if let g = selectedMuscleGroup {
            base = base.filter { $0.primaryMuscleGroup == g || $0.muscle_group == g.rawValue }
        }
        if !searchText.isEmpty {
            base = base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        // Vlastní cviky vždy nahoře
        return base.sorted { ($0.isCustom ? 0 : 1) < ($1.isCustom ? 0 : 1) }
    }

    var customExercises: [Exercise] {
        allExercises.filter { $0.isCustom }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Záložky: Výběr cviků VS Můj Trénink
                    exerciseSelectionList
                        .frame(maxHeight: workoutExercises.isEmpty ? .infinity : UIScreen.main.bounds.height * 0.5)
                    
                    if !workoutExercises.isEmpty {
                        Divider().background(Color.white.opacity(0.1))
                        selectedExercisesList
                            .transition(.move(edge: .bottom))
                    }
                }
            }
            .navigationTitle("Vlastní trénink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavřít") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .sheet(isPresented: $showAddCustom) {
                AddCustomExerciseView()
                    .presentationDetents([.fraction(0.85), .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - Výběr cviků (Horní polovina)
    
    private var exerciseSelectionList: some View {
        VStack(spacing: 0) {
            // Vyhledávání a Filtry
            VStack(spacing: 12) {
                // SearchBar
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.5))
                    TextField("Hledat cvik...", text: $searchText)
                        .foregroundStyle(.white)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Svalový Filtr
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(title: "Vše", isSelected: selectedMuscleGroup == nil) {
                            withAnimation { selectedMuscleGroup = nil }
                        }
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            filterChip(title: group.displayName, isSelected: selectedMuscleGroup == group) {
                                withAnimation { selectedMuscleGroup = group }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.02))
            
            // Seznam cviků k přidání
            List {
                // Sekce vlastní cviky (pokud existují a není aktivní vyhledávání)
                if !customExercises.isEmpty && searchText.isEmpty && selectedMuscleGroup == nil {
                    Section {
                        ForEach(customExercises) { ex in
                            exerciseRow(ex: ex)
                        }
                    } header: {
                        Text("Moje cviky")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.orange)
                            .textCase(nil)
                    }
                    Section {
                        ForEach(filteredExercises.filter { !$0.isCustom }) { ex in
                            exerciseRow(ex: ex)
                        }
                    } header: {
                        Text("Databáze cviků")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .textCase(nil)
                    }
                } else {
                    ForEach(filteredExercises) { ex in
                        exerciseRow(ex: ex)
                    }
                }

                // Tlačítko pro přidání vlastního cviku (vždy na konci)
                Button {
                    showAddCustom = true
                } label: {
                    HStack {
                        Image(systemName: "plus.app.fill")
                        Text("Nenašel jsi cvik? Přidej vlastní")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.blue)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
        }
    }
    
    // MARK: - Můj Trénink (Dolní polovina)
    
    private var selectedExercisesList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Cviky v tréninku")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(workoutExercises.count) cviků")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            
            List {
                ForEach($workoutExercises) { $item in
                    HStack {
                        Text(item.exercise.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        
                        // Stepper pro počet sérií
                        HStack(spacing: 12) {
                            Button { if item.setsCount > 1 { item.setsCount -= 1 } } label: { Image(systemName: "minus.circle").foregroundStyle(.blue) }
                            Text("\(item.setsCount) sérií")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 55, alignment: .center)
                            Button { item.setsCount += 1 } label: { Image(systemName: "plus.circle").foregroundStyle(.blue) }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                .onDelete { indices in
                    withAnimation { workoutExercises.remove(atOffsets: indices) }
                }
            }
            .listStyle(.plain)
            
            // Uložit tlačítko
            Button(action: saveWorkoutSession) {
                Text("Spustit tento trénink")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(16)
            .padding(.bottom, 16)
        }
        .background(AppColors.secondaryBg)
    }
    
    // MARK: - Helper Views

    @ViewBuilder
    private func exerciseRow(ex: Exercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if ex.isCustom {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                    Text(ex.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(ex.muscle_group)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Button {
                withAnimation {
                    workoutExercises.append(BuilderExercise(exercise: ex))
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
    }
    
    // MARK: - Save Logic
    
    private func saveWorkoutSession() {
        guard !workoutExercises.isEmpty else { return }
        
        let plan = PlannedWorkoutDay(
            dayOfWeek: 0, // Marker pro vlastní trénink
            label: "Vlastní Trénink"
        )
        modelContext.insert(plan)
        
        // 1. Vytvoříme session
        let session = WorkoutSession(plan: nil, plannedDay: plan)
        modelContext.insert(session)
        
        // 2. Přidáme cviky do plánu i do session pro okamžitý start
        for (index, builderEx) in workoutExercises.enumerated() {
            // Přidání do plánu (pro historii)
            let plannedEx = PlannedExercise(
                order: index,
                exercise: builderEx.exercise,
                targetSets: builderEx.setsCount,
                targetRepsMin: 8,
                targetRepsMax: 12
            )
            plannedEx.plannedDay = plan
            
            // Přidání do session (pro aktivní trénink)
            _ = SessionExercise(
                order: index,
                exercise: builderEx.exercise,
                session: session
            )
        }
        
        do {
            try modelContext.save()
        } catch {
            AppLogger.error("CustomWorkoutBuilderView: Nepodařilo se uložit vlastní trénink: \(error)")
        }
        
        // 👋 Oznámit Dashboardu, že má spustit tento konkrétní trénink
        NotificationCenter.default.post(name: NSNotification.Name("StartCustomWorkout"), object: session)
        
        dismiss()
    }
}
