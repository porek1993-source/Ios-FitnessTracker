// Exercise.swift

import SwiftData
import Foundation

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var slug: String
    var name: String
    var nameEN: String
    var category: ExerciseCategory
    var movementPattern: MovementPattern
    var equipment: [Equipment] = []
    var musclesTarget: [MuscleGroup] = []
    var musclesSecondary: [MuscleGroup] = []
    var isUnilateral: Bool = false
    var instructions: String = ""
    var videoURL: String?
    
    // Nový flag pro uživatelsky vytvořené cviky
    var isCustom: Bool = false

    @Relationship(deleteRule: .cascade)
    var weightHistory: [WeightEntry] = []

    @Relationship(deleteRule: .nullify)
    var plannedExercises: [PlannedExercise] = []

    @Relationship(deleteRule: .nullify)
    var sessionExercises: [SessionExercise] = []

    // MARK: - Legacy Helpers for Custom Builder
    
    var primaryMuscleGroup: MuscleGroup? {
        musclesTarget.first
    }
    
    var muscle_group: String {
        get { musclesTarget.first?.rawValue ?? "" }
        set { 
            if let group = MuscleGroup(rawValue: newValue) {
                if musclesTarget.isEmpty { musclesTarget = [group] }
                else { musclesTarget[0] = group }
            }
        }
    }

    // MARK: - Progressive Overload Memory

    var lastUsedWeight: Double? {
        weightHistory
            .sorted { $0.loggedAt > $1.loggedAt }
            .first?.weightKg
    }

    /// Epley formula: w * (1 + reps/30)
    var personalRecord1RM: Double? {
        weightHistory.compactMap { entry -> Double? in
            guard entry.reps > 0 else { return nil }
            return entry.weightKg * (1 + Double(entry.reps) / 30.0)
        }.max()
    }

    init(
        slug: String,
        name: String,
        nameEN: String,
        category: ExerciseCategory,
        movementPattern: MovementPattern,
        equipment: [Equipment] = [],
        musclesTarget: [MuscleGroup] = [],
        musclesSecondary: [MuscleGroup] = [],
        isUnilateral: Bool = false,
        instructions: String = ""
    ) {
        self.id = UUID()
        self.slug = slug
        self.name = name
        self.nameEN = nameEN
        self.category = category
        self.movementPattern = movementPattern
        self.equipment = equipment
        self.musclesTarget = musclesTarget
        self.musclesSecondary = musclesSecondary
        self.isUnilateral = isUnilateral
        self.instructions = instructions
        self.weightHistory = []
    }
}

enum Equipment: String, Codable, CaseIterable {
    case barbell        = "barbell"
    case dumbbell       = "dumbbell"
    case cable          = "cable"
    case machine        = "machine"
    case bodyweight     = "bodyweight"
    case resistanceBand = "resistanceBand"
    case kettlebell     = "kettlebell"
    case pullupBar      = "pullupBar"
    case band           = "band"
    case trx            = "trx"

    var emoji: String {
        switch self {
        case .barbell:        return "🏋️‍♂️"
        case .dumbbell:       return "💪"
        case .cable:          return "⚙️"
        case .machine:        return "🦾"
        case .bodyweight:     return "🤸"
        case .resistanceBand, .band: return "🎗️"
        case .kettlebell:     return "🔔"
        case .pullupBar, .trx: return "🧗"
        }
    }

    var localizedName: String {
        switch self {
        case .barbell:        return "Velká činka"
        case .dumbbell:       return "Jednoručky"
        case .cable:          return "Kladka"
        case .machine:        return "Stroj"
        case .bodyweight:     return "Vlastní váha"
        case .resistanceBand, .band: return "Odporová guma"
        case .kettlebell:     return "Kettlebell"
        case .pullupBar, .trx: return "Hrazda / TRX"
        }
    }
}

enum ExerciseCategory: String, Codable, CaseIterable {
    case chest      = "chest"
    case back       = "back"
    case legs       = "legs"
    case shoulders  = "shoulders"
    case arms       = "arms"
    case core       = "core"
    case cardio     = "cardio"
    case olympic    = "olympic"
    case strength   = "strength"
}

enum MovementPattern: String, Codable, CaseIterable {
    case push       = "push"
    case pull       = "pull"
    case hinge      = "hinge"
    case squat      = "squat"
    case carry      = "carry"
    case rotation   = "rotation"
    case isolation  = "isolation"
}

/// Kompletní enum 16 svalových skupin — rawValue přesně odpovídá Supabase klíčům.
/// lokalizace: .localizedName vrací česky pro UI, .displayName je alias.
enum MuscleGroup: String, Codable, CaseIterable {
    // ── Přední strana těla ───────────────────────────────────────────────
    case traps          = "traps"           // Trapézy (vrchol)
    case frontShoulders = "front-shoulders" // Přední ramena (deltoid ant.)
    case chest          = "chest"           // Hrudník (pectoralis major)
    case biceps         = "biceps"          // Biceps
    case forearms       = "forearms"        // Předloktí
    case obliques       = "obliques"        // Šikmé svaly břišní
    case abdominals     = "abdominals"      // Přímý sval břišní (rectus)
    case quads          = "quads"           // Přední stehna (quadriceps)
    case calves         = "calves"          // Lýtka (gastrocnemius)

    // ── Zadní strana těla ────────────────────────────────────────────────
    case rearShoulders  = "rear-shoulders"  // Zadní ramena (deltoid post.)
    case triceps        = "triceps"         // Triceps
    case lats           = "lats"            // Latissimus dorsi
    case trapsMiddle    = "traps-middle"    // Střední záda (rhomboid + mid-trap)
    case lowerback      = "lowerback"       // Spodní záda (erector spinae)
    case hamstrings     = "hamstrings"      // Zadní stehna
    case glutes         = "glutes"          // Hýždě (gluteus maximus)

    // MARK: - Lokalizace (CZ)
    var localizedName: String {
        switch self {
        case .traps:          return "Trapézy"
        case .frontShoulders: return "Přední ramena"
        case .chest:          return "Hrudník"
        case .biceps:         return "Biceps"
        case .forearms:       return "Předloktí"
        case .obliques:       return "Šikmé svaly břišní"
        case .abdominals:     return "Břicho"
        case .quads:          return "Přední stehna"
        case .calves:         return "Lýtka"
        case .rearShoulders:  return "Zadní ramena"
        case .triceps:        return "Triceps"
        case .lats:           return "Široký sval zádový"
        case .trapsMiddle:    return "Střední záda"
        case .lowerback:      return "Spodní záda"
        case .hamstrings:     return "Zadní stehna"
        case .glutes:         return "Hýždě"
        }
    }

    /// Alias pro zpětnou kompatibilitu s kódem volajícím .displayName
    var displayName: String { localizedName }

    // MARK: - Bezpečná inicializace z libovolného Supabase stringu
    /// Zkusí přesný rawValue match, pak fallback mapování pro starší aliasy.
    static func from(supabaseKey: String) -> MuscleGroup? {
        if let direct = MuscleGroup(rawValue: supabaseKey) { return direct }
        // Starší / alternativní klíče
        switch supabaseKey.lowercased() {
        case "pecs":                    return .chest
        case "delts", "shoulders":      return .frontShoulders
        case "abs", "core":             return .abdominals
        case "spinalerectors", "lower back", "lower_back": return .lowerback
        case "traps-middle", "middle back", "upper back":  return .trapsMiddle
        case "lats", "back":            return .lats
        default: return nil
        }
    }
}
