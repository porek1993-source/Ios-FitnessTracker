// AppConstants.swift

import Foundation

enum AppConstants {
    /// Gemini API klíč - načítá se z Environment Variables nebo xcconfig.
    /// Nastavení: Xcode → Scheme → Edit Scheme → Run → Environment Variables → GEMINI_API_KEY
    static let geminiAPIKey: String = {
        if let key = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String,
           !key.isEmpty,
           key != "$(GEMINI_API_KEY)" {
            return key
        }
        // Fallback na process environment (pro lokální vývoj / CI)
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"],
           !key.isEmpty {
            return key
        }
        print("⚠️ GEMINI_API_KEY není nastaven! Pokud běží testy, je to v pořádku, jinak přidej klíč do env vars.")
        return ""
    }()

    static let fallbackSystemPrompt = "Jsi iKorba, elitní fitness trenér. Odpovídej vždy validním JSON."

    // MARK: - Supabase
    /// Supabase URL - načítá se z Info.plist nebo Environment Variables.
    static let supabaseURL: String = {
        if let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
           !url.isEmpty,
           url != "$(SUPABASE_URL)" {
            return url
        }
        if let url = ProcessInfo.processInfo.environment["SUPABASE_URL"],
           !url.isEmpty {
            return url
        }
        return ""
    }()

    static let supabaseAnonKey: String = {
        if let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
           !key.isEmpty,
           key != "$(SUPABASE_ANON_KEY)" {
            return key
        }
        if let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"],
           !key.isEmpty {
            return key
        }
        return ""
    }()

    // MARK: - Progressive Overload
    static let progressiveOverloadUpperBodyIncrement: Double = 2.5
    static let progressiveOverloadLowerBodyIncrement: Double = 5.0
    static let progressiveOverloadDeloadPercent: Double = 0.95
    static let progressiveOverloadLookbackSessions: Int = 3
}

enum AppError: Error, LocalizedError {
    case noPlanForToday
    case encodingFailed
    case healthKitUnavailable
    case noActiveProfile
    case networkUnavailable
    case internalError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .noPlanForToday:       return "Pro dnešní den není naplánován trénink."
        case .encodingFailed:       return "Chyba při přípravě dat pro AI."
        case .healthKitUnavailable: return "HealthKit není dostupný na tomto zařízení."
        case .noActiveProfile:      return "Nenalezen aktivní uživatelský profil."
        case .networkUnavailable:   return "Síť není dostupná."
        case .internalError(let msg): return "Interní chyba: \(msg)"
        case .unknown:              return "Neznámá chyba."
        }
    }
}
