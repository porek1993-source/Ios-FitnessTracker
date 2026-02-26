// MuscleWikiViewModel.swift
// Agilní Fitness Trenér — ViewModel pro knihovnu cviků z MuscleWiki

import Foundation
import SwiftUI

@MainActor
final class MuscleWikiViewModel: ObservableObject {

    // MARK: - Published State

    @Published var exercises: [MuscleWikiExercise] = []
    @Published var selectedGroup: String? = nil
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Computed

    /// Dynamicky extrahované unikátní svalové skupiny (abecedně).
    var muscleGroups: [String] {
        let groups = Set(exercises.map { $0.muscleGroup })
        return groups.sorted()
    }

    /// Filtrované cviky — podle vybrané skupiny a vyhledávání.
    var filteredExercises: [MuscleWikiExercise] {
        var result = exercises

        if let group = selectedGroup {
            result = result.filter { $0.muscleGroup == group }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    /// Seskupené cviky podle svalové partie (pro sekční zobrazení).
    var groupedExercises: [(group: String, exercises: [MuscleWikiExercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { $0.muscleGroup }
        return grouped
            .map { (group: $0.key, exercises: $0.value) }
            .sorted { $0.group < $1.group }
    }

    // MARK: - Dependencies

    private let repository = SupabaseExerciseRepository()

    // MARK: - Load

    func loadAll() async {
        guard exercises.isEmpty else { return } // Nenačítej znovu pokud už máme data
        isLoading = true
        errorMessage = nil

        do {
            exercises = try await repository.fetchMuscleWikiAll()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Nepodařilo se načíst cviky: \(error.localizedDescription)"
        }
    }

    // MARK: - Actions

    func selectGroup(_ group: String?) {
        withAnimation(AppAnimation.quick) {
            if selectedGroup == group {
                selectedGroup = nil
            } else {
                selectedGroup = group
            }
        }
    }

    func retry() async {
        exercises = []
        await loadAll()
    }
}
