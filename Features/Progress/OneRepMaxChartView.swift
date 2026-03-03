// OneRepMaxChartView.swift
import SwiftUI
import Charts

struct MaxRecord: Identifiable {
    let id = UUID()
    let date: Date
    let exercise: String
    let weight: Double
}

struct OneRepMaxChartView: View {
    let records: [MaxRecord]
    
    @State private var selectedExercise: String = "Benchpress"
    private let exercises = ["Benchpress", "Dřep", "Mrtvý tah"]
    
    private var filteredRecords: [MaxRecord] {
        records.filter { $0.exercise == selectedExercise }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Vývoj 1RM")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Picker("Cvik", selection: $selectedExercise) {
                    ForEach(exercises, id: \.self) { exercise in
                        Text(exercise).tag(exercise)
                    }
                }
                .pickerStyle(.menu)
                .tint(.appPrimaryAccent)
            }
            
            if filteredRecords.isEmpty {
                EmptyStateView.oneRepMax()
                    .frame(height: 200)
            } else {
                Chart(filteredRecords) { record in
                    LineMark(
                        x: .value("Datum", record.date),
                        y: .value("Váha (kg)", record.weight)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.appPrimaryAccent)
                    .symbol {
                        Circle()
                            .fill(Color.appPrimaryAccent)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.appBackground, lineWidth: 2))
                    }
                    
                    AreaMark(
                        x: .value("Datum", record.date),
                        yStart: .value("Min", filteredRecords.map(\.weight).min() ?? 0),
                        yEnd: .value("Max", record.weight)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.appPrimaryAccent.opacity(0.3),
                                Color.appPrimaryAccent.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.05))
                        AxisValueLabel(format: .dateTime.day().month())
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.05))
                        if let weight = value.as(Double.self) {
                            AxisValueLabel("\(Int(weight)) kg")
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(20)
        .glassCardStyle(cornerRadius: 20)
    }
}
