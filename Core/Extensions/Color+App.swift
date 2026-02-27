// Color+App.swift
// Synchronizováno s AppColors z Theme.swift
import SwiftUI

extension Color {
    // MARK: - Pozadí
    static var appBackground: Color { AppColors.background }
    static var appSecondaryBackground: Color { AppColors.secondaryBg }
    static var appTertiaryBackground: Color { AppColors.tertiaryBg }
    static var appCardBackground: Color { AppColors.cardBg }
    static var appRowBackground: Color { AppColors.rowBg }
    static var appGlassBackground: Color { AppColors.glassBg }

    // MARK: - Akcenty
    static var appPrimaryAccent: Color { AppColors.primaryAccent }
    static var appSecondaryAccent: Color { AppColors.secondaryAccent }
    static var appAccentCyan: Color { AppColors.accentCyan }

    // MARK: - Statusy
    static var appGreenText: Color { AppColors.success }
    static var appGreenBadge: Color { AppColors.success }
    static var appRedText: Color { AppColors.error }

    // MARK: - RPE barvy
    static func rpeColor(for value: Int) -> Color {
        switch value {
        case 1...4: return AppColors.success
        case 5...6: return AppColors.warning
        case 7...8: return .orange
        default:    return AppColors.error
        }
    }
}
