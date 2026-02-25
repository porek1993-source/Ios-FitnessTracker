// RollingWeekView.swift
// Klouzavý 7denní kalendář s možností overridu dnů. Vše česky.

import SwiftUI
import SwiftData

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Day Model
// MARK: ═══════════════════════════════════════════════════════════════════════

enum DayType: String, CaseIterable, Identifiable {
    case workout    = "Trénink"
    case rest       = "Volno"
    case sport      = "Jiný sport"
    case cardio     = "Kardio"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .workout: return "dumbbell.fill"
        case .rest:    return "bed.double.fill"
        case .sport:   return "sportscourt.fill"
        case .cardio:  return "figure.run"
        }
    }

    var tint: Color {
        switch self {
        case .workout: return .appPrimaryAccent
        case .rest:    return .white.opacity(0.3)
        case .sport:   return .orange
        case .cardio:  return .appGreenBadge
        }
    }
}

struct WeekDay: Identifiable {
    let id = UUID()
    let date: Date
    var dayType: DayType
    var label: String          // "Push", "Pull", "Volno", "Fotbal" apod.
    var isToday: Bool
    var isOverridden: Bool     // Uživatel manuálně změnil

    var czechDayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }

    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ViewModel
// MARK: ═══════════════════════════════════════════════════════════════════════

@MainActor
final class RollingWeekViewModel: ObservableObject {
    @Published var days: [WeekDay] = []
    @Published var isRecalculating = false
    @Published var recalculationMessage: String?
    @Published var editingDay: WeekDay?

    init() {
        buildWeek()
    }

    /// Sestaví 7 dnů od dneška.
    func buildWeek() {
        let calendar = Calendar.current
        let today = Date.now
        days = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            let isToday = offset == 0
            // Výchozí rozložení: Trénink / Volno / Trénink / Trénink / Volno / Trénink / Volno
            let pattern: [DayType] = [.workout, .rest, .workout, .workout, .rest, .workout, .rest]
            let labels = ["Push", "Volno", "Pull", "Nohy", "Volno", "Upper", "Volno"]
            return WeekDay(
                date: date,
                dayType: pattern[offset],
                label: labels[offset],
                isToday: isToday,
                isOverridden: false
            )
        }
    }

    /// Uživatel přepne den na jiný typ.
    func overrideDay(id: UUID, newType: DayType, customLabel: String?) {
        guard let idx = days.firstIndex(where: { $0.id == id }) else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            days[idx].dayType = newType
            days[idx].label = customLabel ?? newType.rawValue
            days[idx].isOverridden = true
        }

        HapticManager.shared.playMediumClick()

        // Spustíme AI přepočet na pozadí
        Task { await triggerRecalculation() }
    }

    /// AI přepočet zbylých tréninků na základě nového rozložení.
    func triggerRecalculation() async {
        isRecalculating = true
        recalculationMessage = nil

        // Sestavíme kontext pro AI
        let availableDays = days.filter { $0.dayType == .workout && !$0.isToday }
        let totalWorkoutDays = days.filter { $0.dayType == .workout }.count

        do {
            let newSchedule = try await AIReschedulingEngine.recalculateWeek(
                currentDays: days,
                availableWorkoutDays: availableDays.count,
                totalDays: 7
            )

            // Animovaně aktualizujeme labels
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                for update in newSchedule {
                    if let idx = days.firstIndex(where: { $0.date.isSameDay(as: update.date) }),
                       days[idx].dayType == .workout {
                        days[idx].label = update.label
                    }
                }
            }

            recalculationMessage = "Plán přepočítán — \(totalWorkoutDays) tréninkových dnů tento týden."
            HapticManager.shared.playSuccess()
        } catch {
            recalculationMessage = "Přepočet se nezdařil, plán zůstává beze změn."
            HapticManager.shared.playWarning()
        }

        isRecalculating = false
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: View
// MARK: ═══════════════════════════════════════════════════════════════════════

struct RollingWeekView: View {
    @StateObject private var vm = RollingWeekViewModel()
    @State private var showOverrideSheet = false
    @State private var selectedDayForEdit: WeekDay?
    @State private var selectedWorkoutDay: WeekDay?    // Den pro zobrazení cviků
    @Query private var profiles: [UserProfile]

    private var activePlan: WorkoutPlan? {
        profiles.first?.workoutPlans.first(where: { $0.isActive })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Nadpis
            HStack {
                Text("TENTO TÝDEN")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white.opacity(0.3))
                    .kerning(1.5)
                Spacer()
                if vm.isRecalculating {
                    HStack(spacing: 6) {
                        ProgressView().tint(.white.opacity(0.5))
                            .scaleEffect(0.7)
                        Text("Přepočítávám…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            // 7denní scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.days) { day in
                        DayCell(day: day) {
                            if day.dayType == .workout {
                                // Tréninkový den → toggle zobrazení cviků
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                    if selectedWorkoutDay?.id == day.id {
                                        selectedWorkoutDay = nil
                                    } else {
                                        selectedWorkoutDay = day
                                    }
                                }
                            } else {
                                selectedDayForEdit = day
                                showOverrideSheet = true
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal, 4)
            }

            // Status zpráva
            if let msg = vm.recalculationMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .transition(.opacity)
            }

            // ── Detail dne se cviky ──────────────────────────────────────────
            if let selectedDay = selectedWorkoutDay {
                WeekDayExerciseDetailView(
                    day: selectedDay,
                    plan: activePlan
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1))
        )
        .sheet(item: $selectedDayForEdit) { day in
            DayOverrideSheet(day: day) { newType, label in
                vm.overrideDay(id: day.id, newType: newType, customLabel: label)
                showOverrideSheet = false
            }
            .presentationDetents([.height(380)])
        }
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let day: WeekDay
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(day.czechDayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))

                ZStack {
                    Circle()
                        .fill(day.isToday
                              ? day.dayType.tint
                              : day.dayType.tint.opacity(0.15))
                        .frame(width: 48, height: 48)
                    if day.isToday {
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 2)
                            .frame(width: 48, height: 48)
                    }
                    Image(systemName: day.dayType.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(day.isToday ? .white : day.dayType.tint)
                }

                Text(day.dayNumber)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(day.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .frame(width: 50)

                if day.isOverridden {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Day Override Sheet

private struct DayOverrideSheet: View {
    let day: WeekDay
    let onSave: (DayType, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: DayType = .rest
    @State private var customLabel: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(.white.opacity(0.18))
                .frame(width: 36, height: 4).padding(.top, 12)

            Text("Změnit den — \(day.czechDayName) \(day.dayNumber).")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                ForEach(DayType.allCases) { type in
                    Button {
                        withAnimation(.spring(response: 0.25)) { selectedType = type }
                        HapticManager.shared.playSelection()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(type.tint)
                                .frame(width: 28)
                            Text(type.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            if selectedType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(type.tint)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedType == type
                                      ? type.tint.opacity(0.12)
                                      : Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(selectedType == type
                                            ? type.tint.opacity(0.3)
                                            : Color.white.opacity(0.06), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if selectedType == .sport {
                TextField("Název sportu (např. Tenis, Fotbal)", text: $customLabel)
                    .font(.system(size: 14))
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)))
                    .foregroundStyle(.white)
            }

            Button {
                let label = selectedType == .sport && !customLabel.isEmpty ? customLabel : nil
                onSave(selectedType, label)
                dismiss()
            } label: {
                Text("Uložit změnu")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Color.appSecondaryBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { selectedType = day.dayType }
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - WeekDayExerciseDetailView
// Zobrazí seznam cviků pro vybraný tréninkový den z aktivního plánu
// ─────────────────────────────────────────────────────────────────

struct WeekDayExerciseDetailView: View {
    let day: WeekDay
    let plan: WorkoutPlan?

    // Mapování WeekDay.date → dayOfWeek (1=Po...7=Ne)
    private var ourDayIndex: Int {
        let cal = Calendar.current
        let wd = cal.component(.weekday, from: day.date)
        return wd == 1 ? 7 : wd - 1
    }

    private var plannedDay: PlannedWorkoutDay? {
        plan?.scheduledDays.first { $0.dayOfWeek == ourDayIndex && !$0.isRestDay }
    }

    private var exercises: [PlannedExercise] {
        (plannedDay?.plannedExercises ?? []).sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hlavička
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.label.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.appPrimaryAccent)
                        .kerning(1.2)
                    Text(exercises.isEmpty ? "Cviky vygeneruje Jakub při startu" : "\(exercises.count) cviků")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                Image(systemName: "chevron.up.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.2))
            }

            Divider().background(Color.white.opacity(0.07))

            if exercises.isEmpty {
                // Prázdný stav — AI vygeneruje cviky při spuštění tréninku
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue.opacity(0.7))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Plán čeká na AI")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Klikni na „Začít trénink“ a Jakub sestaví personalizovaný workout.")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.2), lineWidth: 1)))
            } else {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, ex in
                    HStack(spacing: 12) {
                        // Pořadí
                        ZStack {
                            Circle().fill(Color.white.opacity(0.07)).frame(width: 28, height: 28)
                            Text("\(idx + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        // Info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ex.exercise?.name ?? "Cvik \(idx + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("\(ex.targetSets)× \(ex.targetRepsMin)–\(ex.targetRepsMax) rep · \(ex.restSeconds / 60)m \(ex.restSeconds % 60)s pauza")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                        if let lastWeight = ex.exercise?.lastUsedWeight {
                            Text(String(format: "%.0f kg", lastWeight))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange.opacity(0.8))
                        }
                    }
                    if idx < exercises.count - 1 {
                        Divider().background(Color.white.opacity(0.05))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.appPrimaryAccent.opacity(0.2), lineWidth: 1))
        )
    }
}
