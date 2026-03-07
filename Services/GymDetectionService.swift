// GymDetectionService.swift
// Sleduje GPS polohu uživatele a automaticky přepíná aktivní GymProfile.
// Pokud se uživatel nachází v rámci definovaného radiusu fitka, nastavíme currentGym
// a WatchTrainerContextBuilder použije vybavení tohoto fitka.

import Foundation
import CoreLocation
import SwiftData
import SwiftUI

@MainActor
final class GymDetectionService: NSObject, ObservableObject, CLLocationManagerDelegate {

    static let shared = GymDetectionService()

    // MARK: - Published
    @Published var currentGym: GymProfile? = nil
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastUserLocation: CLLocation? = nil

    // MARK: - Private
    private let locationManager = CLLocationManager()
    private var gyms: [GymProfile] = []

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter  = 50   // Aktualizuj pouze při pohybu > 50m
        locationManager.allowsBackgroundLocationUpdates = true // Nutné pro detekci při vypnutém displeji
        locationManager.pausesLocationUpdatesAutomatically = false // Zabrání agresivnímu uspání
    }

    // MARK: - Veřejné API

    /// Načte fitka z databáze a spustí monitoring
    func start(gyms: [GymProfile]) {
        self.gyms = gyms
        authorizationStatus = locationManager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.lastUserLocation = loc
            self.detectGym(at: loc)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    // MARK: - Detekce fitka

    private func detectGym(at location: CLLocation) {
        let detected = gyms.first { $0.contains(location) }
        if detected?.id != currentGym?.id {
            currentGym = detected
            if let gym = detected {
                AppLogger.info("[GymDetection] Detekováno fitko: \(gym.name) — vybavení: \(gym.equipmentContext)")
                notifyGymChanged(gym)
            } else {
                AppLogger.info("[GymDetection] Opuštění fitka / žádné fitko v okolí.")
            }
        }
    }

    private func notifyGymChanged(_ gym: GymProfile) {
        NotificationCenter.default.post(
            name: .gymProfileChanged,
            object: nil,
            userInfo: ["gymName": gym.name, "equipment": gym.equipment]
        )
    }

    /// Textový kontext pro AI trenéra
    var aiEquipmentContext: String {
        if let gym = currentGym {
            return "AKTUÁLNÍ FITKO: \(gym.name)\nDOSTUPNÉ VYBAVENÍ: \(gym.equipmentContext)\n⚠️ Generuj trénink POUZE s tímto vybavením."
        }
        return ""
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let gymProfileChanged = Notification.Name("gymProfileChanged")
}
