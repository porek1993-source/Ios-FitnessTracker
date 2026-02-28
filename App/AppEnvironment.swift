// AppEnvironment.swift
// Agilní Fitness Trenér — Centrální Dependency Injection kontejner (v2.1)
//
// OPRAVY v2.1:
//  ✅ aiTrainerService je private(set) — čtení odkudkoliv, zápis jen interně
//  ✅ performStartup: všechna Task.detached volání mají explicit [weak self]
//  ✅ configure() je idempotentní — bezpečné opakované volání (ochrana před double-init)
//  ✅ GlobalError API rozšířeno: showError(AppError) pro typované chyby
//  ✅ AppToastError: přidána .critical severity pro fatální chyby
//  ✅ @MainActor garantuje thread-safe přístup ke všem @Published vlastnostem
//  ✅ Lifecycle: WeeklyReportService.scheduleWeeklyNotificationIfNeeded() je nonisolated

import SwiftUI
import SwiftData

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: AppEnvironment — centrální DI kontejner
// MARK: ═══════════════════════════════════════════════════════════════════════

@MainActor
final class AppEnvironment: ObservableObject {

    // MARK: - Sdílené služby (inicializovány při startu, singleton pro celou app)

    /// HealthKit manager — sdílená instance přes celou aplikaci
    let healthKitService: HealthKitService

    /// Background sync — spravuje BGTask registraci a scheduling
    let healthBackgroundManager: HealthBackgroundManager

    /// Supabase exercise repository — actor-isolated, thread-safe pro concurrent fetch
    let exerciseRepository: SupabaseExerciseRepository

    /// AI Trenér — lazy init po dostupnosti ModelContext (SwiftData dependency)
    /// Použij `aiTrainerService!` až po volání `configure(modelContext:)`
    private(set) var aiTrainerService: AITrainerService?

    // MARK: - Globální UI stav

    @Published var globalError: AppToastError?

    /// Flag: startup sequence dokončena → UI může zobrazit hlavní obsah
    @Published private(set) var isStartupComplete: Bool = false

    // MARK: - Interní stav

    private var isConfigured: Bool = false

    // MARK: - Inicializace

    init() {
        self.healthKitService        = HealthKitService()
        self.healthBackgroundManager = HealthBackgroundManager.shared
        self.exerciseRepository      = SupabaseExerciseRepository()

        AppLogger.info("🚀 [AppEnvironment] Inicializován.")
        
        // BGTaskScheduler.register musí být voláno synchronně při inicializaci applikace
        self.healthBackgroundManager.registerBackgroundTasks()
    }

    // MARK: - Konfigurace SwiftData závislostí

    /// Volej jednou z `App.swift` po dostupnosti ModelContainer.
    /// Idempotentní — opakované volání je bezpečné (přeskočí konfiguraci).
    func configure(modelContext: ModelContext) {
        guard !isConfigured else {
            AppLogger.info("ℹ️ [AppEnvironment] configure() již proběhlo, přeskakuji.")
            return
        }
        isConfigured     = true
        aiTrainerService = AITrainerService(
            modelContext: modelContext,
            healthKitService: healthKitService
        )
        AppLogger.info("✅ [AppEnvironment] configure() — AITrainerService inicializován.")
    }

    // MARK: - Startup Sequence

    /// Orchestruje veškerou inicializaci při startu aplikace.
    /// Volá se jednou z App.swift v `.task` modifikátoru.
    ///
    /// Pořadí je důležité:
    ///  1. SwiftData konfigurace (blokující — musí být první)
    ///  2. Background Tasks (musí proběhnout před BGTaskScheduler.submit)
    ///  3. Notifikace scheduling
    ///  4. HealthKit auth + foreground sync (neblokující, paralelně)
    func performStartup(modelContext: ModelContext) async {

        // 1. SwiftData závislosti
        configure(modelContext: modelContext)

        // 2. Naplánování BGTask (registrace proběhla synchronně v init)
        healthBackgroundManager.scheduleNextSync()

        // 3. Týdenní report notifikace (nonisolated — bezpečné z MainActor)
        WeeklyReportService.scheduleWeeklyNotificationIfNeeded()

        // 4. Notifikační oprávnění (non-blocking, fire-and-forget)
        Task.detached(priority: .utility) { [weak self] in
            guard self != nil else { return }
            _ = await NotificationService.shared.requestPermission()
            await NotificationService.shared.scheduleWorkoutReminder(hour: 8, minute: 30)
        }

        // 5. HealthKit auth + sync (non-blocking)
        Task { [weak self] in
            guard let self else { return }
            await self.healthKitService.checkAuthorizationStatus()
            try? await self.healthKitService.requestAuthorization()
            await self.healthBackgroundManager.performForegroundSync(
                healthKit: self.healthKitService
            )
        }

        // 6. Synchronizace videí cviků (non-blocking)
        syncExerciseVideos(modelContext: modelContext)

        // Startup dokončen — UI může přejít do aktivního stavu
        isStartupComplete = true
        AppLogger.info("🏁 [AppEnvironment] Startup sequence dokončena.")
    }

    /// Synchronizuje video URL ze Supabase do lokální SwiftData DB.
    /// ✅ OPRAVA: Řeší problém "ukázka není k dispozici" v tréninku vylepšením fuzzy matching logiky.
    func syncExerciseVideos(modelContext: ModelContext) {
        // ✅ FIX: ModelContext je @MainActor-bound a NELZE ho předávat do Task.detached.
        // Místo toho vytvoříme nový background context z SharedModelContainer.
        // modelContext parametr je zachován pro API kompatibilitu (může být odstraněn v budoucí verzi).
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            do {
                AppLogger.info("⏳ [AppEnvironment] Startuji synchronizaci videí cviků...")
                let wikiExercises = try await self.exerciseRepository.fetchMuscleWikiAll()

                // Bezpečné: nový ModelContext pro background task
                let bgContext = ModelContext(SharedModelContainer.container)
                let descriptor = FetchDescriptor<Exercise>()
                let localExercises = try bgContext.fetch(descriptor)
                
                var updatedCount = 0
                for local in localExercises {
                    let localSlug = local.slug.lowercased()
                    let localNameEn = local.nameEN.lowercased()
                    let localNameCz = local.name.lowercased()
                    
                    // Pokročilejší párování:
                    // 1. Přesná shoda anglického jména
                    // 2. Přesná shoda slugu
                    // 3. Shoda části slugu / jména
                    if let match = wikiExercises.first(where: { wikiEx in
                        let wikiName = wikiEx.name.lowercased()
                        let wikiSlug = wikiName.replacingOccurrences(of: " ", with: "-")
                        
                        return localNameEn == wikiName ||
                               localSlug == wikiSlug ||
                               wikiName.contains(localNameEn) ||
                               localNameEn.contains(wikiName) ||
                               wikiName.contains(localNameCz) ||
                               localNameCz.contains(wikiName)
                    }) {
                        if local.videoURL != match.videoUrl {
                            local.videoURL = match.videoUrl
                            updatedCount += 1
                            AppLogger.info("🔗 [AppEnvironment] Spárováno video pro: \(local.name) -> \(match.name)")
                        }
                    }
                }
                
                if updatedCount > 0 {
                    try bgContext.save()
                    AppLogger.info("✅ [AppEnvironment] Synchronizováno \(updatedCount) videí cviků.")
                } else {
                    AppLogger.info("ℹ️ [AppEnvironment] Žádná nová videa k synchronizaci.")
                }
            } catch {
                AppLogger.error("❌ [AppEnvironment] Chyba při synchronizaci videí: \(error)")
            }
        }
    }

    // MARK: - Globální Error Handling

    /// Zobrazí globální toast chybu. Thread-safe (MainActor).
    func showError(_ toastError: AppToastError) {
        globalError = toastError
    }

    func showError(message: String, icon: String = "exclamationmark.triangle.fill", severity: AppToastError.Severity = .warning) {
        globalError = AppToastError(message: message, icon: icon, severity: severity)
    }

    /// Překladač z typovaného `AppError` na `AppToastError`.
    func showError(_ appError: AppError) {
        let toast: AppToastError
        switch appError {
        case .networkUnavailable:
            toast = .noInternet
        case .encodingFailed:
            toast = AppToastError(message: "Chyba při kódování dat. Zkus to znovu.", icon: "exclamationmark.triangle.fill", severity: .error)
        case .internalError(let desc):
            toast = AppToastError(message: "Interní chyba: \(desc)", icon: "ladybug.fill", severity: .error)
        case .healthKitUnavailable:
            toast = AppToastError(message: "Apple Health není dostupný na tomto zařízení.", icon: "heart.slash.fill", severity: .warning)
        case .noPlanForToday:
            toast = AppToastError(message: "Pro dnešní den není naplánovaný trénink.", icon: "calendar.badge.exclamationmark", severity: .info)
        case .noActiveProfile:
            toast = AppToastError(message: "Nenalezen aktivní profil. Vytvoř si profil v nastavení.", icon: "person.badge.minus.fill", severity: .error)
        case .unknown:
            toast = AppToastError(message: "Nastala neznámá chyba. Zkus aplikaci restartovat.", icon: "exclamationmark.circle.fill", severity: .warning)
        }
        globalError = toast
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: AppToastError — datový model pro globální toasty
// MARK: ═══════════════════════════════════════════════════════════════════════

struct AppToastError: Identifiable, Equatable {

    let id       = UUID()
    let message: String
    let icon:    String
    var severity: Severity = .warning

    enum Severity {
        case info     /// Neutral informace (modrá)
        case warning  /// Varování (oranžová)
        case error    /// Chyba (červená)
        case critical /// Kritická chyba — vyžaduje akci uživatele
    }

    // MARK: Předpřipravené stavy

    static let noInternet = AppToastError(
        message:  "Žádné připojení k internetu — iKorba pracuje offline.",
        icon:     "wifi.slash",
        severity: .warning
    )
    static let apiTimeout = AppToastError(
        message:  "iKorba neodpovídá. Načítám záložní plán…",
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
    static let supabaseError = AppToastError(
        message:  "Cviky se nepodařilo načíst z databáze. Zkontroluj internet.",
        icon:     "exclamationmark.icloud.fill",
        severity: .error
    )
}
