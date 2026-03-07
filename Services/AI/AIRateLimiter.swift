// AIRateLimiter.swift
// Denní limit pro volání Gemini API s Free/Premium tieringem.
// Free: 3 volání/den | Premium: 50 volání/den
// Reset automaticky o půlnoci. Úložiště: UserDefaults (thread-safe).

import Foundation

enum AIUserTier: String {
    case free    = "free"
    case premium = "premium"
}

enum AIRateLimiter {

    // MARK: - Konfigurace

    static let freeDailyLimit:    Int = 3
    static let premiumDailyLimit: Int = 50

    // Odhad průměrné ceny jednoho volání v centách (gemini-2.5-flash)
    private static let estimatedCostCentsPerCall: Double = 0.08

    // MARK: - UserDefaults klíče

    private static let callsKey    = "ai_rate_calls_today"
    private static let dateKey     = "ai_rate_reset_date"
    private static let tierKey     = "ai_user_tier"

    // MARK: - Veřejné API

    static var tier: AIUserTier {
        get { AIUserTier(rawValue: UserDefaults.standard.string(forKey: tierKey) ?? "free") ?? .free }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: tierKey) }
    }

    static var dailyLimit: Int {
        tier == .premium ? premiumDailyLimit : freeDailyLimit
    }

    /// Vrací true pokud lze provést další AI volání.
    /// Automaticky resetuje čítač pokud nastal nový den.
    static func canMakeCall() -> Bool {
        resetIfNewDay()
        let count = UserDefaults.standard.integer(forKey: callsKey)
        return count < dailyLimit
    }

    /// Zaznamená jedno AI volání. Vždy voláme po úspěšném odeslání requestu.
    static func recordCall() {
        resetIfNewDay()
        let count = UserDefaults.standard.integer(forKey: callsKey)
        UserDefaults.standard.set(count + 1, forKey: callsKey)
        AppLogger.info("📊 [AIRateLimiter] Volání dnes: \(count + 1)/\(dailyLimit) (\(tier.rawValue))")
    }

    /// Vrátí počet zbývajících AI volání pro dnešní den.
    static func remainingCalls() -> Int {
        resetIfNewDay()
        let used = UserDefaults.standard.integer(forKey: callsKey)
        return max(0, dailyLimit - used)
    }

    /// Vrátí počet použitých AI volání pro dnešní den.
    static func usedCalls() -> Int {
        resetIfNewDay()
        return UserDefaults.standard.integer(forKey: callsKey)
    }

    /// Odhadované náklady dneška v centách.
    static func estimatedDailyCostCents() -> Double {
        Double(usedCalls()) * estimatedCostCentsPerCall
    }

    /// UI-přívětivý string nákladů (např. "0.24¢")
    static func dailyCostDisplay() -> String {
        String(format: "%.2f¢", estimatedDailyCostCents())
    }

    // MARK: - Privátní logika resetu

    private static func resetIfNewDay() {
        let defaults = UserDefaults.standard
        if let lastDate = defaults.object(forKey: dateKey) as? Date {
            if !Calendar.current.isDate(lastDate, inSameDayAs: .now) {
                defaults.set(0, forKey: callsKey)
                defaults.set(Date.now, forKey: dateKey)
                AppLogger.info("🔄 [AIRateLimiter] Denní čítač resetován (nový den).")
            }
        } else {
            defaults.set(0, forKey: callsKey)
            defaults.set(Date.now, forKey: dateKey)
        }
    }
}
