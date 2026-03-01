// PlateCalculatorView.swift
// Agilní Fitness Trenér — Vizualizace a výpočet kotoučů na osu

import SwiftUI

struct PlateCalculatorView: View {
    let targetWeight: Double
    let barbellWeight: Double

    // Standardní váhy kotoučů
    private let availablePlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    private var calculatedPlates: [Double] {
        var remainingWeight = (targetWeight - barbellWeight) / 2.0
        var platesUsed: [Double] = []

        if remainingWeight <= 0 { return [] }

        for plate in availablePlates {
            while remainingWeight >= plate {
                platesUsed.append(plate)
                remainingWeight -= plate
            }
        }
        return platesUsed
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Naložit na osu")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if targetWeight <= barbellWeight {
                Text("Samotná osa (\(formatKg(barbellWeight)))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                HStack(alignment: .center, spacing: 2) {
                    
                    // Střed osy
                    Rectangle()
                        .fill(Color(white: 0.3))
                        .frame(width: 40, height: 12)
                    
                    // Rukáv osy
                    Rectangle()
                        .fill(Color(white: 0.5))
                        .frame(width: 10, height: 24)

                    // Kotouče
                    ForEach(Array(calculatedPlates.enumerated()), id: \.offset) { _, plate in
                        plateView(weight: plate)
                    }

                    // Konec osy
                    Rectangle()
                        .fill(Color(white: 0.5))
                        .frame(width: 30, height: 16)
                }
                .padding(.vertical, 12)
                
                // Soupis kotoučů
                HStack(spacing: 12) {
                    ForEach(Array(Set(calculatedPlates).sorted(by: >)), id: \.self) { plate in
                        let count = calculatedPlates.filter { $0 == plate }.count
                        HStack(spacing: 4) {
                            Text("\(count)×")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(formatKg(plate))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(colorForPlate(plate))
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    @ViewBuilder
    private func plateView(weight: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(colorForPlate(weight))
                .frame(width: thicknessForPlate(weight), height: heightForPlate(weight))
            
            // Text na větších kotoučích
            if weight >= 5 {
                Text(formatKg(weight))
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-90))
            }
        }
    }

    // MARK: - Dimensions & Colors (IPF / IWF Standard)
    private func heightForPlate(_ weight: Double) -> CGFloat {
        if weight >= 15 { return 100 }
        if weight >= 10 { return 80 }
        if weight >= 5 { return 60 }
        return 45
    }

    private func thicknessForPlate(_ weight: Double) -> CGFloat {
        switch weight {
        case 25: return 24
        case 20: return 20
        case 15: return 16
        case 10: return 12
        case 5: return 10
        case 2.5: return 8
        case 1.25: return 6
        default: return 10
        }
    }

    private func colorForPlate(_ weight: Double) -> Color {
        switch weight {
        case 25: return .red
        case 20: return .blue
        case 15: return .yellow
        case 10: return .green
        case 5: return .white
        case 2.5: return .black
        case 1.25: return .gray
        default: return .gray
        }
    }
    
    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.2f", value)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            PlateCalculatorView(targetWeight: 140, barbellWeight: 20)
            PlateCalculatorView(targetWeight: 82.5, barbellWeight: 20)
            PlateCalculatorView(targetWeight: 40, barbellWeight: 20)
            PlateCalculatorView(targetWeight: 20, barbellWeight: 20)
        }
        .padding()
    }
}
