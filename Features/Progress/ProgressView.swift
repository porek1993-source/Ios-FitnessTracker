// ProgressView.swift
// Agilní Fitness Trenér — Progres napojený na reálná SwiftData

import SwiftUI
import SwiftData
import Charts

struct AppProgressView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var exercises: [Exercise]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedExercise: Exercise?
    @State private var showExercisePicker = false
    @State private var show1RM = false

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.status == .completed }
    }

    @Query(sort: \WeightEntry.loggedAt, order: .reverse) private var weightEntries: [WeightEntry]

    private var volumeByWeek: [(label: String, volume: Double)] {
        let calendar = Calendar.current
        // FIX: Použij (yearForWeekOfYear * 100 + weekOfYear) jako klíč
        // Zabraňuje kolizi T01/T52 přes hranici roku (bug: T52 2024 vs T52 2025 = stejný klíč)
        var grouped: [Int: Double] = [:]

        func yearWeekKey(from date: Date) -> Int {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return (comps.yearForWeekOfYear ?? 0) * 100 + (comps.weekOfYear ?? 0)
        }

        // Použij WeightEntry (pouze .normal a .failure)
        for entry in weightEntries.filter({ $0.setType == .normal || $0.setType == .failure }) {
            grouped[yearWeekKey(from: entry.loggedAt), default: 0] += entry.weightKg * Double(entry.reps)
        }
        // Fallback na session.exercises pro zpětnou kompatibilitu
        if grouped.isEmpty {
            for session in completedSessions {
                let key = yearWeekKey(from: session.startedAt)
                var vol = 0.0
                for ex in session.exercises {
                    for set in ex.completedSets {
                        if set.setType == .normal || set.setType == .failure {
                            vol += set.weightKg * Double(set.reps)
                        }
                    }
                }
                grouped[key, default: 0] += vol
            }
        }
        // Seřaď chronologicky (YYYYWW), vezmi posledních 6 týdnů, zobraz jen číslo týdne v popisku
        return grouped.sorted { $0.key < $1.key }.suffix(6).map { (key, vol) in
            ("T\(key % 100)", vol)
        }
    }

    private var exerciseHistory: [(date: Date, weight: Double)] {
        guard let ex = selectedExercise else { return [] }
        
        // Filtrujeme vždy jen na .normal a .failure (případně ty, co flag nemají a spadnou pod .normal)
        let relevantEntries = weightEntries
            .filter { $0.exercise?.slug == ex.slug }
            .filter { $0.setType == .normal || $0.setType == .failure }
            
        if show1RM {
            return OneRepMaxCalculator.historical1RM(from: relevantEntries)
                .suffix(12)
                .map { (date: $0.date, weight: $0.OneRM) }
        } else {
            return relevantEntries // používáme filtrované pole
                .sorted { $0.loggedAt < $1.loggedAt }
                .suffix(12)
                .map { ($0.loggedAt, $0.weightKg) }
        }
    }

    private var totalVolume: Double {
        // WeightEntry je přesný zdroj (jen pracovní a failure)
        let fromEntries = weightEntries
            .filter({ $0.setType == .normal || $0.setType == .failure })
            .reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            
        if fromEntries > 0 { return fromEntries }
        
        // Fallback
        var fallbackVol = 0.0
        for session in completedSessions {
            for ex in session.exercises {
                for set in ex.completedSets {
                    if set.setType == .normal || set.setType == .failure {
                        fallbackVol += set.weightKg * Double(set.reps)
                    }
                }
            }
        }
        return fallbackVol
    }

    private var personalRecordsCount: Int {
        exercises.filter { ($0.personalRecord1RM ?? 0) > 0 }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        statsHeader
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        if !volumeByWeek.isEmpty {
                            weeklyVolumeChart.padding(.horizontal, 16)
                        }
                        
                        WorkoutCalendarView(workoutDates: completedSessions.map { $0.startedAt })
                            .padding(.horizontal, 16)

                        exerciseProgressSection.padding(.horizontal, 16)
                        historySection.padding(.horizontal, 16).padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Progres")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showExercisePicker) { exercisePickerSheet }
            .onAppear {
                if selectedExercise == nil {
                    selectedExercise = exercises.first(where: { $0.slug == "barbell-bench-press" })
                        ?? exercises.first(where: { !$0.weightHistory.isEmpty })
                }
            }
        }
    }

    // MARK: — Stats

    // MARK: - Helpers
    


    private var statsHeader: some View {
        HStack(spacing: 12) {
            statCard(title: "Tréninky", value: "\(completedSessions.count)", icon: "checkmark.circle.fill", color: .blue)
            statCard(title: "Celkový objem", value: totalVolume.formatVolume(), icon: "scalemass.fill", color: .orange)
            statCard(title: "PR záznamy", value: "\(personalRecordsCount)", icon: "trophy.fill", color: .yellow)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: — Weekly Volume Chart

    private var weeklyVolumeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Týdenní objem (kg)")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Chart(volumeByWeek, id: \.label) { item in
                BarMark(x: .value("Týden", item.label), y: .value("Objem", item.volume))
                    .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .bottom, endPoint: .top))
                    .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().foregroundStyle(Color.white.opacity(0.6)) }
            }
            .chartYAxis {
                AxisMarks { _ in AxisValueLabel().foregroundStyle(Color.white.opacity(0.6)) }
            }
            .frame(height: 160)
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: — Exercise Progress

    private var exerciseProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progres cviku")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                
                // Toggle 1RM
                Button {
                    withAnimation { show1RM.toggle() }
                } label: {
                    Text(show1RM ? "1RM" : "Váha")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(show1RM ? .white : .blue)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(show1RM ? Color.orange : Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Button { showExercisePicker = true } label: {
                    HStack(spacing: 4) {
                        Text(selectedExercise?.name ?? "Vyber cvik").font(.system(size: 13, weight: .medium)).foregroundStyle(.blue)
                        Image(systemName: "chevron.down").font(.system(size: 11)).foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            if exerciseHistory.isEmpty {
                EmptyStateView(
                    icon: "chart.xyaxis.line",
                    title: "Zatím žádná data",
                    message: "Začni odcvičovat tento cvik a sleduj svůj progres! 💪",
                    iconColor: .white.opacity(0.3)
                )
            } else {
                Chart(exerciseHistory, id: \.date) { entry in
                    let color = show1RM ? Color.orange : Color.blue
                    LineMark(x: .value("Datum", entry.date), y: .value("Váha", entry.weight))
                        .foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Datum", entry.date), y: .value("Váha", entry.weight))
                        .foregroundStyle(color).symbolSize(40)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.day().month())
                                    .foregroundStyle(Color.white.opacity(0.6)).font(.system(size: 10))
                            }
                        }
                    }
                }
                .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Color.white.opacity(0.6)) } }
                .frame(height: 140)

                if let pr = selectedExercise?.personalRecord1RM {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                        Text("Odhadovaný 1RM rekord: \(String(format: "%.1f", pr)) kg")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: — History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Historie tréninků")
                .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)

            if completedSessions.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "Prázdná historie",
                    message: "Ještě jsi neodcvičil žádný trénink. Hurá na to! 🏋️",
                    iconColor: .white.opacity(0.3)
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(completedSessions.prefix(20)) { session in
                        sessionCard(session)
                    }
                }
            }
        }
    }

    private func sessionCard(_ session: WorkoutSession) -> some View {
        // Výpočet objemu ze session WeightEntries (jen pracovní/selhání)
        var sessionVolume = weightEntries
            .filter { $0.sessionId == session.id }
            .filter { $0.setType == .normal || $0.setType == .failure }
            .reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            
        // Fallback pro staré tréninky
        if sessionVolume == 0 {
            var fallbackVol: Double = 0
            for ex in session.exercises {
                for set in ex.completedSets {
                    if set.setType == .normal || set.setType == .failure {
                        fallbackVol += set.weightKg * Double(set.reps)
                    }
                }
            }
            sessionVolume = fallbackVol
        }

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4).fill(Color.blue.opacity(0.8)).frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.plannedDay?.label ?? "Trénink")
                    .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                HStack(spacing: 12) {
                    Label("\(session.durationMinutes) min", systemImage: "clock")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                    if sessionVolume > 0 {
                        Label(sessionVolume.formatVolume(), systemImage: "scalemass")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                    }
                    let exCount = session.exercises.count > 0 ? session.exercises.count : (session.plannedDay?.plannedExercises.count ?? 0)
                    if exCount > 0 && sessionVolume == 0 {
                        Label("\(exCount) cviků", systemImage: "scalemass.fill")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            Spacer()
            Text(session.startedAt, format: .dateTime.day().month())
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: — Picker Sheet

    private var exercisePickerSheet: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                let withHistory = exercises.filter { !$0.weightHistory.isEmpty }
                if withHistory.isEmpty {
                    Text("Zatím žádná historie cviků.")
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    List(withHistory, id: \.slug) { ex in
                        Button {
                            selectedExercise = ex
                            showExercisePicker = false
                        } label: {
                            HStack {
                                Text(ex.name).foregroundStyle(.white)
                                Spacer()
                                if selectedExercise?.slug == ex.slug {
                                    Image(systemName: "checkmark").foregroundStyle(.blue)
                                }
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Vyber cvik").navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zavřít") { showExercisePicker = false } } }
        }
    }


}
