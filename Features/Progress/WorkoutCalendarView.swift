// WorkoutCalendarView.swift
// GitHub-style monthly heatmap for workouts

import SwiftUI

struct WorkoutCalendarView: View {
    let workoutDates: [Date]
    let accentColor: Color
    
    // Získáme pole dnů v aktuálním měsíci, zarovnané na týdny
    private var daysInMonth: [Date?] {
        let calendar = Calendar.mondayStart
        guard let monthInterval = calendar.dateInterval(of: .month, for: .now) else { return [] }
        
        let firstDayOfMonth = monthInterval.start
        let weekdayOfFirst = calendar.component(.weekday, from: firstDayOfMonth) 
        // 1=Neděle, 2=Pondělí... převedeme na 0=Pondělí... 6=Neděle
        let offset = (weekdayOfFirst + 5) % 7
        
        var days: [Date?] = Array(repeating: nil, count: offset)
        
        let numberOfDays = calendar.range(of: .day, in: .month, for: .now)?.count ?? 30
        for day in 0..<numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        // Zarovnání do plného obdélníku (aby grid vypadal dobře)
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(Date.now.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                HStack(spacing: 4) {
                    Text("Méně").font(.system(size: 10))
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.05)).frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(accentColor.opacity(0.4)).frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2).fill(accentColor).frame(width: 10, height: 10)
                    Text("Více").font(.system(size: 10))
                }
                .foregroundStyle(.white.opacity(0.3))
            }
            
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<daysInMonth.count, id: \.self) { index in
                    if let date = daysInMonth[index] {
                        let isToday = Calendar.mondayStart.isDateInToday(date)
                        let hasWorkout = workoutDates.contains { Calendar.mondayStart.isDate($0, inSameDayAs: date) }
                        
                        Circle()
                            .fill(hasWorkout ? accentColor : Color.white.opacity(0.05))
                            .frame(height: 38) // Větší kolečka pro mobilní UI
                            .overlay(
                                Circle()
                                    .stroke(isToday ? .white : .clear, lineWidth: 2)
                            )
                            .overlay {
                                Text("\(Calendar.mondayStart.component(.day, from: date))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(hasWorkout ? .black : .white.opacity(0.2))
                            }
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}
