// Theme.swift
// Centrální design systém aplikace AgileFitnessTrainer.
// Sjednocuje barvy, typografii a spacing podle Apple HIG.

import SwiftUI

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Colors
// MARK: ═══════════════════════════════════════════════════════════════════════

enum AppColors {
    // Pozadí
    static let background        = Color(hue: 0.62, saturation: 0.18, brightness: 0.07)
    static let secondaryBg       = Color(hue: 0.62, saturation: 0.18, brightness: 0.09)
    static let tertiaryBg        = Color(hue: 0.62, saturation: 0.22, brightness: 0.15)
    static let cardBg            = Color.white.opacity(0.04)
    static let rowBg             = Color.white.opacity(0.05)

    // Akcenty
    static let primaryAccent     = Color(red: 0.20, green: 0.52, blue: 1.0)
    static let secondaryAccent   = Color(red: 0.08, green: 0.32, blue: 0.82)
    static let accentGradient    = LinearGradient(
        colors: [primaryAccent, secondaryAccent],
        startPoint: .leading, endPoint: .trailing
    )

    // Statusy
    static let success           = Color(red: 0.13, green: 0.80, blue: 0.43)
    static let warning           = Color.orange
    static let error             = Color(red: 0.95, green: 0.30, blue: 0.30)
    static let info              = Color.cyan

    // Text
    static let textPrimary       = Color.white
    static let textSecondary     = Color.white.opacity(0.6)
    static let textTertiary      = Color.white.opacity(0.35)
    static let textMuted         = Color.white.opacity(0.22)

    // Okraje
    static let border            = Color.white.opacity(0.07)
    static let borderActive      = Color.white.opacity(0.15)
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Typography
// MARK: ═══════════════════════════════════════════════════════════════════════

enum AppTypography {
    static let largeTitle  = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title       = Font.system(size: 20, weight: .bold, design: .rounded)
    static let headline    = Font.system(size: 17, weight: .semibold)
    static let body        = Font.system(size: 15, weight: .regular)
    static let callout     = Font.system(size: 14, weight: .medium)
    static let footnote    = Font.system(size: 13, weight: .regular)
    static let caption     = Font.system(size: 11, weight: .medium)
    static let overline    = Font.system(size: 9, weight: .black)

    // Monospaced číselníky (skóre, časomíry)
    static let scoreDisplay = Font.system(size: 58, weight: .black, design: .monospaced)
    static let scoreMedium  = Font.system(size: 24, weight: .black, design: .rounded)
    static let scoreSmall   = Font.system(size: 17, weight: .bold, design: .monospaced)
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Spacing
// MARK: ═══════════════════════════════════════════════════════════════════════

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 20
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Corner Radius
// MARK: ═══════════════════════════════════════════════════════════════════════

enum AppRadius {
    static let small:  CGFloat = 8
    static let medium: CGFloat = 12
    static let large:  CGFloat = 16
    static let card:   CGFloat = 20
    static let sheet:  CGFloat = 24
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Animations
// MARK: ═══════════════════════════════════════════════════════════════════════

enum AppAnimation {
    static let standard   = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let quick      = Animation.spring(response: 0.25, dampingFraction: 0.85)
    static let slow       = Animation.spring(response: 0.55, dampingFraction: 0.75)
    static let bounce     = Animation.spring(response: 0.35, dampingFraction: 0.65)
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Reusable View Modifiers
// MARK: ═══════════════════════════════════════════════════════════════════════

/// Standardní karta
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(AppColors.cardBg)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1))
            )
    }
}

/// Standardní overline nápis (VŠECHNO CAPS)
struct OverlineStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTypography.overline)
            .foregroundStyle(AppColors.textTertiary)
            .kerning(1.5)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
    func overlineStyle() -> some View { modifier(OverlineStyle()) }
}
