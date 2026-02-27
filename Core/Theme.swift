// Theme.swift
// Centrální design systém aplikace AgileFitnessTrainer.
// Prémiový dark-mode design inspirovaný Apple Fitness+ / Whoop.

import SwiftUI

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Colors
// MARK: ═══════════════════════════════════════════════════════════════════════

enum AppColors {
    // Pozadí — hluboká břidlicová (ne čistě černá)
    static let background        = Color(red: 0.086, green: 0.102, blue: 0.133) // #161A22
    static let secondaryBg       = Color(red: 0.106, green: 0.122, blue: 0.157) // #1B1F28
    static let tertiaryBg        = Color(red: 0.137, green: 0.157, blue: 0.200) // #232833
    static let cardBg            = Color.white.opacity(0.05)
    static let rowBg             = Color.white.opacity(0.04)
    static let glassBg           = Color.white.opacity(0.06)

    // Akcenty — sjednocená vibrantně modrá
    static let primaryAccent     = Color(red: 0.22, green: 0.55, blue: 1.0)     // Vibrantně modrá
    static let secondaryAccent   = Color(red: 0.10, green: 0.38, blue: 0.90)
    static let accentCyan        = Color(red: 0.15, green: 0.82, blue: 0.88)    // Cyan glow
    static let accentGradient    = LinearGradient(
        colors: [primaryAccent, secondaryAccent],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let accentGlowGradient = LinearGradient(
        colors: [primaryAccent, accentCyan],
        startPoint: .leading, endPoint: .trailing
    )

    // Statusy
    static let success           = Color(red: 0.18, green: 0.82, blue: 0.48)
    static let warning           = Color(red: 1.0, green: 0.68, blue: 0.26)
    static let error             = Color(red: 0.95, green: 0.30, blue: 0.30)
    static let info              = Color(red: 0.30, green: 0.78, blue: 0.95)

    // Text
    static let textPrimary       = Color.white
    static let textSecondary     = Color.white.opacity(0.62)
    static let textTertiary      = Color.white.opacity(0.38)
    static let textMuted         = Color.white.opacity(0.22)

    // Okraje
    static let border            = Color.white.opacity(0.08)
    static let borderActive      = Color.white.opacity(0.18)
    static let borderAccent      = primaryAccent.opacity(0.25)
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

/// Prémiová glassmorphism karta
struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = AppRadius.card
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.lg)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppColors.glassBg)
                    // Subtilní horní odlesk
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
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

/// Trend indikátor (šipka nahoru/dolů s barvou)
struct TrendIndicator: View {
    let value: Double   // kladná = zlepšení, záporná = zhoršení
    let suffix: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text("\(String(format: "%.0f", abs(value)))\(suffix)")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(value >= 0 ? AppColors.success : AppColors.error)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill((value >= 0 ? AppColors.success : AppColors.error).opacity(0.15))
        )
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
    func glassCardStyle(cornerRadius: CGFloat = AppRadius.card) -> some View {
        modifier(GlassCardStyle(cornerRadius: cornerRadius))
    }
    func overlineStyle() -> some View { modifier(OverlineStyle()) }
}
