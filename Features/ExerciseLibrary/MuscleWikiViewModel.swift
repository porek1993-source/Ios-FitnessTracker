// MuscleWikiViewModel.swift
// Agilní Fitness Trenér — ViewModel pro knihovnu cviků z MuscleWiki
//
// OPRAVY v2.0:
//  ✅ Přidána time-based cache invalidace (data starší 1 hodiny se přenačtou)
//  ✅ loadAll() nyní akceptuje forceRefresh parametr pro pull-to-refresh
//  ✅ Přidán isRefreshing stav pro vizuální indikaci obnovy
//  ✅ Přidáno filtrování podle equipment (nový sloupec v tabulce)

import Foundation
import SwiftUI

@MainActor
final class MuscleWikiViewModel: ObservableObject {

    // MARK: - Published State

    @Published var exercises: [MuscleWikiExercise] = []
    @Published var selectedGroup: String? = nil
    @Published var selectedEquipment: String? = nil
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    // MARK: - Cache
    /// Čas posledního úspěšného načtení
    private var lastLoadedAt: Date?
    /// Cache invalidace po 1 hodině
    private let cacheMaxAge: TimeInterval = 3600

    // MARK: - Computed

    /// Dynamicky extrahované unikátní svalové skupiny (abecedně, lokalizovaně).
    var muscleGroups: [String] {
        let groups = Set(exercises.map { $0.muscleGroup })
        return groups.sorted()
    }

    /// Unikátní hodnoty equipment ze všech načtených cviků.
    var equipmentOptions: [String] {
        let equips = exercises.compactMap { $0.equipment }.filter { !$0.isEmpty }
        return Array(Set(equips)).sorted()
    }

    /// Filtrované cviky — podle vybrané skupiny, vybavení a vyhledávání.
    var filteredExercises: [MuscleWikiExercise] {
        var result = exercises

        if let group = selectedGroup {
            result = result.filter { $0.muscleGroup == group }
        }

        if let equip = selectedEquipment {
            result = result.filter { $0.equipment == equip }
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

    /// Počet cviků celkem a po filtrování.
    var exerciseCountLabel: String {
        if filteredExercises.count == exercises.count {
            return "\(exercises.count) cviků"
        }
        return "\(filteredExercises.count) z \(exercises.count) cviků"
    }

    // MARK: - Dependencies

    private let repository = SupabaseExerciseRepository()

    // MARK: - Load

    /// Načte cviky. Data se přeskočí pokud jsou čerstvá (< 1 hodina).
    /// Pokud forceRefresh == true, data se vždy obnoví.
    func loadAll(forceRefresh: Bool = false) async {
        // Cache check: pokud máme data a jsou čerstvá, přeskoč
        if !forceRefresh,
           !exercises.isEmpty,
           let lastLoad = lastLoadedAt,
           Date().timeIntervalSince(lastLoad) < cacheMaxAge {
            return
        }

        if exercises.isEmpty {
            isLoading = true
        } else {
            isRefreshing = true
        }
        errorMessage = nil

        do {
            let fetched = try await repository.fetchMuscleWikiAll()
            exercises = fetched
            lastLoadedAt = Date()
            AppLogger.info("✅ [MuscleWiki] Načteno \(fetched.count) cviků z muscle_wiki_data_full")
        } catch {
            errorMessage = "Nepodařilo se načíst cviky: \(error.localizedDescription)"
            AppLogger.error("⛔ [MuscleWiki] Chyba načítání: \(error)")
        }

        isLoading = false
        isRefreshing = false
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

    func selectEquipment(_ equipment: String?) {
        withAnimation(AppAnimation.quick) {
            if selectedEquipment == equipment {
                selectedEquipment = nil
            } else {
                selectedEquipment = equipment
            }
        }
    }

    func clearFilters() {
        withAnimation(AppAnimation.quick) {
            selectedGroup = nil
            selectedEquipment = nil
            searchText = ""
        }
    }

    func retry() async {
        exercises = []
        lastLoadedAt = nil
        await loadAll()
    }
}
