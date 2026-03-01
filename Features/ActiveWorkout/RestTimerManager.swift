// RestTimerManager.swift
// Agilní Fitness Trenér — Lokální notifikace pro pauzy v aplikaci

import Foundation
import UserNotifications

final class RestTimerManager: NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = RestTimerManager()
    private let center = UNUserNotificationCenter.current()
    
    private let notificationIdentifier = "RestTimerNotification"
    
    // Ukládáme, jestli máme oprávnění, abychom se neptali zbytečně
    @Published var isAuthorized: Bool = false
    
    private override init() {
        super.init()
        center.delegate = self
        checkAuthorization()
    }
    
    func checkAuthorization() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
            }
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                completion(granted)
            }
        }
    }
    
    /// Naplánuje notifikaci za X sekund
    func startRestTimer(seconds: Int) {
        guard isAuthorized, seconds > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Pauza skončila!"
        content.body = "Čas na další sérii. Rozbij to! 💪"
        content.sound = .default
        
        // Budík za X sekund
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        
        // Zrušíme případnou předchozí (kdyby uživatel naplánoval novou před koncem staré)
        cancelTimer()
        
        center.add(request) { error in
            if let error = error {
                print("⚠️ RestTimerManager: Nelze naplánovat notifikaci (\(error.localizedDescription))")
            }
        }
    }
    
    /// Zruší aktuálně běžící odpočet notifikace, např. když uživatel pauzu přeskočí ručně dřív
    func cancelTimer() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
    }
    
    // Zajišťuje, že se notifikace ukáže, i když je aplikace v popředí (kdyby se tam uživatel zdržel, ale nezavřel timer u view)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound]) // Zobrazí banner a zahraje zvuk
    }
}
