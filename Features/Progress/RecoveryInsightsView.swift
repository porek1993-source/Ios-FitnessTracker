// RecoveryInsightsView.swift
// Agilní Fitness Trenér — Přehled zotavení a HealthKit metrik

import SwiftUI
import SwiftData
import Charts

struct RecoveryInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @Query(sort: \HealthMetricsSnapshot.date, order: .reverse) private var allSnapshots: [HealthMetricsSnapshot]
    @State private var isSyncing = false
    
    // Načteme jen 7 posledních dnů pro grafy
    private var last7Days: [HealthMetricsSnapshot] {
        Array(allSnapshots.prefix(7).reversed()) // Od nejstaršího po nejnovější pro graf
    }
    
    @State private var weeklyReport: WeeklyReportResult?
    @State private var isGeneratingReport = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // 1. Dnešní AI Insight
                        if let today = last7Days.last {
                            DailyInsightCard(snapshot: today)
                        } else {
                            DailyInsightCard(snapshot: nil) // Prázdný stav
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
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                
                // Loading overlay při syncu
                if isSyncing {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            ProgressView().tint(.blue)
                            Text("Synchronizuji Health data...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                                .shadow(color: .black.opacity(0.3), radius: 10)
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
                // Okamžitý sync při otevření, aby byly grafy aktuální
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
                // Místo alertu jen tisk do konzole pro zjednodušení v prototypu
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
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text("AI Daily Insight")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if isLoading {
                    ProgressView().tint(.yellow).scaleEffect(0.7)
                } else if let score = snapshot?.readinessScore {
                    Text("\(Int(score))/100")
                        .font(.subheadline.bold())
                        .foregroundStyle(scoreColor(score))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(scoreColor(score).opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            Text(insightText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .task {
            // Použij cache pokud je dnešní
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
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
}

// MARK: - Charts

struct SleepChartCard: View {
    let data: [HealthMetricsSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spánek (Posledních 7 dní)")
                .font(.headline)
                .foregroundStyle(.white)
            
            if data.isEmpty {
                Text("Žádná data")
                    .foregroundStyle(.gray)
                    .frame(height: 150)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Den", item.date, unit: .day),
                        y: .value("Hodin", item.sleepDurationHours ?? 0)
                    )
                    .foregroundStyle(Color.indigo.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel().foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct HRVChartCard: View {
    let data: [HealthMetricsSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Variabilita srdeční frekvence (HRV)")
                .font(.headline)
                .foregroundStyle(.white)
            
            if data.isEmpty {
                Text("Žádná data")
                    .foregroundStyle(.gray)
                    .frame(height: 150)
            } else {
                Chart(data) { item in
                    LineMark(
                        x: .value("Den", item.date, unit: .day),
                        y: .value("HRV (ms)", item.heartRateVariabilityMs ?? 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.red.gradient)
                    .symbol(Circle())
                    
                    AreaMark(
                        x: .value("Den", item.date, unit: .day),
                        y: .value("HRV (ms)", item.heartRateVariabilityMs ?? 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(
                        colors: [.red.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel().foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Resting HR Chart

struct RestingHRChartCard: View {
    let data: [HealthMetricsSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Klidový tep (Posledních 7 dní)")
                .font(.headline)
                .foregroundStyle(.white)
            
            if data.isEmpty || data.allSatisfy({ $0.restingHeartRate == nil }) {
                Text("Žádná data")
                    .foregroundStyle(.gray)
                    .frame(height: 150)
            } else {
                Chart(data) { item in
                    if let rhr = item.restingHeartRate {
                        LineMark(
                            x: .value("Den", item.date, unit: .day),
                            y: .value("BPM", rhr)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.pink.gradient)
                        .symbol(Circle())
                        
                        PointMark(
                            x: .value("Den", item.date, unit: .day),
                            y: .value("BPM", rhr)
                        )
                        .foregroundStyle(.pink)
                        .annotation(position: .top, spacing: 4) {
                            Text("\(Int(rhr))")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel().foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
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
                Text("Jakubovo týdenní zhodnocení")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(.blue)
                } else if report == nil {
                    Button(action: onGenerate) {
                        Text("Generovat")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            
            if let r = report {
                VStack(alignment: .leading, spacing: 12) {
                    Text(r.summary)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                    
                    ReportSection(title: "Co se povedlo", text: r.praise, icon: "hand.thumbsup.fill", color: .green)
                    ReportSection(title: "Kde přidat", text: r.mistakes, icon: "exclamationmark.triangle.fill", color: .orange)
                    ReportSection(title: "Motivace do dalšího týdne", text: r.motivation, icon: "flame.fill", color: .red)

                }
            } else if !isLoading {
                Text("Získej detailní AI rozbor svých tréninků, spánku a progresu od trenéra.")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
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
                    .font(.caption)
                Text(title.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }
}
