// OfflineSyncManager.swift
// Agilní Fitness Trenér — Synchronizace dokončených tréninků do Supabase
//
// Logika:
//   • Hledá WorkoutSession se statusem .completed a isSynced == false
//   • Volá SupabaseExerciseRepository.syncWorkoutSession() pro každý neodeslaný trénink
//   • Po úspěšném uložení nastaví session.isSynced = true a uloží do SwiftData
//   • Chráněno proti souběžným voláním pomocí `isSyncing` flagu
//   • Spouštěno z AppEnvironment po NotificationCenter "NetworkBecameAvailable"
//
// ✅ v2.2 OPRAVY:
//  ✅ configure(repository:) — akceptuje sdílenou instanci z AppEnvironment (odstraňuje duplicitní init)
//  ✅ Retry logika pro přechodné síťové chyby (max 2 pokusy s exponential backoff)

import Foundation
import SwiftData

@MainActor
final class OfflineSyncManager {
    static let shared = OfflineSyncManager()

    private var repository: SupabaseExerciseRepository
    private var isSyncing = false

    private init() {
        // Výchozí instance — nahradí se přes configure(repository:) při startu aplikace
        self.repository = SupabaseExerciseRepository()
    }

    /// Injektuje sdílenou instanci SupabaseExerciseRepository z AppEnvironment.
    /// ✅ FIX: Odstraňuje duplicitní instanci (dříve OfflineSyncManager + AppEnvironment = 2 instance)
    func configure(repository: SupabaseExerciseRepository) {
        self.repository = repository
    }

    // MARK: - Public API

    /// Spustí synchronizaci neodeslaných tréninků, pokud jsme online.
    /// Bezpečné pro opakované volání — chrání proti race conditions.
    func syncUnsyncedWorkouts(context: ModelContext) async {
        guard NetworkMonitor.shared.isConnected else {
            AppLogger.warning("[OfflineSync] Zařízení je offline, sync přerušen.")
            return
        }
        guard !isSyncing else {
            AppLogger.info("[OfflineSync] Sync již probíhá, přeskakuji.")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isSynced == false && $0.statusRaw == "completed" }
        )

        guard let unsynced = try? context.fetch(descriptor), !unsynced.isEmpty else {
            AppLogger.info("[OfflineSync] Žádné neodeslaný tréninky k synchronizaci.")
            return
        }

        AppLogger.info("[OfflineSync] Nalezeno \(unsynced.count) neodeslaných tréninků. Odesílám...")

        var successCount = 0
        var failCount    = 0

        for session in unsynced {
            // Konstrukce DTO na MainActoru (bezpečné pro ne-Sendable session)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let dto = SupabaseExerciseRepository.WorkoutSessionDTO(
                id:                    session.id.uuidString,
                startedAt:             iso.string(from: session.startedAt),
                finishedAt:            session.finishedAt.map { iso.string(from: $0) },
                durationMinutes:       session.durationMinutes,
                status:                session.statusRaw,
                plannedDayName:        session.plannedDay?.label,
                readinessScore:        session.readinessScore,
                aiAdaptationNote:      session.aiAdaptationNote,
                userFeedbackEnergy:    session.userFeedbackEnergy,
                userFeedbackDifficulty: session.userFeedbackDifficulty,
                userNotes:             session.userNotes
            )

            // ✅ Retry s exponential backoff pro přechodné síťové chyby
            var attempts = 0
            var succeeded = false
            while attempts < 2 && !succeeded {
                do {
                    try await repository.syncWorkoutSession(dto)
                    session.isSynced = true
                    successCount += 1
                    succeeded = true
                    AppLogger.success("[OfflineSync] Trénink \(session.id.uuidString.prefix(8)) → Supabase ✅")
                } catch {
                    attempts += 1
                    if attempts < 2 {
                        let delay = pow(2.0, Double(attempts))
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } else {
                        failCount += 1
                        AppLogger.error("[OfflineSync] Sync selhala pro \(session.id.uuidString.prefix(8)): \(error.localizedDescription)")
                        // Nepřerušujeme loop — ostatní session mohou projít
                    }
                }
            }
        }

        try? context.save()

        if failCount == 0 {
            AppLogger.success("[OfflineSync] Synchronizace dokončena — \(successCount)/\(unsynced.count) úspěšně.")
        } else {
            AppLogger.warning("[OfflineSync] Synchronizace dokončena s chybami — \(successCount) OK, \(failCount) selhaných.")
        }
    }
}
