// ExerciseDetailViewModel.swift
// ViewModel pro detail cviku — načítá data ze Supabase a doplňuje přes AI.

import Foundation
import SwiftUI

@MainActor
final class ExerciseDetailViewModel: ObservableObject {

    // MARK: - Published State

    @Published var exercise: ExerciseDTO?
    @Published var enrichedData: AIEnrichedExerciseData?
    @Published var isLoadingExercise = false
    @Published var isEnriching = false
    @Published var errorMessage: String?

    // MARK: - Computed

    /// Název cviku — vždy česky.
    var displayName: String {
        exercise?.nameCz ?? "Načítání…"
    }

    /// Vybavení — AI data mají prioritu, pak DB.
    var equipment: String? {
        enrichedData?.equipment ?? exercise?.equipment
    }

    /// Primární svaly — AI data mají prioritu, pak DB.
    var muscles: [String] {
        enrichedData?.primaryMuscles ?? exercise?.primaryMuscles ?? []
    }

    /// Přesný anglický název z AI nebo DB.
    var nameEn: String? {
        enrichedData?.nameEn ?? exercise?.nameEn
    }

    /// Instrukce — AI data mají prioritu, pak DB.
    var instructions: String? {
        enrichedData?.instructions ?? exercise?.instructions
    }

    /// Sekundární svaly — AI data mají prioritu, pak DB.
    var secondaryMuscles: [String] {
        enrichedData?.secondaryMuscles ?? exercise?.secondaryMuscles ?? []
    }

    /// YouTube URL pro tutoriál.
    var youtubeURL: URL? {
        guard let ex = exercise else { return nil }
        let resolvedNameEn = nameEn ?? "" // nameEn is computed and already handles nested optionals
        return YouTubeLinkGenerator.searchURL(nameEn: resolvedNameEn, nameCz: ex.safeNameCz)
    }

    /// Má cvik kompletní data?
    var hasCompleteData: Bool {
        instructions != nil && !muscles.isEmpty && equipment != nil
    }

    // MARK: - Dependencies

    private let repository = SupabaseExerciseRepository()
    private let enrichmentService = ExerciseAIEnrichmentService()

    // MARK: - Load

    /// Načte cvik ze Supabase a pokud chybí instrukce, spustí AI enrichment.
    func load(slug: String) async {
        isLoadingExercise = true
        errorMessage = nil

        do {
            let dto = try await repository.fetchBySlug(slug)
            exercise = dto
            isLoadingExercise = false

            // Pokud instrukce chybí, spustíme AI enrichment
            if let dto, dto.isMissing {
                await enrichWithAI(slug: dto.safeSlug, nameCz: dto.safeNameCz)
            }
        } catch {
            isLoadingExercise = false
            errorMessage = "Nepodařilo se načíst cvik: \(error.localizedDescription)"
            HapticManager.shared.playError()
        }
    }

    /// Explicitní opětovné načtení.
    func retry(slug: String) async {
        enrichedData = nil
        await load(slug: slug)
    }

    // MARK: - AI Enrichment

    private func enrichWithAI(slug: String, nameCz: String) async {
        isEnriching = true
        defer { isEnriching = false }

        do {
            let data = try await enrichmentService.enrichExercise(nameCz: nameCz)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                enrichedData = data
            }
            HapticManager.shared.playSuccess()

            // Fire and forget zápis do Supabase
            Task {
                do {
                    try await repository.updateExercise(slug: slug, with: data)
                    AppLogger.info("[ExerciseDetail] Obohacená data úspěšně uložena do Supabase pro cvik: \(slug)")
                } catch {
                    AppLogger.error("[ExerciseDetail] Chyba při asynchronním ukládání do Supabase: \(error.localizedDescription)")
                }
            }

        } catch {
            // Enrichment selhal — zobrazíme co máme, nepřerušujeme UX
            AppLogger.error("[ExerciseDetail] AI enrichment selhal: \(error.localizedDescription)")
        }
    }
}
