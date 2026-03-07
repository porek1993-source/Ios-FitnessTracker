// GymProfile.swift
// SwiftData model pro fitko s GPS lokací, názvem a vybavením.
// Využíváno GymDetectionService, který na základě polohy přepíná aktivní profil vybavení.

import SwiftData
import Foundation
import CoreLocation

@Model
final class GymProfile {

    @Attribute(.unique) var id: UUID
    var name:          String
    var latitude:      Double
    var longitude:     Double
    var radiusMeters:  Double           // Oblast detekce [m] — default 150m
    var equipment:     [String]         // Serialized [Equipment.rawValue]
    var isDefault:     Bool             // Primární "domácí" fitko
    var createdAt:     Date

    init(
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 150,
        equipment: [String] = [],
        isDefault: Bool = false
    ) {
        self.id           = UUID()
        self.name         = name
        self.latitude     = latitude
        self.longitude    = longitude
        self.radiusMeters = radiusMeters
        self.equipment    = equipment
        self.isDefault    = isDefault
        self.createdAt    = .now
    }

    /// CLLocation pro porovnání vzdálenosti
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Vrací true pokud je daná lokace v rámci definovaného radiusu
    func contains(_ userLocation: CLLocation) -> Bool {
        let distance = location.distance(from: userLocation)
        return distance <= radiusMeters
    }

    /// Textový výpis vybavení pro AI kontext
    var equipmentContext: String {
        equipment.isEmpty ? "Neznámé vybavení" : equipment.joined(separator: ", ")
    }
}
