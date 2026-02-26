// AppEnvironment.swift
// Agilní Fitness Trenér — Centrální Dependency Injection kontejner
//
// ✅ Jediné místo inicializace sdílených služeb (prevence memory leaků)
// ✅ @MainActor zajišťuje thread-safe přístup ke všem @Published properties
// ✅ Lazy inicializace těžkých závislostí
// ✅ Bezpečný přístup přes @EnvironmentObject

import SwiftUI
import SwiftData

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: AppEnvironment — centrální DI kontejner
// MARK: ═══════════════════════════════════════════════════════════════════════

@MainActor
final class AppEnvironment: ObservableObject {

    // MARK: - Sdílené služby (singleton instance)

    /// HealthKit — sdílená instance, předává se přes .environmentObject
    let healthKitService: HealthKitService

    /// Background sync manager — spravuje BGTask registraci
    let healthBackgroundManager: HealthBackgroundManager

    /// AI trenér — závislý na ModelContext a HealthKitService
    /// Lazy — inicializuje se až po dostupnosti modelContext
    private(set) var aiTrainerService: AITrainerService?

    /// Supabase repository — actor-isolated, bezpečný pro concurrent přístup
    let exerciseRepository: SupabaseExerciseRepository

    // MARK: - Global Error State

    /// Globální chybový stav pro GlobalErrorModifier
    @Published var globalError: AppToastError?

    // MARK: - Inicializace

    init() {
        self.healthKitService        = HealthKitService()
        self.healthBackgroundManager = HealthBackgroundManager.shared
        self.exerciseRepository      = SupabaseExerciseRepository()
    }

    /// Voláno z App.swift po dostupnosti ModelContext.
    /// Až zde inicializujeme závislosti na SwiftData.
    func configure(modelContext: ModelContext) {
        self.aiTrainerService = AITrainerService(
            modelContext: modelContext,
            healthKitService: healthKitService
        )
    }

    // MARK: - Startup Sequence

    /// Orchestruje veškerou inicializaci při startu aplikace.
    /// Volá se jednou z App.swift v .task modifikátoru.
    func performStartup(modelContext: ModelContext) async {
        // 1. Konfiguruj závislosti na SwiftData
        configure(modelContext: modelContext)

        // 2. Registruj background tasky (musí být před jakýmkoliv schedulováním)
        healthBackgroundManager.registerBackgroundTasks()
        healthBackgroundManager.scheduleNextSync()

        // 3. Týdenní report notifikace
        WeeklyReportService.scheduleWeeklyNotificationIfNeeded()

        // 4. Seed databáze cviků (jen při prvním spuštění)
        ExerciseDatabaseLoader.seedIfNeeded(context: modelContext)

        // 5. Notifikační oprávnění + reminder (non-blocking)
        Task.detached(priority: .utility) {
            _ = await NotificationService.shared.requestPermission()
            await NotificationService.shared.scheduleWorkoutReminder(hour: 8, minute: 30)
        }

        // 6. HealthKit autorizace + foreground sync (non-blocking)
        Task {
            await healthKitService.checkAuthorizationStatus()
            try? await healthKitService.requestAuthorization()
            await healthBackgroundManager.performForegroundSync(healthKit: healthKitService)
        }
    }

    // MARK: - Global Error Handling

    /// Zobrazí globální toast chybu. Bezpečné volání z libovolného místa.
    func showError(_ error: AppToastError) {
        globalError = error
    }

    func showError(message: String, icon: String = "exclamationmark.triangle.fill") {
        globalError = AppToastError(message: message, icon: icon)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: AppToastError — datový model pro globální chyby
// MARK: ═══════════════════════════════════════════════════════════════════════

struct AppToastError: Identifiable, Equatable {
    let id        = UUID()
    let message:  String
    let icon:     String
    var severity: Severity = .warning

    enum Severity { case info, warning, error }

    // Předpřipravené chyby
    static let noInternet = AppToastError(
        message:  "Žádné připojení k internetu. Jakub pracuje offline.",
        icon:     "wifi.slash",
        severity: .warning
    )
    static let apiTimeout = AppToastError(
        message:  "Jakub neodpovídá. Načítám záložní plán…",
        icon:     "clock.badge.exclamationmark.fill",
        severity: .warning
    )
    static let syncFailed = AppToastError(
        message:  "Synchronizace zdravotních dat selhala.",
        icon:     "heart.slash.fill",
        severity: .error
    )
    static let savedOK = AppToastError(
        message:  "Trénink uložen! 💪",
        icon:     "checkmark.circle.fill",
        severity: .info
    )
}
