// WorkoutCalendarView.swift
// Agilní Fitness Trenér — Heatmap Kalendář (GitHub Commit Style)

import SwiftUI

struct WorkoutCalendarView: View {
    let workoutDates: [Date]
    
    // Měsíce pro zobrazení
    private let calendar = Calendar.current
    private let today = Date()
    
    // Config: Zobrazíme posledních cca 12 týdnů (84 úkresů) po sloupcích (jeden sloupec je týden)
    private let columns = Array(repeating: GridItem(.fixed(14), spacing: 4), count: 12)
    private let rows = 7 // Pondělí až Neděle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aktivita (poslední 3 měsíce)")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    
                    // Názvy dní (Po, St, Pá)
                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(0..<7) { row in
                            dayLabel(for: row)
                                .frame(height: 14)
                        }
                    }
                    .padding(.top, 22) // Zarovnání kvůli štítkům měsíců nahoře
                    
                    // Heatmap mřížka
                    VStack(alignment: .leading, spacing: 4) {
                        // Month Labels (Zjednodušeno pro MVP: jen pevná mezera)
                        HStack(spacing: 0) {
                            Text("Posledních 12 týdnů")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                            Spacer()
                        }
                        .frame(height: 14)
                        
                        LazyHGrid(rows: Array(repeating: GridItem(.fixed(14), spacing: 4), count: 7), spacing: 4) {
                            // Vygenerujeme grid zleva doprava (starší -> novější)
                            ForEach(heatmapDays(), id: \.date) { day in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(color(for: day))
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func dayLabel(for row: Int) -> some View {
        // Zobrazíme P, S, P (Pondělí, Středa, Pátek) - 0 = Po, 2 = St, 4 = Pá
        let text: String
        switch row {
        case 0: text = "Po"
        case 2: text = "St"
        case 4: text = "Pá"
        default: text = ""
        }
        return Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.4))
    }
    
    struct HeatmapDay {
        let date: Date
        let hasWorkout: Bool
    }
    
    private func heatmapDays() -> [HeatmapDay] {
        var days: [HeatmapDay] = []
        
        // Zjistíme konec (dnešní konec týdne, např. neděle)
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        
        // Jdeme zpět 11 týdnů + aktuální = 12 týdnů (84 dní)
        let weeksCount = 12
        let daysCount = weeksCount * 7
        
        // Posuneme začátek na pondělí před 11 týdny
        guard let startDate = calendar.date(byAdding: .day, value: -(daysCount - 7), to: currentWeekStart) else { return [] }
        
        // Množina dnů, kdy se cvičilo (normalizováno jen na startOfDay)
        let workoutSet = Set(workoutDates.map { calendar.startOfDay(for: $0) })
        
        // Vytvoříme pole den po dni
        for i in 0..<daysCount {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                let pDate = calendar.startOfDay(for: date)
                days.append(HeatmapDay(date: pDate, hasWorkout: workoutSet.contains(pDate)))
            }
        }
        
        return days
    }
    
    private func color(for day: HeatmapDay) -> Color {
        if day.date > today { return .clear } // Budoucnost nenačrtáváme tiskem, ale necháme prázdnou/neviditelnou, nebo slabou
        
        if day.hasWorkout {
            return AppColors.primaryAccent // Modrá pro cvičení
        } else {
            return Color.white.opacity(0.08) // Šedá pro necvičení
        }
    }
}
