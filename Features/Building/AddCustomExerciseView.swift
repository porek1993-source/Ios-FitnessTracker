// AddCustomExerciseView.swift
// Agilní Fitness Trenér — Přidání vlastního cviku

import SwiftUI
import SwiftData

struct AddCustomExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var selectedMuscle: MuscleGroup = .chest
    @State private var isUnilateral: Bool = false
    
    // Validace
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Základní údaje")) {
                    TextField("Název cviku", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    Picker("Hlavní svalová partie", selection: $selectedMuscle) {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Text(group.displayName).tag(group)
                        }
                    }
                    
                    Toggle("Jednostranný cvik (Unilaterální)", isOn: $isUnilateral)
                }
                
                Section(header: Text("Poznámka / Instrukce (Volitelné)")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Přidat vlastní cvik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušit") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uložit") {
                        saveExercise()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private func saveExercise() {
        let slug = "custom-\(UUID().uuidString.prefix(8).lowercased())"
        
        let newExercise = Exercise(
            slug: slug,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            nameEN: name, // Fallback
            category: .strength,
            movementPattern: .isolation,
            equipment: [],
            musclesTarget: [selectedMuscle],
            musclesSecondary: [],
            isUnilateral: isUnilateral,
            instructions: notes
        )
        newExercise.isCustom = true 
        
        modelContext.insert(newExercise)
        do {
            try modelContext.save()
        } catch {
            AppLogger.error("AddCustomExerciseView: Nepodařilo se uložit vlastní cvik '\(newExercise.name)': \(error)")
        }
        
        dismiss()
    }
}
