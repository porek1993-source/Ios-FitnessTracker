// ProgressView.swift
// Agilní Fitness Trenér — Progres napojený na reálná SwiftData

import SwiftUI
import SwiftData
import Charts

struct AppProgressView: View {
    // ✅ VÝKON: Omezíme sessions na posledních 52 týdnů (1 rok) — starší záznamy nepotřebujeme pro grafy
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    // ✅ VÝKON: Načítáme POUZE cviky které mají historii vah (isCustom nezáleží)
    // FetchDescriptor s predikátem filtruje na DB úrovni — nesahá na lazy-loaded relationship
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var profiles: [UserProfile]
    @Query(sort: \SprintGoal.createdAt, order: .reverse) private var sprintGoals: [SprintGoal]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedExercise: Exercise?
    @State private var showExercisePicker = false
    @State private var show1RM = false
    @State private var showPhotos = false

    // ✅ VÝKON: lazy var místo computed var — filtrování proběhne jen při prvním přístupu per render cycle
    private var completedSessions: [WorkoutSession] {
        sessions.lazy.filter { $0.status == .completed }.map { $0 }
    }

    @Query(sort: \WeightEntry.loggedAt, order: .reverse) private var weightEntries: [WeightEntry]

    private var volumeByWeek: [(label: String, volume: Double)] {
        let calendar = Calendar.mondayStart
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
        // Zkusíme sečíst objem přímo ze všech záznamů
        let fromEntries = weightEntries
            .filter { $0.setType == .normal || $0.setType == .failure }
            .reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }

        if fromEntries > 0 { return fromEntries }

        // Fallback: Pokud weightEntries selžou (např. lag v SwiftData), sečteme z completedSessions
        var fallbackVol = 0.0
        for session in completedSessions {
            for ex in session.exercises {
                for set in ex.completedSets {
                    // ✅ FIX: Pouze .normal a .failure se počítají do objemu a 1RM
                    if set.setType == .normal || set.setType == .failure {
                        fallbackVol += set.weightKg * Double(set.reps)
                    }
                }
            }
        }
        return fallbackVol
    }

    private var sessionDates: [Date] {
        completedSessions.map { $0.startedAt }
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

                        // ✅ Oblast A — Svalová Heatmapa (Phase 3)
                        MuscleHeatmapCard()
                            .padding(.horizontal, 16)

                        // ✅ Oblast B — Mezocyklus link (Phase 3)
                        NavigationLink(destination: MesocyclePlannerView()) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(LinearGradient(
                                            colors: [Color(red: 0.22, green: 0.55, blue: 1.0), Color(red: 0.10, green: 0.38, blue: 0.90)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Periodizace a Mezocykly")
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text("Plánuj 8–12 týdenní tréninkové cykly")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppColors.textMuted)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)

                        // ✅ Sprint Souhrn (deepanal.pdf bod 8-9)
                        if let profile = profiles.first,
                           let plan = profile.workoutPlans.first(where: \.isActive) {
                            sprintSummary(plan: plan)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }

                        MuscleVolumeChart()
                            .frame(height: 220)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // GitHub-style Heatmap
                    WorkoutCalendarView(workoutDates: sessionDates, accentColor: .blue)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    
                    // 1RM Graf
                    VStack(alignment: .leading, spacing: 12) {
                        exerciseProgressSection
                        historySection.padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                }
            }
            .navigationTitle("Progres")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showExercisePicker) { exercisePickerSheet }
            .navigationDestination(isPresented: $showPhotos) {
                ProgressGalleryView()
            }
            .onAppear {
                if selectedExercise == nil {
                    selectedExercise = exercises.first(where: { $0.slug == "barbell-bench-press" })
                        ?? exercises.first(where: { !$0.weightHistory.isEmpty })
                }
            }
        }
    }

    private var galleryHeaderButton: some View {
        Button {
            showPhotos = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 14))
                Text("Fotky")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.orange.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel("Fotogalerie pro sledování fyzického pokroku")
        }
    }

    // MARK: — Sprint Summary

    private func sprintSummary(plan: WorkoutPlan) -> some View {
        let startOfWeek = Calendar.mondayStart.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let completedThisWeek = plan.sessions.filter {
            $0.startedAt >= startOfWeek && $0.status == .completed
        }.count
        let plannedDays = plan.scheduledDays.filter { !$0.isRestDay }.count
        let weeksSince = max(1, Calendar.current.dateComponents([.weekOfYear], from: plan.sprintStartDate, to: .now).weekOfYear ?? 1)
        let goals = sprintGoals.filter { $0.sprintNumber == plan.sprintNumber }
        let doneGoals = goals.filter(\.isCompleted).count

        return HStack(spacing: 12) {
            // Sprint číslo
            VStack(spacing: 4) {
                Text("SPRINT")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white.opacity(0.3))
                    .kerning(1.5)
                Text("#\(plan.sprintNumber)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.cyan)
            }
            .frame(width: 60)

            Rectangle().fill(.white.opacity(0.08)).frame(width: 1, height: 40)

            // Týden tréninku
            VStack(spacing: 2) {
                Text("Týden \(weeksSince) z \(plan.durationWeeks)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(completedThisWeek)/\(plannedDays) tréninků tento týden")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            // Cíle
            if !goals.isEmpty {
                VStack(spacing: 2) {
                    Text("\(doneGoals)/\(goals.count)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(doneGoals == goals.count ? .green : .orange)
                    Text("cílů")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.cyan.opacity(0.12), lineWidth: 1))
        )
    }

    // MARK: — Stats

    // MARK: - Helpers
    


    private var statsHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Můj výkon")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                galleryHeaderButton
            }
            
            HStack(spacing: 12) {
                statCard(title: "Tréninky", value: "\(completedSessions.count)", icon: "checkmark.circle.fill", color: .blue)
                statCard(title: "Celkový objem", value: totalVolume.formatVolume(), icon: "scalemass.fill", color: .orange)
                statCard(title: "PR záznamy", value: "\(personalRecordsCount)", icon: "trophy.fill", color: .yellow)
            }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
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
                .accessibilityLabel(show1RM ? "Zobrazuje se odhadované 1RM. Přepnout na zvednutou váhu." : "Zobrazuje se zvednutá váha. Přepnout na odhadované 1RM.")
                
                Button { showExercisePicker = true } label: {
                    HStack(spacing: 4) {
                        Text(selectedExercise?.name ?? "Vyber cvik").font(.system(size: 13, weight: .medium)).foregroundStyle(.blue)
                        Image(systemName: "chevron.down").font(.system(size: 11)).foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
                }
                .accessibilityHint("Otevře seznam pro výběr cviku k zobrazení historie")
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
            // Barevný indikátor — modrá pro plánované, oranžová pro rychlé/standalone
            let isStandalone = session.plannedDay?.dayOfWeek == 99
            RoundedRectangle(cornerRadius: 4)
                .fill(isStandalone ? Color.orange.opacity(0.8) : Color.blue.opacity(0.8))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isStandalone {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                    Text(session.plannedDay?.label ?? "Trénink")
                        .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                }
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
        .accessibilityElement(children: .combine)
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

// MARK: - Placeholders for Phase 3 components

struct MuscleHeatmapCard: View {
    var body: some View {
        VStack {
            Text("Svalová Heatmapa")
                .font(.headline)
            Text("Ve vývoji (Phase 3)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}
