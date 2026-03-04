// HealthBackgroundManager.swift

import Foundation
import BackgroundTasks
import HealthKit
import SwiftData

@MainActor
final class HealthBackgroundManager {
    static let shared = HealthBackgroundManager()
    
    // Identifikátor úlohy musí odpovídat Info.plist (Permitted background task scheduler identifiers)
    static let healthSyncTaskIdentifier = "com.agilefitness.healthSync"

    // ✅ OPRAVA: Lazy init — instance HealthKitService se vytvoří jen pokud nebyla injektována
    // z AppEnvironment. Normálně se vždy volá configure(healthKit:) z AppEnvironment.init()
    // ještě před jakýmkoliv použitím, takže skutečná lazy instance nikdy nevznikne.
    private var _healthKitService: HealthKitService?
    private var healthKitService: HealthKitService {
        if let svc = _healthKitService { return svc }
        AppLogger.warning("[HealthBackgroundManager] healthKitService použito bez configure() — vytváří se nová instance. Volej configure(healthKit:) z AppEnvironment.init().")
        let svc = HealthKitService()
        _healthKitService = svc
        return svc
    }

    /// Nastaví sdílenou HealthKitService instanci (volej z AppEnvironment.init()).
    func configure(healthKit: HealthKitService) {
        self._healthKitService = healthKit
    }
    
    /// Zamezuje spuštění více sync operací současně.
    private var isSyncing = false
    
    /// Flag pro zabránění duplicitní registrace BGTask (opravuje crash)
    private var hasRegisteredTasks = false
    
    private init() {}
    
    // MARK: - Foreground Sync (volej při otevření aplikace)
    
    /// Stáhne aktuální HealthKit data a uloží je do SwiftData.
    /// Bezpečné pro opakované volání — chrání proti race conditions.
    /// `healthKit` parametr je zachován pro zpětnou kompatibilitu s AppEnvironment;
    /// interně se vždy používá nakonfigurovaná sdílená instance.
    func performForegroundSync(healthKit: HealthKitService? = nil) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        
        // Preferuj předanou instanci (zpětná kompatibilita), jinak nakonfigurovanou shared
        let service = healthKit ?? self.healthKitService
        
        do {
            if !service.isAuthorized {
                try await service.requestAuthorization()
            }
            let today = Date()
            let summary = try await service.fetchDailySummary(for: today)
            let externalActivities = try await service.fetchExternalActivities(since: today.startOfDay)
            saveToSwiftData(summary: summary, externalActivities: externalActivities, date: today)
            AppLogger.info("[HealthSync] Foreground sync úspěšný.")
        } catch {
            AppLogger.error("[HealthSync] Foreground sync selhal: \(error.localizedDescription)")
        }
    }
    
    /// Zaregistruje background task. Musí být voláno hned po spuštění aplikace.
    func registerBackgroundTasks() {
        guard !hasRegisteredTasks else {
            AppLogger.info("[HealthSync] BGTasks již zaregistrovány, přeskakuji.")
            return
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.healthSyncTaskIdentifier, using: nil) { [weak self] task in
            guard let bgTask = task as? BGAppRefreshTask else { return }
            // ✅ FIX #20: BGTaskScheduler handler běží na libovolném vlákně.
            // Přesuneme zpracování na MainActor, ale MUSÍME nastavit expirationHandler
            // PŘED async hopem, protože systém ho může zavolat kdykoliv (i okamžitě).
            // Nastavíme ho synchronně ještě před Task { @MainActor }.
            nonisolated(unsafe) var taskRef: Task<Void, Never>? = nil
            bgTask.expirationHandler = {
                AppLogger.warning("[HealthSync] Task vypršel (čas vyhrazený systémem došel).")
                taskRef?.cancel()
                bgTask.setTaskCompleted(success: false)
            }
            taskRef = Task { @MainActor in
                self?.handleHealthSync(task: bgTask)
            }
        }
        
        hasRegisteredTasks = true
    }
    
    /// Naplánuje další spuštění. Ideálně chceme úkol nad ránem (např. 4:00 AM).
    func scheduleNextSync() {
        let request = BGAppRefreshTaskRequest(identifier: Self.healthSyncTaskIdentifier)
        
        // Nastavíme spuštění nejdříve na zítra ve 4:00 ráno
        if let tomorrow = Calendar.mondayStart.date(byAdding: .day, value: 1, to: Date()),
           let next4AM = Calendar.mondayStart.date(bySettingHour: 4, minute: 0, second: 0, of: tomorrow) {
            request.earliestBeginDate = next4AM
        } else {
            // Fallback na 8 hodin od teď
            request.earliestBeginDate = Date(timeIntervalSinceNow: 8 * 3600)
        }
        
        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.info("[\(Self.healthSyncTaskIdentifier)] Úspěšně naplánováno na \(request.earliestBeginDate?.description ?? "neznámo").")
        } catch {
            AppLogger.error("[HealthSync] Nelze naplánovat background task: \(error.localizedDescription)")
        }
    }
    
    /// Vykoná samotnou logiku updatu
    private func handleHealthSync(task: BGAppRefreshTask) {
        // Hned naplánujeme další (systém vyžaduje, abychom naplánovali vždy dopředu)
        scheduleNextSync()
        
        // ✅ FIX #20: expirationHandler je nastaven v registerBackgroundTasks() PŘED
        // async hopem na MainActor, protože systém ho může zavolat kdykoliv.
        // Duplicitní nastavení zde bylo odstraněno — přepisovalo by handler z registrace.
        Task {
            do {
                AppLogger.info("[HealthSync] Začínám background sync Health dat...")
                
                // 1. Zkontrolujeme oprávnění (na pozadí se nové dialogy neukážou, ale data přečteme pokud už práva máme)
                if !healthKitService.isAuthorized {
                    try await healthKitService.requestAuthorization()
                }
                
                // 2. Stáhneme data za dnešek (od půlnoci), tj. včerejší spánek a dnešní ranní HRV
                let today = Date()
                let summary = try await healthKitService.fetchDailySummary(for: today)
                let externalActivities = try await healthKitService.fetchExternalActivities(since: today.startOfDay)
                
                // 3. Uložíme do SwiftData
                saveToSwiftData(summary: summary, externalActivities: externalActivities, date: today)
                
                AppLogger.info("[HealthSync] Sync dokončen úspěšně.")
                task.setTaskCompleted(success: true)
                
            } catch {
                AppLogger.error("[HealthSync] Sync selhal: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    @MainActor
    private func saveToSwiftData(summary: HKDailySummary, externalActivities: [HKWorkoutSummary], date: Date) {
        let container = SharedModelContainer.container
        let context = container.mainContext // Používáme mainContext, protože je to singleton kontejner
        
        // Získáme uživatele
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? context.fetch(descriptor).first else {
            AppLogger.warning("[HealthSync] Nenalezen žádný UserProfile. Nemohu uložit zdravotní data.")
            return
        }
        
        // Vytvoříme nový snapshot
        let snapshot = HealthMetricsSnapshot(date: date)
        
        snapshot.sleepDurationHours = summary.sleepDurationHours
        snapshot.sleepEfficiencyPct = summary.sleepEfficiencyPct
        snapshot.sleepDeepHours = summary.sleepDeepHours
        snapshot.sleepREMHours = summary.sleepREMHours
        
        snapshot.heartRateVariabilityMs = summary.hrv
        snapshot.restingHeartRate = summary.restingHeartRate
        snapshot.avgRespiratoryRate = summary.respiratoryRate
        snapshot.activeCaloriesKcal = summary.activeCaloriesKcal
        snapshot.totalSteps = summary.totalSteps
        
        // Prevod external activities
        snapshot.externalActivities = externalActivities.map {
            ExternalActivity(
                type: $0.activityTypeName,
                durationMinutes: $0.durationMinutes,
                energyKcal: $0.totalEnergyKcal,
                startedAt: $0.startDate
            )
        }
        
        // Získáme baseline z předchozích (jen hrubý průměr pro ukázku)
        let pastSnapshots = profile.healthMetricsHistory.sorted(by: { $0.date > $1.date })
        if let last = pastSnapshots.first {
            snapshot.hrvBaselineAvg = last.hrvBaselineAvg ?? last.heartRateVariabilityMs
            snapshot.restingHRBaseline = last.restingHRBaseline ?? last.restingHeartRate
        } else {
            // První spuštění: baseline je aktuální hodnota
            snapshot.hrvBaselineAvg = summary.hrv
            snapshot.restingHRBaseline = summary.restingHeartRate
        }
        
        // Spočítáme skóre
        if let readiness = ReadinessCalculator.compute(snapshot: snapshot) {
            snapshot.readinessScore = readiness.score
        }
        
        // Navážeme a uložíme (vyhneme se zbytečným duplicitám ve stejný den)
        // (V produkci by bylo lepší napřed hledat snapshot s dnešním datem a updatovat ho, než vždy tvořit nový)
        
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay
        let existingIndex = profile.healthMetricsHistory.firstIndex {
            $0.date >= startOfDay && $0.date <= endOfDay
        }
        
        if let idx = existingIndex {
            // Nahradíme dnešní
            context.delete(profile.healthMetricsHistory[idx])
            profile.healthMetricsHistory.remove(at: idx)
        }
        
        profile.healthMetricsHistory.append(snapshot)
        
        do {
            try context.save()
            AppLogger.info("[HealthSync] Uloženo: \(summary.sleepDurationHours ?? 0) h spánku, HRV: \(summary.hrv ?? 0)")
            
            // Kontrola trendu přetrénování (deload detekce)
            checkDeloadTrend(profile: profile)
        } catch {
            AppLogger.error("[HealthSync] Chyba při ukládání do SwiftData: \(error)")
        }
    }
    
    // MARK: - Deload Detection
    
    /// Analyzuje posledních 7 dnů HRV a RHR. Pokud HRV klesá 5+ dní nebo RHR roste,
    /// navrhneme uživateli deload týden přes notifikaci.
    private func checkDeloadTrend(profile: UserProfile) {
        let recent = profile.healthMetricsHistory
            .sorted { $0.date > $1.date }
            .prefix(7)
        
        guard recent.count >= 5 else { return }
        
        let hrvValues = recent.compactMap { $0.heartRateVariabilityMs }
        let rhrValues = recent.compactMap { $0.restingHeartRate }
        
        guard hrvValues.count >= 4, rhrValues.count >= 4 else { return }
        
        // Kontroluj klesající HRV trend (každý den nižší než předchozí)
        var hrvDeclining = true
        for i in 0..<(hrvValues.count - 1) {
            if hrvValues[i] >= hrvValues[i + 1] {
                hrvDeclining = false; break
            }
        }
        
        // Kontroluj rostoucí RHR trend
        var rhrRising = true
        for i in 0..<(rhrValues.count - 1) {
            if rhrValues[i] <= rhrValues[i + 1] {
                rhrRising = false; break
            }
        }
        
        if hrvDeclining || rhrRising {
            profile.isDeloadRecommended = true
            NotificationService.shared.scheduleDeloadReminder()
        } else {
            profile.isDeloadRecommended = false
        }
    }
}
