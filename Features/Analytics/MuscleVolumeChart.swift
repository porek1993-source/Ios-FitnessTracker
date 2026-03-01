// MuscleVolumeChart.swift
// Agilní Fitness Trenér — Analytika svalového objemu

import SwiftUI
import Charts
import SwiftData

public struct MuscleVolumeChart: View {
    @Query(sort: \WeightEntry.loggedAt, order: .reverse) private var weightEntries: [WeightEntry]

    public init() {}

    private var weeklyVolume: [(group: MuscleGroup, sets: Int)] {
        let calendar = Calendar.mondayStart
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: .now) else { return [] }
        
        var counts: [MuscleGroup: Int] = [:]
        
        // Zpracování úspěšných sérií za posledních 7 dní
        for entry in weightEntries where entry.wasSuccessful && entry.loggedAt >= sevenDaysAgo {
            // Bezpečné získání hlavní svalové partie (předpokládáme, že WeightEntry má vazbu na Exercise)
            if let group = entry.exercise?.primaryMuscleGroup {
                counts[group, default: 0] += 1
            } else if let groupName = entry.exercise?.muscle_group, let group = MuscleGroup(rawValue: groupName) {
                // Fallback pro parsování přímo přes raw string, pokud neexistuje property primaryMuscleGroup
                counts[group, default: 0] += 1
            }
        }
        
        // Seřadit sestupně podle počtu sérií
        return counts.map { (group: $0.key, sets: $0.value) }.sorted { $0.sets > $1.sets }
    }

    private func colorFor(sets: Int) -> Color {
        if sets < 10 {
            return .blue // Udržovací / Lehký trénink
        } else if sets <= 20 {
            return .green // Optimální růst (Hypertrofie)
        } else {
            return .red // Riziko přetrénování
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Objem na partii")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Série za posledních 7 dní")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                
                // Legenda
                HStack(spacing: 8) {
                    legendDot(color: .blue, text: "<10 (Stagnace)")
                    legendDot(color: .green, text: "10-20 (Růst)")
                    legendDot(color: .red, text: ">20 (Riziko)")
                }
            }
            
            if weeklyVolume.isEmpty {
                EmptyStateView(
                    icon: "chart.bar.fill",
                    title: "Zatím žádná data",
                    message: "Během posledních 7 dnů nemáš žádné dokončené série.",
                    iconColor: .white.opacity(0.3)
                )
                .frame(height: 160)
            } else {
                Chart(weeklyVolume, id: \.group) { item in
                    BarMark(
                        x: .value("Partie", item.group.displayName),
                        y: .value("Série", item.sets)
                    )
                    .foregroundStyle(colorFor(sets: item.sets).gradient)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(Color.white.opacity(0.7))
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(Color.white.opacity(0.5))
                            .font(.system(size: 10))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.white.opacity(0.1))
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
        }
    }
}
