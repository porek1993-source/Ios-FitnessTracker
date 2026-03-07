// MesocyclePlannerView.swift
// Přehled a tvorba 8–12 týdenního mezocyklu.
// Zobrazuje aktuální pozici v cyklu, fáze a umožňuje AI generaci nového plánu.

import SwiftUI
import SwiftData

struct MesocyclePlannerView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Mesocycle.startDate, order: .reverse) private var cycles: [Mesocycle]
    @State private var showCreate = false

    var activeCycle: Mesocycle? { cycles.first(where: \.isActive) }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    if let cycle = activeCycle {
                        ActiveCycleCard(cycle: cycle)
                        WeekTimelineView(cycle: cycle)
                    } else {
                        emptyState
                    }

                    if cycles.count > 1 {
                        pastCyclesSection
                    }
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Periodizace")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppColors.primaryAccent)
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateMesocycleView()
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.primaryAccent.opacity(0.5))
            Text("Zatím žádný mezocyklus")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
            Text("Vytvoř svůj první AI periodizovaný plán na 8–12 týdnů.")
                .font(.callout)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
            Button { showCreate = true } label: {
                Label("Vytvořit plán", systemImage: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 13)
                    .background(AppColors.primaryAccent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 40)
    }

    private var pastCyclesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Předchozí cykly")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
            ForEach(cycles.filter { !$0.isActive }) { cycle in
                HStack {
                    let c = cycle.currentPhase.accentColor
                    Circle().fill(Color(red: c.r, green: c.g, blue: c.b)).frame(width: 10, height: 10)
                    Text(cycle.title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text("\(cycle.totalWeeks) týdnů")
                        .font(.caption)
                        .foregroundStyle(AppColors.textMuted)
                }
                .padding(.vertical, 8)
                Divider().background(Color.white.opacity(0.06))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Active Cycle Card

struct ActiveCycleCard: View {
    let cycle: Mesocycle

    var body: some View {
        let c = cycle.currentPhase.accentColor
        let phaseColor = Color(red: c.r, green: c.g, blue: c.b)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(cycle.currentPhase.icon) \(cycle.currentPhase.rawValue)")
                        .font(.system(.caption, design: .rounded).weight(.black))
                        .foregroundStyle(phaseColor)
                        .textCase(.uppercase)
                    Text(cycle.title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Týden \(cycle.currentWeekIndex + 1)/\(cycle.totalWeeks)")
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundStyle(phaseColor)
                    Text(cycle.currentPhase.description)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [phaseColor, phaseColor.opacity(0.6)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * cycle.progressFraction, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Label(formatDate(cycle.startDate), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                Spacer()
                Label(formatDate(cycle.endDate), systemImage: "flag.checkered")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            if let goal = Optional(cycle.goal), !goal.isEmpty {
                Text("Cíl: \(goal)")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .fill(phaseColor.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .stroke(phaseColor.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f.string(from: date)
    }
}

// MARK: - Week Timeline

struct WeekTimelineView: View {
    let cycle: Mesocycle

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Přehled týdnů")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<cycle.totalWeeks, id: \.self) { i in
                        let isCurrent = i == cycle.currentWeekIndex
                        let isPast    = i < cycle.currentWeekIndex

                        let weekPhase = phaseFor(week: i)
                        let c = weekPhase.accentColor
                        let color = Color(red: c.r, green: c.g, blue: c.b)

                        VStack(spacing: 4) {
                            Text("\(i + 1)")
                                .font(.system(size: 11, weight: isCurrent ? .black : .medium, design: .rounded))
                                .foregroundStyle(isCurrent ? .white : (isPast ? AppColors.textMuted : AppColors.textSecondary))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle().fill(
                                        isCurrent ? color : (isPast ? color.opacity(0.3) : Color.white.opacity(0.07))
                                    )
                                )
                                .overlay(
                                    Circle().stroke(isCurrent ? color : Color.clear, lineWidth: 2.5)
                                )

                            Text(weekPhase == .deload ? "D" : weekPhase.rawValue.prefix(3))
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(isCurrent ? color : AppColors.textMuted)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func phaseFor(week: Int) -> MesocyclePhase {
        if let w = cycle.weeks[safe: week] { return w.phase }
        // Fallback: rovnoměrné rozdělení fází
        guard !cycle.phases.isEmpty else { return .foundation }
        let perPhase = max(1, cycle.totalWeeks / cycle.phases.count)
        let idx = min(week / perPhase, cycle.phases.count - 1)
        return cycle.phases[idx]
    }
}

// MARK: - Create Mesocycle

struct CreateMesocycleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @State private var title: String = ""
    @State private var goal: String = ""
    @State private var totalWeeks: Int = 8
    @State private var startDate: Date = Date()
    @State private var selectedPhases: [MesocyclePhase] = [.hypertrophy, .strength, .deload]
    @State private var isGenerating: Bool = false

    private let weekOptions = [6, 8, 10, 12, 16]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        formSection(label: "Název a cíl") {
                            VStack(spacing: 10) {
                                styledField("Název (např. Jarní hyper-síla)", text: $title)
                                styledField("Cíl (co chceš dosáhnout?)", text: $goal)
                            }
                        }

                        formSection(label: "Délka") {
                            HStack(spacing: 10) {
                                ForEach(weekOptions, id: \.self) { w in
                                    Button { totalWeeks = w } label: {
                                        Text("\(w)T")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(totalWeeks == w ? .white : AppColors.textSecondary)
                                            .frame(maxWidth: .infinity).frame(minHeight: 38)
                                            .background(
                                                totalWeeks == w ? AppColors.primaryAccent.opacity(0.25) : Color.white.opacity(0.07),
                                                in: RoundedRectangle(cornerRadius: 10)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(totalWeeks == w ? AppColors.primaryAccent.opacity(0.5) : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        formSection(label: "Fáze (v tomto pořadí)") {
                            VStack(spacing: 8) {
                                ForEach(MesocyclePhase.allCases, id: \.self) { phase in
                                    let isSelected = selectedPhases.contains(phase)
                                    let c = phase.accentColor
                                    Button {
                                        if isSelected {
                                            if selectedPhases.count > 1 { selectedPhases.removeAll { $0 == phase } }
                                        } else {
                                            selectedPhases.append(phase)
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(phase.icon).frame(width: 28)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(phase.rawValue).font(.callout.weight(.semibold)).foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                                                Text(phase.description).font(.caption2).foregroundStyle(AppColors.textMuted).lineLimit(1)
                                            }
                                            Spacer()
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(Color(red: c.r, green: c.g, blue: c.b))
                                            }
                                        }
                                        .padding(12)
                                        .background(
                                            isSelected ? Color(red: c.r, green: c.g, blue: c.b).opacity(0.12) : Color.white.opacity(0.05),
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        DatePicker("Začátek", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .colorScheme(.dark)
                            .padding(14)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                        Button {
                            createCycle()
                        } label: {
                            HStack(spacing: 8) {
                                if isGenerating {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isGenerating ? "Generuji plán…" : "Vytvořit mezocyklus")
                                    .font(.body.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(LinearGradient(colors: [AppColors.primaryAccent, AppColors.secondaryAccent],
                                                         startPoint: .leading, endPoint: .trailing))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(title.isEmpty || isGenerating)
                        .opacity(title.isEmpty ? 0.5 : 1)

                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                }
            }
            .navigationTitle("Nový mezocyklus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavřít") { dismiss() }.foregroundStyle(AppColors.textSecondary)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func formSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(AppColors.textMuted)
                .textCase(.uppercase)
            content()
        }
    }

    private func styledField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .foregroundStyle(AppColors.textPrimary)
            .padding(12)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private func createCycle() {
        let cycle = Mesocycle(
            title: title,
            goal: goal,
            totalWeeks: totalWeeks,
            startDate: startDate,
            phases: selectedPhases
        )
        ctx.insert(cycle)
        try? ctx.save()
        dismiss()
    }
}
