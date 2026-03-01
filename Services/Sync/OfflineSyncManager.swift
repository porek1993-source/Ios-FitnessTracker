// OfflineSyncManager.swift
import Foundation
import SwiftData

@MainActor
final class OfflineSyncManager {
    static let shared = OfflineSyncManager()
    
    private init() {}
    
    /// Spustí synchronizaci neodeslaných tréninků, pokud jsme online.
    func syncUnsyncedWorkouts(context: ModelContext) async {
        guard NetworkMonitor.shared.isConnected else {
            print("⚠️ [OfflineSyncManager] Zařízení je offline, sync přerušen.")
            return
        }
        
        // Zjistíme, které sessions ještě nejsou synchronizované
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.isSynced == false })
        
        guard let unsynced = try? context.fetch(descriptor) else {
            return
        }
        
        // Vybereme jen ty, které jsou už .finished
        let finishedToSync = unsynced.filter { $0.status == .completed }
        
        if finishedToSync.isEmpty {
            return
        }
        
        print("🔄 [OfflineSyncManager] Nalezeno \(finishedToSync.count) neodeslaných tréninků. Odesílám...")
        
        for session in finishedToSync {
            do {
                // Mock Network Upload k Supabase (cca 1 vteřina)
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                session.isSynced = true
                print("✅ [OfflineSyncManager] Trénink (\(session.id)) úspěšně synchronizován s cloudem.")
                
            } catch {
                print("❌ [OfflineSyncManager] Synchronizace selhala.")
            }
        }
        
        try? context.save()
    }
}
