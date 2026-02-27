// ActiveSessionContrast_and_PlanFallback.swift
// Agilní Fitness Trenér — Dva prémiové doplňky
//
// ══════════════════════════════════════════════════════════════
// ČÁST A: ActiveSetRow — vylepšený kontrast pro fitness studio
//   ✅ Aktuální série: výraznější rámeček v akcentní barvě
//   ✅ Pole pro váhu a repy: světlejší pozadí, lépe čitelné pod přímým světlem
//   ✅ Drop-in — nahraď rowBG a InlineField v ActiveSessionView.swift
//
// ČÁST B: PlanFallbackCard — výplň prázdné plochy pod kalendářem
//   ✅ Zobrazuje se, pokud není vybrán žádný tréninkový den
//   ✅ Týdenní konzistence + motivační citát od iKorby
//   ✅ Elegantní kartička, drop-in do RollingWeekView
// ══════════════════════════════════════════════════════════════

import SwiftUI
import SwiftData

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ČÁST A — Vylepšený kontrast ActiveSetRow
// MARK: ═══════════════════════════════════════════════════════════════════════

// ── A1: Vylepšené pozadí řádku série ────────────────────────────────────────
//
// Nahraď v ActiveSessionView.swift property `rowBG` za tuto implementaci.
// Klíčové změny:
//   • isActive = světlejší fill + výraznější modrý rámeček (fitness studio čitelnost)
//   • Completed = jemný zelený nádech (jasná zpětná vazba)
//   • Inactive = průhledné (méně rušivé)

extension ActiveSetRow {

    /// Vylepšené pozadí série — nahrazuje původní `rowBG`
    var enhancedRowBackground: some View {
        Group {
            if currentSet.isCompleted {
                // ─ Dokončená série: zelený nádech + outline
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.28, blue: 0.12).opacity(0.50))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                Color(red: 0.13, green: 0.80, blue: 0.43).opacity(0.30),
                                lineWidth: 1
                            )
                    )
            } else if isActive {
                // ─ Aktivní série: výraznější pozadí + akcentní rámeček
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.11))          // ← světlejší (fitness studio)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.80),
                                        Color.cyan.opacity(0.55)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5               // ← silnější rámeček
                            )
                    )
                    .shadow(
                        color: Color.blue.opacity(0.20),
                        radius: 8, x: 0, y: 2
                    )
            } else {
                // ─ Neaktivní série: průhledné
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.clear)
            }
        }
    }
}

// ── A2: Vylepšené InlineField — světlejší, lépe čitelné pod ostrým světlem ──
//
// Toto je upravená verze `InlineField` z ActiveSessionView.swift.
// Přidej příponu `_HighContrast` nebo nahraď původní implementaci.

private struct InlineField_HighContrast: View {
    @Binding var text: String
    let hint: String
    let suffix: String?
    let keyboard: UIKeyboardType
    @FocusState var isFocused: Bool
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(borderColor, lineWidth: isFocused ? 2.0 : 1.0)
                )

            if text.isEmpty && !isFocused {
                Text(hint)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(isActive ? 0.35 : 0.18))
            }

            HStack(spacing: 2) {
                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .focused($isFocused)
                    .font(.system(size: 17, weight: .bold, design: .rounded))   // ← větší písmo
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .disabled(!isActive || isCompleted)

                if let s = suffix, !text.isEmpty {
                    Text(s)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.40))
                }
            }
        }
        .frame(height: 44)   // ← o 2pt vyšší pro lepší tappabilitu
    }

    private var fieldBackground: Color {
        if isFocused       { return .white.opacity(0.15) }  // ← světlejší při focusu
        if isActive        { return .white.opacity(0.12) }  // ← světlejší aktivní
        if isCompleted     { return .white.opacity(0.04) }
        return .clear
    }

    private var borderColor: Color {
        if isFocused  { return Color.blue.opacity(0.80) }
        if isActive   { return Color.white.opacity(0.22) }  // ← jemný outline i bez focusu
        return Color.clear
    }
}

// ── A3: Ukázka zapojení do ActiveSetRow.body ────────────────────────────────
//
// V ActiveSessionView.swift v struct ActiveSetRow, nahraď:
//
//   .background(rowBG)
//
// za:
//
//   .background(enhancedRowBackground)
//
// A InlineField( ... ) za InlineField_HighContrast( ... )


// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ČÁST B — PlanFallbackCard (výplň prázdné plochy v PlanView)
// MARK: ═══════════════════════════════════════════════════════════════════════
//
// Použití v RollingWeekView.body:
//
//   // Po konci 7denního scrollu, pokud není vybrán žádný den:
//   if selectedWorkoutDay == nil {
//       PlanFallbackCard(
//           weekConsistency: vm.weekConsistency,
//           motivationalQuote: vm.motivationalQuote
//       )
//       .transition(.move(edge: .bottom).combined(with: .opacity))
//   }

struct PlanFallbackCard: View {

    /// Procento dokončených tréninků tento týden (0.0 – 1.0)
    var weekConsistency: Double = 0.6

    /// Motivační citát — ideálně načtený z AI nebo ze statického poolu
    var motivationalQuote: String = "Konstantnost poráží motivaci. Každý trénink, i průměrný, tě posouvá dál."

    /// Autor citátu
    var quoteAuthor: String = "iKorba, tvůj AI trenér"

    @State private var appeared  = false
    @State private var glowPulse = false

    private var consistencyColor: Color {
        weekConsistency >= 0.75 ? Color(red: 0.13, green: 0.80, blue: 0.43)
            : weekConsistency >= 0.50 ? .orange
            : .red.opacity(0.80)
    }

    private var consistencyLabel: String {
        weekConsistency >= 0.75 ? "Výborná konzistence 🔥"
            : weekConsistency >= 0.50 ? "Slušný start 💪"
            : "Čas přidat plyn ⚡"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Hlavička ─────────────────────────────────────────────────────
            HStack {
                Text("PŘEHLED TÝDNE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white.opacity(0.30))
                    .kerning(1.5)
                Spacer()
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.25))
            }

            // ── Konzistence pruh ─────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(consistencyLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(weekConsistency * 100))%")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(consistencyColor)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [consistencyColor, consistencyColor.opacity(0.65)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(
                                width: appeared
                                    ? geo.size.width * min(weekConsistency, 1.0)
                                    : 0,
                                height: 6
                            )
                            .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.15), value: appeared)
                    }
                }
                .frame(height: 6)
            }

            Divider()
                .background(Color.white.opacity(0.07))

            // ── iKorbův citát ─────────────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                // iKorbův avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.20, green: 0.52, blue: 1.0),
                                    Color(red: 0.08, green: 0.32, blue: 0.82)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)

                    // Ambient glow
                    Circle()
                        .fill(Color.blue.opacity(0.20))
                        .frame(width: 34, height: 34)
                        .blur(radius: glowPulse ? 8 : 4)
                        .scaleEffect(glowPulse ? 1.3 : 0.9)
                        .animation(
                            .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                            value: glowPulse
                        )

                    Text("iK")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(quoteAuthor.uppercased())
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.white.opacity(0.28))
                        .kerning(0.8)

                    Text("„\(motivationalQuote)“")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // ── Hint pro uživatele ────────────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.25))
                Text("Vyber tréninkový den výše pro detail a zahájení.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.28))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.50, dampingFraction: 0.75).delay(0.08)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                glowPulse = true
            }
        }
    }
}

// MARK: ─── Statický pool motivačních citátů (fallback bez AI) ────────────────

enum iKorbaQuotes {
    static let pool: [String] = [
        // Konzistence a mentalita
        "Konstantnost poráží motivaci. Každý trénink, i průměrný, tě posouvá dál.",
        "Progres není přímka. Jsou v tom výkyvy — ale směr je vždy nahoru.",
        "Nejlepší trénink je ten, který jsi absolvoval. Dokonalý přijde časem.",
        "Malé týdenní přírůstky vedou k obrovským ročním výsledkům.",
        "Disciplína ti otevírá dveře, které motivace ani neumí najít.",
        "Záleží na tom, co děláš, když se nechceš. To rozhoduje.",
        "Průměrný trénink dvakrát týdně poráží dokonalý trénink jednou za měsíc.",
        // Regenerace a tělo
        "Regenerace je součást tréninku, ne jeho opak.",
        "Tvoje tělo adaptuje na to, co po něm pravidelně chceš. Buď s tím záměrný.",
        "Síla se nebuduje v posilovně — buduje se ve spánku, jídle a konzistenci.",
        "Spánek je levný doping. Využívej ho.",
        "Únava je normální. Ignorování únavy je risk. Poznáš rozdíl.",
        // Technické a progresivní přetížení
        "Gram techniky má větší cenu než kilogram ega.",
        "Přidávej váhu, až ti to tělo dovolí — ne ego.",
        "Šest týdnů konzistentního tréninku změní víc než rok náhodného přístupu.",
        // Mindset
        "Porovnávej se jenom s tím, kým jsi byl minulý týden.",
        "Nikdo nezačínal silný. Každý začínal a opakoval.",
        "Tvoje limity jsou dočasné. Tvoje rutina je permanentní.",
        "Zdravé tělo je dlouhodobý projekt, ne 30denní výzva.",
    ]

    static var random: String { pool.randomElement() ?? pool[0] }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Rozšíření RollingWeekViewModel o konzistenci a citáty
// MARK: ═══════════════════════════════════════════════════════════════════════
//
// Přidej tato computed properties do existujícího RollingWeekViewModel:

extension RollingWeekViewModel {

    /// Poměr dokončených tréninkových dnů z aktuálního týdne
    /// Načítá skutečné WorkoutSession záznamy ze SwiftData.
    var weekConsistency: Double {
        let workoutDays = days.filter { $0.dayType == .workout }
        guard !workoutDays.isEmpty else { return 0 }

        let context   = SharedModelContainer.container.mainContext
        let weekStart = days.first?.date ?? Date()
        let weekEnd   = days.last?.date  ?? Date()
        let statusCompleted = SessionStatus.completed

        // Načti dokončené tréninky v rozsahu aktuálního týdne
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.status == statusCompleted &&
                $0.startedAt >= weekStart &&
                $0.startedAt <= weekEnd
            }
        )
        let completedSessions = (try? context.fetch(descriptor))?.count ?? 0
        return min(Double(completedSessions) / Double(workoutDays.count), 1.0)
    }

    /// Motivační citát — nejprve z recalculationMessage, jinak statický pool
    var motivationalQuote: String {
        iKorbaQuotes.random
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Preview
// MARK: ═══════════════════════════════════════════════════════════════════════

#Preview("Plan Fallback + SetRow kontrast") {
    ZStack {
        Color(hue: 0.62, saturation: 0.18, brightness: 0.07).ignoresSafeArea()

        ScrollView {
            VStack(spacing: 24) {
                Text("PlanFallbackCard — 60% konzistence")
                    .font(.caption).foregroundStyle(.white.opacity(0.4))

                PlanFallbackCard(
                    weekConsistency: 0.60,
                    motivationalQuote: "Konstantnost poráží motivaci. Každý trénink, i průměrný, tě posouvá dál."
                )

                Text("PlanFallbackCard — 80% konzistence")
                    .font(.caption).foregroundStyle(.white.opacity(0.4))

                PlanFallbackCard(
                    weekConsistency: 0.80,
                    motivationalQuote: "Výborný týden! Regenerace dnes je investice do dalšího tréninku."
                )

                Text("PlanFallbackCard — 30% konzistence")
                    .font(.caption).foregroundStyle(.white.opacity(0.4))

                PlanFallbackCard(
                    weekConsistency: 0.30,
                    motivationalQuote: "Malé týdenní přírůstky vedou k obrovským ročním výsledkům."
                )
            }
            .padding(20)
        }
    }
    .preferredColorScheme(.dark)
}
