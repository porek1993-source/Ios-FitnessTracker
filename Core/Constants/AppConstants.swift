// AppConstants.swift

import Foundation

enum AppConstants {
    // TODO: Replace with your actual Gemini API key
    static let geminiAPIKey: String = {
        guard let key = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String, !key.isEmpty else {
            return "YOUR_GEMINI_API_KEY_HERE"
        }
        return key
    }()

    static let fallbackSystemPrompt = "Jsi fitness trenér Jakub. Odpovídej vždy validním JSON."

    // MARK: - Supabase
    // TODO: Replace with your actual Supabase project URL and anon key
    static let supabaseURL: String = {
        guard let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String, !url.isEmpty else {
            return "https://YOUR_PROJECT.supabase.co"
        }
        return url
    }()

    static let supabaseAnonKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String, !key.isEmpty else {
            return "YOUR_SUPABASE_ANON_KEY_HERE"
        }
        return key
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

    var errorDescription: String? {
        switch self {
        case .noPlanForToday:       return "Pro dnešní den není naplánován trénink."
        case .encodingFailed:       return "Chyba při přípravě dat pro AI."
        case .healthKitUnavailable: return "HealthKit není dostupný na tomto zařízení."
        case .noActiveProfile:      return "Nenalezen aktivní uživatelský profil."
        }
    }
}
