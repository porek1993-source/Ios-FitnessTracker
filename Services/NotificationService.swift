// NotificationService.swift
// Naplánování push notifikací pro tréninky a týdenní report

import UserNotifications
import SwiftData
import Foundation

@MainActor
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    // MARK: — Permission

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            AppLogger.error("NotificationService: Chyba při žádosti o oprávnění: \(error)")
            return false
        }
    }

    // MARK: — Workout Reminder

    /// Naplánuje denní připomínku tréninku na zadaný čas
    func scheduleWorkoutReminder(hour: Int = 8, minute: Int = 30) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["workout_daily_reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Čas na trénink! 💪"
        content.body = "Trenér iKorba na tebe čeká. Podívej se na dnešní plán."
        content.sound = .default
        // ✅ FIX #17: Odstraněno content.badge = 1 — badge se nikde nevynuloval,
        // takže zůstal trvale na ikoně. Opakující se připomínky nemají badge nastavovat.
        // Místo toho je clearBadge() voláno při otevření aplikace (viz AgileFitnessTrainerApp.swift).

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "workout_daily_reminder",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                AppLogger.error("NotificationService: Chyba při plánování notifikace: \(error)")
            } else {
                AppLogger.info("NotificationService: Denní připomínka naplánována na \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    /// ✅ FIX #17: Vymaže badge aplikace. Volej při každém spuštění do popředí.
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }

    /// Naplánuje notifikaci po vynechání tréninku (24h po původně plánovaném čase)
    func scheduleMissedWorkoutNudge(afterDate: Date) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Vynechal jsi trénink 😕"
        content.body = "Nevadí! Trenér iKorba ti naplánoval náhradní trénink. Zkus to dnes?"
        content.sound = .default

        let triggerDate = afterDate.addingTimeInterval(24 * 3600)
        let components = Calendar.mondayStart.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let id = "missed_workout_\(Int(afterDate.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        // ✅ FIX #10: Prevence duplicitních notifikací pro stejný identifikátor
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(request)
    }

    /// Notifikace po dosažení PR (osobního rekordu)
    func sendPersonalRecordNotification(exerciseName: String, weight: Double) {
        let content = UNMutableNotificationContent()
        content.title = "🏆 Nový osobní rekord!"
        content.body = "\(exerciseName): \(String(format: "%.1f", weight)) kg. Skvělá práce!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let id = "pr_\(exerciseName)_\(Int(Date.now.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    /// Notifikace pro deload týden
    func scheduleDeloadReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Čas na deload 🔄"
        content.body = "Tvoje data ukazují příznaky přetrénování. Tento týden si dej lehčí tréninky."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "deload_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: — Cancel All

    func cancelAllWorkoutReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["workout_daily_reminder"]
        )
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: — WeeklyReportService extension (scheduleWeeklyNotificationIfNeeded)
// Přesun do NotificationService namísto WeeklyReportService

extension WeeklyReportService {
    static func scheduleWeeklyNotificationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let alreadyScheduled = requests.contains { $0.identifier == "weekly_report" }
            guard !alreadyScheduled else { return }

            let content = UNMutableNotificationContent()
            content.title = "📊 Týdenní report je připraven"
            content.body = "Trenér iKorba zhodnotil tvůj týden. Podívej se, jak ses zlepšil!"
            content.sound = .default

            var components = DateComponents()
            // ✅ FIX #2: UNCalendarNotificationTrigger VŽDY používá kalendář, kde 1 = Neděle, 2 = Pondělí.
            // Pokud chceme, aby po "pondělí-neděle" týdnu přišel report v neděli v 18:00,
            // musíme použít weekday = 1, nehledě na lokální nastavení.
            components.weekday = 1  // Neděle
            components.hour = 18
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "weekly_report", content: content, trigger: trigger)
            center.add(request)
        }
    }
}
