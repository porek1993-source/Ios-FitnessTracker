// RecoveryInsightsView.swift
// Agilní Fitness Trenér — Přehled zotavení a HealthKit metrik

import SwiftUI
import SwiftData
import Charts

struct RecoveryInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthMetricsSnapshot.date, order: .reverse) private var allSnapshots: [HealthMetricsSnapshot]
    
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
                        
                        // 4. Týdenní hodnocení (Placeholder nebo na vyžádání)
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
            }
            .navigationTitle("Zotavení & Zdraví")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                print("Chyba generování reportu: \(error)")
                // Místo alertu jen tisk do konzole pro zjednodušení v prototypu
            }
            isGeneratingReport = false
        }
    }
}

// MARK: - Daily Insight Card

struct DailyInsightCard: View {
    let snapshot: HealthMetricsSnapshot?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("AI Daily Insight")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let score = snapshot?.readinessScore {
                    Text("\(Int(score))/100")
                        .font(.subheadline.bold())
                        .foregroundColor(scoreColor(score))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(scoreColor(score).opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            Text(generateInsightText())
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(4)
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
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
    
    private func generateInsightText() -> String {
        guard let snap = snapshot else {
            return "Zatím nemám dostatek dat. Až si v noci nasadíš Apple Watch, zítra ti vyhodnotím připravenost na trénink."
        }
        
        // Jednoduchá logika pro demo (v budoucnu to může tahat Gemini)
        if (snap.readinessScore ?? 100) < 60 {
            return "Tvé HRV je dnes snížené a spánkové skóre ukazuje únavu. Doporučuji dnes zařadit spíše lehčí izolované cviky nebo aktivní regeneraci. Těžké dřepy si necháme na jindy."
        } else {
            return "Tělo je skvěle zregenerované! Spánek i hodnoty srdce jsou v optimu. Dnes je ideální den na překonávání osobních rekordů."
        }
    }
}

// MARK: - Charts

struct SleepChartCard: View {
    let data: [HealthMetricsSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spánek (Posledních 7 dní)")
                .font(.headline)
                .foregroundColor(.white)
            
            if data.isEmpty {
                Text("Žádná data")
                    .foregroundColor(.gray)
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
                .foregroundColor(.white)
            
            if data.isEmpty {
                Text("Žádná data")
                    .foregroundColor(.gray)
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
                    .foregroundColor(.white)
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(.blue)
                } else if report == nil {
                    Button(action: onGenerate) {
                        Text("Generovat")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
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
                        .foregroundColor(.white.opacity(0.9))
                    
                    ReportSection(title: "Co se povedlo", text: r.praise, icon: "hand.thumbsup.fill", color: .green)
                    ReportSection(title: "Kde přidat", text: r.mistakes, icon: "exclamationmark.triangle.fill", color: .orange)
                    ReportSection(title: "Motivace do dalšího týdne", text: r.motivation, icon: "flame.fill", color: .red)

                }
            } else if !isLoading {
                Text("Získej detailní AI rozbor svých tréninků, spánku a progresu od trenéra.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
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
                    .foregroundColor(color)
                    .font(.caption)
                Text(title.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(color)
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }
}
