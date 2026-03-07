// HealthKitErrorHandling.swift
// Agilní Fitness Trenér — Elegantní ošetření HealthKit chyb
//
// ✅ Surová systémová chybová hlášení se NIKDY nezobrazí uživateli
// ✅ Specifické mapování known HealthKit errorů na česky přátelské zprávy
// ✅ Drop-in úprava sekce Apple Health v ProfileSettingsForm
// ✅ Logování surové chyby zůstává zachováno (AppLogger) pro debugging

import SwiftUI

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: HealthKitErrorMapper  — čistý překlad systémových chyb
// MARK: ═══════════════════════════════════════════════════════════════════════

enum HealthKitErrorMapper {

    /// Přeloží libovolnou Error na uživatelsky přátelský český text.
    /// Surová systémová hláška se NIKDY nevrátí — vždy vrátí fallback.
    static func friendlyMessage(from error: Error) -> String {
        let raw = error.localizedDescription.lowercased()

        // ── Entitlement / oprávnění (nejčastější případ při dev buildu) ──────
        if raw.contains("entitlement") || raw.contains("com.apple.developer.healthkit") {
            return "Nepodařilo se propojit s Apple Health. Zkontroluj prosím nastavení iPhonu."
        }

        // ── Uživatel zamítl přístup ────────────────────────────────────────
        if raw.contains("authorization denied") || raw.contains("not determined") {
            return "Přístup k Apple Health byl zamítnut. Otevři Nastavení → Zdraví → Agile Trainer a povol přístup."
        }

        // ── HealthKit není na zařízení dostupný (iPad, Mac bez HealthKit) ──
        if raw.contains("unavailable") || raw.contains("not available") {
            return "Apple Health není na tomto zařízení dostupný. Funkce vyžaduje iPhone s watchOS."
        }

        // ── Síťová / cloudová chyba (iCloud Health Sharing) ────────────────
        if raw.contains("network") || raw.contains("internet") {
            return "Nepodařilo se připojit. Zkontroluj připojení k internetu a zkus to znovu."
        }

        // ── Generická záloha — všechny ostatní neznámé chyby ────────────────
        return "Nepodařilo se propojit s Apple Health. Zkontroluj prosím nastavení iPhonu."
    }

    /// Výsledkový typ pro UI stav HealthKit sekce
    enum AuthState {
        case success(message: String)
        case failure(message: String)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: AppleHealthSection  — drop-in náhrada sekce v ProfileSettingsForm
// MARK: ═══════════════════════════════════════════════════════════════════════
//
// Použití v SettingsView:
//
//   AppleHealthSection(healthKitService: healthKitService)
//
// Nahrazuje celý blok settingsSection(title: "Apple Health", ...) { ... }

struct AppleHealthSection: View {
    @ObservedObject var healthKitService: HealthKitService

    @State private var isRequesting    = false
    @State private var feedbackState:  HealthKitErrorMapper.AuthState? = nil

    var body: some View {
        // Použij existující settingsSection wrapper z ProfileSettingsForm.
        // Zde implementujeme obsah (content) sekce.
        VStack(alignment: .leading, spacing: 12) {

            // ── Status řádek ─────────────────────────────────────────────────
            HStack(spacing: 12) {
                Image(systemName: healthKitService.isAuthorized
                      ? "checkmark.circle.fill"
                      : "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(healthKitService.isAuthorized ? .green : .orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(healthKitService.isAuthorized ? "Přístup povolen" : "Přístup není povolen")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(healthKitService.isAuthorized
                         ? "Spánek, HRV a tep se načítají automaticky."
                         : "Bez přístupu nelze zobrazit zdravotní data.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // ── Tlačítko pro povolení přístupu ───────────────────────────────
            Button {
                requestAccess()
            } label: {
                HStack(spacing: 8) {
                    if isRequesting {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "heart.text.square.fill")
                    }
                    Text(healthKitService.isAuthorized
                         ? "Znovu požádat o přístup"
                         : "Povolit přístup k Apple Health")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)

            // ── Elegantní výsledková zpráva (BEZ surových chyb) ──────────────
            if let state = feedbackState {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: iconFor(state))
                        .font(.system(size: 14))
                        .foregroundStyle(colorFor(state))
                        .padding(.top, 1)

                    Text(messageFor(state))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColorFor(state).opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(backgroundColorFor(state).opacity(0.25), lineWidth: 1)
                        )
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // ── Odkaz na Nastavení ────────────────────────────────────────────
            Button {
                openHealthSettings()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                    Text("Otevřít Nastavení → Zdraví")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: feedbackState != nil)
    }

    // MARK: Actions

    private func requestAccess() {
        isRequesting = true
        feedbackState = nil

        Task {
            do {
                try await healthKitService.requestAuthorization()
                // ✅ Phase 4: Vyžádat opt-in i pro nutriční a spánková data 
                try? await HealthKitNutritionService.shared.requestAuthorization()

                // ✅ Úspěch — elegantní česká zpráva
                await MainActor.run {
                    withAnimation {
                        feedbackState = .success(message: "Přístup k Apple Health byl udělen. Data se začnou načítat.")
                    }
                    isRequesting = false
                }
            } catch {
                // ⚠️ Surová chyba se NIKDY nezobrazí — pouze zalogujeme
                AppLogger.error("HealthKit authorization failed (raw): \(error)")

                // Uživateli ukážeme přátelský text
                let friendly = HealthKitErrorMapper.friendlyMessage(from: error)

                await MainActor.run {
                    withAnimation {
                        feedbackState = .failure(message: friendly)
                    }
                    isRequesting = false
                }
            }
        }
    }

    private func openHealthSettings() {
        if let url = URL(string: "App-Prefs:HEALTH") {
            UIApplication.shared.open(url)
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: Helpers

    private func iconFor(_ state: HealthKitErrorMapper.AuthState) -> String {
        switch state {
        case .success: return "checkmark.circle.fill"
        case .failure: return "info.circle.fill"
        }
    }

    private func colorFor(_ state: HealthKitErrorMapper.AuthState) -> Color {
        switch state {
        case .success: return .green
        case .failure: return .orange
        }
    }

    private func backgroundColorFor(_ state: HealthKitErrorMapper.AuthState) -> Color {
        switch state {
        case .success: return .green
        case .failure: return .orange
        }
    }

    private func messageFor(_ state: HealthKitErrorMapper.AuthState) -> String {
        switch state {
        case .success(let msg): return msg
        case .failure(let msg): return msg
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Preview
// MARK: ═══════════════════════════════════════════════════════════════════════

#Preview("HealthKit Error Handling") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            Text("Testovací sekce Apple Health")
                .font(.headline).foregroundStyle(.white)
                .padding(.top, 60)

            // Simulace chybového stavu
            VStack(alignment: .leading, spacing: 12) {
                // Přímá ukázka chybové zprávy bez tlačítka
                let mockError = NSError(
                    domain: "com.apple.healthkit",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Missing com.apple.developer.healthkit entitlement"]
                )
                let friendlyMsg = HealthKitErrorMapper.friendlyMessage(from: mockError)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text(friendlyMsg)
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)))

                Text("↑ Tohle vidí uživatel. Surová zpráva je pouze v logu.")
                    .font(.caption).foregroundStyle(.white.opacity(0.4))
                    .italic()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
            .padding(.horizontal, 20)

            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
