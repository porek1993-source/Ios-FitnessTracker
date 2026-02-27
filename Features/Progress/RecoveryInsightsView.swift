// RecoveryInsightsView.swift
// Agilní Fitness Trenér — Prémiový přehled zotavení a HealthKit metrik

import SwiftUI
import SwiftData
import Charts

struct RecoveryInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @Query(sort: \HealthMetricsSnapshot.date, order: .reverse) private var allSnapshots: [HealthMetricsSnapshot]
    @State private var isSyncing = false
    
    private var last7Days: [HealthMetricsSnapshot] {
        Array(allSnapshots.prefix(7).reversed())
    }
    
    @State private var weeklyReport: WeeklyReportResult?
    @State private var isGeneratingReport = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // 1. Dnešní AI Insight
                        if let today = last7Days.last {
                            DailyInsightCard(snapshot: today)
                        } else {
                            DailyInsightCard(snapshot: nil)
                        }
                        
                        // 2. Graf Spánku
                        SleepChartCard(data: last7Days)
                        
                        // 3. Graf HRV
                        HRVChartCard(data: last7Days)
                        
                        // 4. Graf klidového tepu
                        RestingHRChartCard(data: last7Days)
                        
                        // 5. Týdenní hodnocení
                        WeeklyReportCard(
                            report: weeklyReport,
                            isLoading: isGeneratingReport,
                            onGenerate: generateReport
                        )
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                
                // Loading overlay
                if isSyncing {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            ProgressView().tint(AppColors.primaryAccent)
                            Text("Synchronizuji Health data...")
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(AppColors.secondaryBg)
                                .shadow(color: .black.opacity(0.4), radius: 12)
                        )
                        .padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Zotavení & Zdraví")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                withAnimation { isSyncing = true }
                await HealthBackgroundManager.shared.performForegroundSync(healthKit: healthKit)
                withAnimation { isSyncing = false }
            }
        }
    }
    
    private func generateReport() {
        guard let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first else { return }
        
        isGeneratingReport = true
        let service = WeeklyReportService(modelContext: modelContext)
        
        Task {
            do {
                let result = try await service.generateWeeklyReport(for: profile)
                self.weeklyReport = result
            } catch {
                AppLogger.error("RecoveryInsightsView: Chyba generování reportu: \(error)")
            }
            isGeneratingReport = false
        }
    }
}

// MARK: - Daily Insight Card

struct DailyInsightCard: View {
    let snapshot: HealthMetricsSnapshot?
    @Environment(\.modelContext) private var modelContext
    @State private var insightText: String = "Analyzuji data..."
    @State private var isLoading = false
    @AppStorage("dailyInsightText") private var cachedInsight: String = ""
    @AppStorage("dailyInsightDate") private var cachedDate: String = ""

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppColors.primaryAccent)
                        .font(.system(size: 16))
                    Text("AI Daily Insight")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                if isLoading {
                    ProgressView().tint(AppColors.primaryAccent).scaleEffect(0.7)
                } else if let score = snapshot?.readinessScore {
                    Text("\(Int(score))/100")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(score))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(scoreColor(score).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            
            Text(insightText)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCardStyle()
        .task {
            if cachedDate == todayKey && !cachedInsight.isEmpty {
                insightText = cachedInsight
                return
            }
            await fetchInsight()
        }
    }
    
    private func fetchInsight() async {
        guard !isLoading else { return }
        isLoading = true
        guard let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first else {
            insightText = "Nenalezen profil."
            isLoading = false
            return
        }
        let service = WeeklyReportService(modelContext: modelContext)
        do {
            let text = try await service.generateDailyInsight(for: profile, snapshot: snapshot)
            await MainActor.run {
                insightText = text
                cachedInsight = text
                cachedDate = todayKey
                isLoading = false
            }
        } catch {
            await MainActor.run {
                insightText = "Nepodařilo se vygenerovat insight. Dneska to ale dáme!"
                isLoading = false
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 75 { return AppColors.success }
        if score >= 50 { return AppColors.warning }
        return AppColors.error
    }
}

// MARK: - Empty State Fallback

private struct ChartEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    let iconColor: Color
    
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.10))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundStyle(iconColor.opacity(0.6))
            }
            
            Text(title)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
            
            Text(subtitle)
                .font(AppTypography.footnote)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Charts

struct SleepChartCard: View {
    let data: [HealthMetricsSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Spánek", systemImage: "moon.fill")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                if let latest = data.last?.sleepDurationHours {
                    Text(String(format: "%.1fh", latest))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.indigo)
                }
            }
            
            Text("Posledních 7 dní")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
            
            if data.isEmpty || data.allSatisfy({ $0.sleepDurationHours == nil }) {
                ChartEmptyState(
                    icon: "moon.zzz.fill",
                    title: "Žádná data o spánku",
                    subtitle: "Připoj Apple Watch nebo zadej spánek v Zdraví pro sledování kvality odpočinku.",
                    iconColor: .indigo
                )
            } else {
                Chart(data) { item in
                    AreaMark(
                        x: .value("Den", item.date, unit: .day),
                        y: .value("Hodin", item.sleepDurationHours ?? 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.35), Color.indigo.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    LineMark(
                        x: .value("Den", item.date, unit: .day),
                        y: .value("Hodin", item.sleepDurationHours ?? 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.indigo)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    
                    PointMark(
                        x: .value("Den", item.date, unit: .day),
                        y: .value("Hodin", item.sleepDurationHours ?? 0)
                    )
                    .foregroundStyle(Color.indigo)
                    .symbolSize(20)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine().foregroundStyle(AppColors.border)
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(AppColors.border)
                        AxisValueLabel().foregroundStyle(AppColors.textTertiary)
                    }
                }
                
                // Doporučená zóna
                HStack(spacing: 6) {
                    Circle().fill(Color.indigo.opacity(0.5)).frame(width: 6, height: 6)
                    Text("Doporučeno: 7–9 hodin")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .glassCardStyle()
    }
}

struct HRVChartCard: View {
    let data: [HealthMetricsSnapshot]
    
    private let chartColor = Color(red: 0.30, green: 0.78, blue: 0.95) // Cyan-blue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("HRV", systemImage: "waveform.path.ecg")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                if let latest = data.last?.heartRateVariabilityMs {
                    Text("\(Int(latest)) ms")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(chartColor)
                }
            }
            
            Text("Variabilita srdeční frekvence · 7 dní")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
            
            if data.isEmpty || data.allSatisfy({ $0.heartRateVariabilityMs == nil }) {
                ChartEmptyState(
                    icon: "waveform.path.ecg",
                    title: "Žádná HRV data",
                    subtitle: "HRV měří tvoji schopnost zotavení. Nos Apple Watch přes noc pro automatické měření.",
                    iconColor: chartColor
                )
            } else {
                Chart(data) { item in
                    AreaMark(
                        x: .value("Den", item.date, unit: .day),
                        y: .value("HRV", item.heartRateVariabilityMs ?? 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartColor.opacity(0.30), chartColor.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    LineMark(
                        x: .value("Den", item.date, unit: .day),
                        y: .value("HRV", item.heartRateVariabilityMs ?? 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(chartColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    
                    PointMark(
                        x: .value("Den", item.date, unit: .day),
                        y: .value("HRV", item.heartRateVariabilityMs ?? 0)
                    )
                    .foregroundStyle(chartColor)
                    .symbolSize(20)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine().foregroundStyle(AppColors.border)
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(AppColors.border)
                        AxisValueLabel().foregroundStyle(AppColors.textTertiary)
                    }
                }
                
                HStack(spacing: 6) {
                    Circle().fill(chartColor.opacity(0.5)).frame(width: 6, height: 6)
                    Text("Vyšší HRV = lepší zotavení")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .glassCardStyle()
    }
}

// MARK: - Resting HR Chart

struct RestingHRChartCard: View {
    let data: [HealthMetricsSnapshot]
    
    private let chartColor = Color(red: 0.92, green: 0.35, blue: 0.52) // Rose pink
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Klidový tep", systemImage: "heart.fill")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                if let latest = data.last?.restingHeartRate {
                    Text("\(Int(latest)) BPM")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(chartColor)
                }
            }
            
            Text("Posledních 7 dní")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
            
            if data.isEmpty || data.allSatisfy({ $0.restingHeartRate == nil }) {
                ChartEmptyState(
                    icon: "heart.slash.fill",
                    title: "Žádná data o klidovém tepu",
                    subtitle: "Klidový tep ukazuje kardiovaskulární zdatnost. Apple Watch ho měří automaticky.",
                    iconColor: chartColor
                )
            } else {
                Chart(data) { item in
                    if let rhr = item.restingHeartRate {
                        AreaMark(
                            x: .value("Den", item.date, unit: .day),
                            y: .value("BPM", rhr)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [chartColor.opacity(0.25), chartColor.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        LineMark(
                            x: .value("Den", item.date, unit: .day),
                            y: .value("BPM", rhr)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(chartColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        
                        PointMark(
                            x: .value("Den", item.date, unit: .day),
                            y: .value("BPM", rhr)
                        )
                        .foregroundStyle(chartColor)
                        .symbolSize(24)
                        .annotation(position: .top, spacing: 6) {
                            Text("\(Int(rhr))")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine().foregroundStyle(AppColors.border)
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(AppColors.border)
                        AxisValueLabel().foregroundStyle(AppColors.textTertiary)
                    }
                }
                
                HStack(spacing: 6) {
                    Circle().fill(chartColor.opacity(0.5)).frame(width: 6, height: 6)
                    Text("Nižší klidový tep = lepší kondice")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .glassCardStyle()
    }
}

// MARK: - Weekly Report Card

struct WeeklyReportCard: View {
    let report: WeeklyReportResult?
    let isLoading: Bool
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("iKorbovo týdenní zhodnocení", systemImage: "doc.text.magnifyingglass")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                if isLoading {
                    ProgressView().tint(AppColors.primaryAccent)
                } else if report == nil {
                    Button(action: onGenerate) {
                        Text("Generovat")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(AppColors.accentGradient)
                            )
                    }
                }
            }
            
            if let r = report {
                VStack(alignment: .leading, spacing: 12) {
                    Text(r.summary)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                    
                    ReportSection(title: "Co se povedlo", text: r.praise, icon: "hand.thumbsup.fill", color: AppColors.success)
                    ReportSection(title: "Kde přidat", text: r.mistakes, icon: "exclamationmark.triangle.fill", color: AppColors.warning)
                    ReportSection(title: "Motivace do dalšího týdne", text: r.motivation, icon: "flame.fill", color: AppColors.error)
                }
            } else if !isLoading {
                Text("Získej detailní AI rozbor svých tréninků, spánku a progresu od trenéra.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .glassCardStyle()
    }
}

struct ReportSection: View {
    let title: String
    let text: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 11))
                Text(title.uppercased())
                    .font(AppTypography.caption)
                    .foregroundStyle(color)
                    .kerning(0.5)
            }
            Text(text)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }
}
