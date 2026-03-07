import Foundation
import SwiftData

/// The phase of a Mesocycle
enum MesocyclePhase: String, Codable, CaseIterable {
    case foundation = "Foundation"
    case hypertrophy = "Hypertrophy"
    case strength = "Strength"
    case peaking = "Peaking"
    case deload = "Deload"

    var icon: String {
        switch self {
        case .foundation: return "🏗"
        case .hypertrophy: return "💪"
        case .strength: return "🏋️"
        case .peaking: return "🏆"
        case .deload: return "🔋"
        }
    }

    var description: String {
        switch self {
        case .foundation: return "Budování základů, technika"
        case .hypertrophy: return "Budování svalové hmoty"
        case .strength: return "Rozvoj maximální síly"
        case .peaking: return "Příprava na maximálky"
        case .deload: return "Regenerace a odpočinek"
        }
    }

    var accentColor: (r: Double, g: Double, b: Double) {
        switch self {
        case .foundation: return (0.6, 0.6, 0.6)
        case .hypertrophy: return (0.22, 0.55, 1.0)
        case .strength: return (1.0, 0.58, 0.0)
        case .peaking: return (1.0, 0.2, 0.2)
        case .deload: return (0.2, 0.8, 0.2)
        }
    }
}

// Typ pro simulaci "týdne" v modelu
struct MesocycleWeek: Codable {
    var phase: MesocyclePhase
}

@Model
final class Mesocycle: Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var goal: String = ""
    var totalWeeks: Int = 8
    var startDate: Date = Date()
    var isActive: Bool = false
    var phases: [MesocyclePhase] = []
    
    // Pro compatibility s případným uložením v DB (nepovinny list tydnu, pokud se neco chova custom)
    var weeksRaw: [MesocycleWeek] = []

    init(title: String = "", goal: String = "", totalWeeks: Int = 8, startDate: Date = Date(), phases: [MesocyclePhase] = [], isActive: Bool = false) {
        self.id = UUID()
        self.title = title
        self.goal = goal
        self.totalWeeks = totalWeeks
        self.startDate = startDate
        self.phases = phases
        self.isActive = isActive
    }

    // Computed properties expected by MesocyclePlannerView
    
    var endDate: Date {
        return Calendar.current.date(byAdding: .day, value: totalWeeks * 7, to: startDate) ?? startDate
    }

    var currentWeekIndex: Int {
        let weeksDiff = Calendar.current.dateComponents([.weekOfYear], from: startDate, to: Date.now).weekOfYear ?? 0
        return max(0, min(weeksDiff, totalWeeks - 1))
    }

    var progressFraction: Double {
        guard totalWeeks > 0 else { return 0 }
        let fraction = Double(currentWeekIndex) / Double(totalWeeks)
        return min(max(fraction, 0), 1)
    }

    var currentPhase: MesocyclePhase {
        if let week = weeks[safe: currentWeekIndex] {
            return week.phase
        }
        guard !phases.isEmpty else { return .foundation }
        let perPhase = max(1, totalWeeks / phases.count)
        let idx = min(currentWeekIndex / perPhase, phases.count - 1)
        return phases[idx]
    }

    var weeks: [MesocycleWeek] {
        if !weeksRaw.isEmpty { return weeksRaw }
        guard !phases.isEmpty else {
            return (0..<totalWeeks).map { _ in MesocycleWeek(phase: .foundation) }
        }
        let perPhase = max(1, totalWeeks / phases.count)
        return (0..<totalWeeks).map { i in
            let idx = min(i / perPhase, phases.count - 1)
            return MesocycleWeek(phase: phases[idx])
        }
    }
}


