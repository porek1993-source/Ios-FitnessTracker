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

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.status == .completed }
    }

    @Query(sort: \WeightEntry.loggedAt, order: .reverse) private var weightEntries: [WeightEntry]

    private var volumeByWeek: [(label: String, volume: Double)] {
        let calendar = Calendar.current
        var grouped: [Int: Double] = [:]
        // Použij WeightEntry (přesná data ze všech typů tréninků)
        for entry in weightEntries {
            let week = calendar.component(.weekOfYear, from: entry.loggedAt)
            grouped[week, default: 0] += entry.weightKg * Double(entry.reps)
        }
        // Fallback na session.exercises pro zpětnou kompatibilitu
        if grouped.isEmpty {
            for session in completedSessions {
                let week = calendar.component(.weekOfYear, from: session.startedAt)
                let vol = session.exercises
                    .flatMap { $0.completedSets }
                    .reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
                grouped[week, default: 0] += vol
            }
        }
        return grouped.sorted { $0.key < $1.key }.suffix(6).map { ("T\($0.key)", $0.value) }
    }

    private var exerciseHistory: [(date: Date, weight: Double)] {
        guard let ex = selectedExercise else { return [] }
        return ex.weightHistory
            .sorted { $0.loggedAt < $1.loggedAt }
            .suffix(12)
            .map { ($0.loggedAt, $0.weightKg) }
    }

    private var totalVolume: Double {
        // WeightEntry je přesný zdroj - zahrnuje AI workout data
        let fromEntries = weightEntries.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
        if fromEntries > 0 { return fromEntries }
        // Fallback
        return completedSessions
            .flatMap { $0.exercises }
            .flatMap { $0.completedSets }
            .reduce(0) { $0 + $1.weightKg * Double($1.reps) }
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

    private var statsHeader: some View {
        HStack(spacing: 12) {
            statCard(title: "Tréninků", value: "\(completedSessions.count)", icon: "checkmark.circle.fill", color: .blue)
            statCard(title: "Celkem tun", value: formatKg(totalVolume), icon: "scalemass.fill", color: .orange)
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
                Text("Žádná data. Začni odcvičovat a sleduj svůj progres! 💪")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 32)
            } else {
                Chart(exerciseHistory, id: \.date) { entry in
                    LineMark(x: .value("Datum", entry.date), y: .value("Váha", entry.weight))
                        .foregroundStyle(.blue).lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Datum", entry.date), y: .value("Váha", entry.weight))
                        .foregroundStyle(.blue).symbolSize(40)
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
                Text("Ještě jsi neodcvičil žádný trénink. Hurá na to! 🏋️")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 32)
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
        // Výpočet objemu ze session WeightEntries (přesné pro AI workout)
        let sessionVolume = weightEntries
            .filter { $0.sessionId == session.id }
            .reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }

        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4).fill(Color.blue.opacity(0.8)).frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.plannedDay?.label ?? "Trénink")
                    .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                HStack(spacing: 12) {
                    Label("\(session.durationMinutes) min", systemImage: "clock")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                    if sessionVolume > 0 {
                        Label(formatKg(sessionVolume), systemImage: "scalemass")
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

    private func formatKg(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0f t", value / 1_000) }
        return String(format: "%.0f kg", value)
    }
}
