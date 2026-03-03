// VolumeChartView.swift
import SwiftUI
import Charts

struct VolumeRecord: Identifiable {
    let id = UUID()
    let date: Date
    let volumeKg: Double
}

struct VolumeChartView: View {
    let records: [VolumeRecord]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Týdenní objem")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            if records.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.1))
                    Text("Zatím žádná data")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
            } else {
                Chart(records) { record in
                    BarMark(
                        x: .value("Týden", record.date, unit: .weekOfYear),
                        y: .value("Objem (kg)", record.volumeKg)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.appGreenBadge, Color.appGreenBadge.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { value in
                        AxisValueLabel(format: .dateTime.week())
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.05))
                        if let volume = value.as(Double.self) {
                            AxisValueLabel {
                                Text("\(Int(volume / 1000))t")
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(20)
        .glassCardStyle(cornerRadius: 20)
    }
}
