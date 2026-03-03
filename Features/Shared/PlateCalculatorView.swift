// PlateCalculatorView.swift
// Agilní Fitness Trenér — Kalkulačka kotoučů pro naložení osy
//
// Vypočítá optimální kombinaci kotoučů pro zadanou váhu.

import SwiftUI

struct PlateCalculatorView: View {
    let targetWeight: Double
    let barbellWeight: Double
    
    // Standardní sada kotoučů (kg)
    private let availablePlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kalkulačka kotoučů")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Jak naložit na osu o váze \(barbellWeight.formatted()) kg")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.2))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            // Result Weight
            VStack(spacing: 4) {
                Text("\(targetWeight.formatted()) kg")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.blue)
                Text("Cílová váha")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            
            // Plates Visualization
            VStack(spacing: 16) {
                let calculation = calculatePlates()
                
                if calculation.isEmpty {
                    Text("Na osu o váze \(barbellWeight.formatted()) kg nic nakládat nemusíš.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                } else {
                    Text("Nalož na KAŽDOU stranu tyto kotouče:")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(calculation, id: \.weight) { plate in
                                plateCard(plate: plate.weight, count: plate.count)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            
            Spacer()
            
            // Tip
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Výpočet předpokládá symetrické naložení na obě strany osy.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.bottom, 24)
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.1).ignoresSafeArea())
    }
    
    private func plateCard(plate: Double, count: Int) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(colorForPlate(plate).opacity(0.15))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(colorForPlate(plate).opacity(0.35), lineWidth: 2)
                    )
                
                Text(plate.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", plate) : String(format: "%.2f", plate))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(colorForPlate(plate))
            }
            
            Text("\(count)×")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    private func colorForPlate(_ weight: Double) -> Color {
        switch weight {
        case 25: return .red
        case 20: return .blue
        case 15: return .yellow
        case 10: return .green
        case 5: return .white
        case 2.5: return .black // Or dark gray
        default: return .orange
        }
    }
    
    private func calculatePlates() -> [(weight: Double, count: Int)] {
        var remaining = (targetWeight - barbellWeight) / 2.0
        guard remaining > 0 else { return [] }
        
        var result: [(weight: Double, count: Int)] = []
        
        for plate in availablePlates {
            let count = Int(remaining / plate)
            if count > 0 {
                result.append((weight: plate, count: count))
                remaining -= Double(count) * plate
            }
        }
        
        return result
    }
}

#Preview {
    PlateCalculatorView(targetWeight: 82.5, barbellWeight: 20.0)
        .preferredColorScheme(.dark)
}
