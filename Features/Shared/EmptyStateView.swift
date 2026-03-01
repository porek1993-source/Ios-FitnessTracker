// EmptyStateView.swift
// Agilní Fitness Trenér — Univerzální prémiový prázdný stav (v2.1)
//
// OPRAVY v2.1:
//  ✅ Odstraněna globální funkce previewCard() — nahrazena privátní extension
//  ✅ Přidány nové prázdné stavy: noWorkout, noProfile, supabaseError
//  ✅ Action handler nemá retain cycle (slabá reference není potřeba — struct)
//  ✅ Přidán přístupový modifier .accessibilityLabel pro VoiceOver
//  ✅ Animace optimalizována (jeden stav, dvě fáze)
//  ✅ Plně česky

import SwiftUI

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: EmptyStateView — universální komponenta
// MARK: ═══════════════════════════════════════════════════════════════════════

struct EmptyStateView: View {

    // MARK: Povinné parametry
    let icon:    String     // SF Symbol name (např. "moon.stars.fill")
    let title:   String
    let message: String

    // MARK: Volitelné parametry
    var iconColor:   Color        = .blue
    var actionLabel: String?      = nil
    var action:      (() -> Void)? = nil

    // MARK: Vnitřní stav animace
    @State private var appeared  = false
    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 0) {

            Spacer(minLength: 28)

            // ── Animovaná ikona s glow halo ───────────────────────────────────
            iconSection
                .scaleEffect(appeared ? 1.0 : 0.60)
                .opacity(appeared ? 1.0 : 0.0)
                .accessibilityLabel(title)

            Spacer(minLength: 22)

            // ── Text ──────────────────────────────────────────────────────────
            textSection
                .offset(y: appeared ? 0 : 10)
                .opacity(appeared ? 1.0 : 0.0)

            Spacer(minLength: 22)

            // ── Volitelné akční tlačítko ──────────────────────────────────────
            if let label = actionLabel, let handler = action {
                ctaButton(label: label, handler: handler)
                    .offset(y: appeared ? 0 : 8)
                    .opacity(appeared ? 1.0 : 0.0)
            }

            Spacer(minLength: 28)
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.70).delay(0.05)) {
                appeared = true
            }
            // Glow puls — spouštíme s mírným zpožděním
            withAnimation(
                .easeInOut(duration: 2.4)
                .repeatForever(autoreverses: true)
                .delay(0.35)
            ) {
                glowPulse = true
            }
        }
    }

    // MARK: Subviews

    private var iconSection: some View {
        ZStack {
            // Vnější pulsující halo
            Circle()
                .fill(iconColor.opacity(0.07))
                .frame(width: 92, height: 92)
                .blur(radius: glowPulse ? 16 : 9)
                .scaleEffect(glowPulse ? 1.20 : 0.88)

            // Vnitřní kruh s ikonou
            Circle()
                .fill(iconColor.opacity(0.10))
                .frame(width: 66, height: 66)
                .overlay(
                    Circle()
                        .stroke(iconColor.opacity(0.20), lineWidth: 1)
                )

            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [iconColor.opacity(0.90), iconColor.opacity(0.60)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var textSection: some View {
        VStack(spacing: 9) {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
        }
    }

    private func ctaButton(label: String, handler: @escaping () -> Void) -> some View {
        Button(action: handler) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .padding(.horizontal, 24)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(iconColor.opacity(0.11))
                        .overlay(
                            Capsule()
                                .stroke(iconColor.opacity(0.28), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Tovární metody — předpřipravené stavy
// MARK: ═══════════════════════════════════════════════════════════════════════

extension EmptyStateView {

    // ── Spánek ────────────────────────────────────────────────────────────────
    /// Použij v `RecoveryInsightsView` pokud chybí data ze spánkového trackingu.
    static func sleep(onEnable: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon:        "moon.stars.fill",
            title:       "Spánková data nejsou k dispozici",
            message:     "Spi s Apple Watch nasazenými na zápěstí a iKorba bude moct přesněji dávkovat tvoji zátěž.",
            iconColor:   Color(red: 0.42, green: 0.30, blue: 0.92),
            actionLabel: onEnable != nil ? "Propojit Apple Health" : nil,
            action:      onEnable
        )
    }

    // ── HRV ───────────────────────────────────────────────────────────────────
    static func hrv() -> EmptyStateView {
        EmptyStateView(
            icon:      "waveform.path.ecg",
            title:     "HRV data chybí",
            message:   "Variabilita srdečního tepu se načítá z Apple Watch. Nos je přes noc a data se začnou zobrazovat.",
            iconColor: Color(red: 0.18, green: 0.76, blue: 0.56)
        )
    }

    // ── Tréninkový objem ───────────────────────────────────────────────────────
    static func volumeChart() -> EmptyStateView {
        EmptyStateView(
            icon:      "chart.bar.fill",
            title:     "Zatím žádný tréninkový objem",
            message:   "Dokončit první trénink a iKorba začne sledovat tvůj týdenní objem a progres.",
            iconColor: Color(red: 0.25, green: 0.55, blue: 1.0)
        )
    }

    // ── 1RM odhad ─────────────────────────────────────────────────────────────
    static func oneRepMax() -> EmptyStateView {
        EmptyStateView(
            icon:      "trophy.fill",
            title:     "Osobní rekordy se teprve plní",
            message:   "Po prvním tréninku iKorba automaticky odhadne tvoje 1RM a nastaví optimální váhy.",
            iconColor: Color(red: 1.0, green: 0.76, blue: 0.20)
        )
    }

    // ── Konzistence ───────────────────────────────────────────────────────────
    static func consistency() -> EmptyStateView {
        EmptyStateView(
            icon:      "flame.fill",
            title:     "Série teprve začíná",
            message:   "Dokončit alespoň jeden trénink a iKorba začne sledovat tvoji týdenní konzistenci.",
            iconColor: Color(red: 1.0, green: 0.44, blue: 0.20)
        )
    }

    // ── Historie tréninků ──────────────────────────────────────────────────────
    static func workoutHistory() -> EmptyStateView {
        EmptyStateView(
            icon:      "clock.arrow.circlepath",
            title:     "Žádná tréninková historie",
            message:   "Tvoje hotové tréninky se zobrazí tady. Zahaj první session a začni psát svůj příběh.",
            iconColor: Color.white.opacity(0.55)
        )
    }

    // ── Klidový tep (nové) ────────────────────────────────────────────────────
    static func restingHeartRate() -> EmptyStateView {
        EmptyStateView(
            icon:      "heart.slash.fill",
            title:     "Žádná data o klidovém tepu",
            message:   "Klidový tep ukazuje kardiovaskulární zdatnost. Apple Watch ho měří automaticky.",
            iconColor: Color(red: 0.92, green: 0.35, blue: 0.52)
        )
    }

    // ── Trénink nenalezen (nové) ───────────────────────────────────────────────
    static func noWorkout(onGenerate: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon:        "figure.strengthtraining.traditional",
            title:       "Trénink na dnes není připraven",
            message:     "iKorba ještě nevygeneroval dnešní plán. Klepni na tlačítko a spusť generování.",
            iconColor:   Color(red: 0.25, green: 0.70, blue: 1.0),
            actionLabel: onGenerate != nil ? "Vygenerovat trénink" : nil,
            action:      onGenerate
        )
    }

    // ── Chyba Supabase (nové) ─────────────────────────────────────────────────
    static func supabaseError(onRetry: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon:        "exclamationmark.icloud.fill",
            title:       "Databáze cviků nedostupná",
            message:     "Nepodařilo se načíst cviky z databáze. Zkontroluj připojení k internetu.",
            iconColor:   Color(red: 1.0, green: 0.35, blue: 0.25),
            actionLabel: onRetry != nil ? "Zkusit znovu" : nil,
            action:      onRetry
        )
    }

    // ── Profil nenalezen ──────────────────────────────────────────────────────
    static func noProfile() -> EmptyStateView {
        EmptyStateView(
            icon:      "person.crop.circle.badge.questionmark",
            title:     "Profil nenalezen",
            message:   "Zdá se, že tvůj profil byl smazán. Restartuj aplikaci a projdi onboarding znovu.",
            iconColor: Color(red: 0.80, green: 0.75, blue: 1.0)
        )
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Preview
// MARK: ═══════════════════════════════════════════════════════════════════════

#Preview("Prázdné stavy — galerie") {
    ZStack {
        Color(hue: 0.62, saturation: 0.20, brightness: 0.07).ignoresSafeArea()
        ScrollView {
            LazyVStack(spacing: 16) {
                EmptyStatePreviewCard { EmptyStateView.sleep() }
                EmptyStatePreviewCard { EmptyStateView.hrv() }
                EmptyStatePreviewCard { EmptyStateView.volumeChart() }
                EmptyStatePreviewCard { EmptyStateView.oneRepMax() }
                EmptyStatePreviewCard { EmptyStateView.workoutHistory() }
                EmptyStatePreviewCard { EmptyStateView.noWorkout(onGenerate: {}) }
                EmptyStatePreviewCard { EmptyStateView.supabaseError(onRetry: {}) }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
        }
    }
    .preferredColorScheme(.dark)
}

// MARK: Pomocná Preview komponenta (jen pro Preview — nepoužívej v produkci)

private struct EmptyStatePreviewCard<V: View>: View {
    @ViewBuilder let content: () -> V

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
    }
}
