// WorkoutCalendarView.swift
// GitHub-style monthly heatmap for workouts — navigovatelný po měsících

import SwiftUI

struct WorkoutCalendarView: View {
    let workoutDates: [Date]
    let accentColor: Color

    @State private var monthOffset: Int = 0   // 0 = aktuální měsíc, -1 = minulý, +1 = příští

    private var displayedMonth: Date {
        Calendar.mondayStart.date(byAdding: .month, value: monthOffset, to: .now) ?? .now
    }

    private var isCurrentMonth: Bool { monthOffset == 0 }

    // Vrací dny zobrazovaného měsíce zarovnané na týdny (pondělí = první sloupec)
    private var daysInMonth: [Date?] {
        let calendar = Calendar.mondayStart
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }

        let firstDay = monthInterval.start
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay)
        let offset = (weekdayOfFirst + 5) % 7   // Pondělí → offset 0

        var days: [Date?] = Array(repeating: nil, count: offset)

        let numberOfDays = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
        for day in 0..<numberOfDays {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDay) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Hlavička s navigací ──────────────────────────────────────────
            HStack {
                Button(action: { withAnimation(.spring(response: 0.35)) { monthOffset -= 1 } }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .contentTransition(.numericText())

                Spacer()

                Button(action: { withAnimation(.spring(response: 0.35)) { monthOffset += 1 } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isCurrentMonth ? .white.opacity(0.15) : .white.opacity(0.55))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(isCurrentMonth ? 0.02 : 0.06)))
                }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth)   // Nelze přejít do budoucnosti
            }

            // ── Zkratky dní (Po–Ne) ─────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(["Po", "Út", "St", "Čt", "Pá", "So", "Ne"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.25))
                        .frame(maxWidth: .infinity)
                }
            }

            // ── Mřížka dnů ──────────────────────────────────────────────────
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<daysInMonth.count, id: \.self) { index in
                    if let date = daysInMonth[index] {
                        let isToday = Calendar.mondayStart.isDateInToday(date)
                        let hasWorkout = workoutDates.contains {
                            Calendar.mondayStart.isDate($0, inSameDayAs: date)
                        }
                        let isFuture = date > Date.now

                        Circle()
                            .fill(hasWorkout ? accentColor : Color.white.opacity(isFuture ? 0.02 : 0.05))
                            .frame(height: 38)
                            .overlay(
                                Circle().stroke(isToday ? .white : .clear, lineWidth: 2)
                            )
                            .overlay {
                                Text("\(Calendar.mondayStart.component(.day, from: date))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(
                                        hasWorkout ? .black :
                                        isFuture   ? .white.opacity(0.1) :
                                                     .white.opacity(0.2)
                                    )
                            }
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: monthOffset)

            // ── Legenda ──────────────────────────────────────────────────────
            HStack(spacing: 4) {
                Spacer()
                Text("Méně").font(.system(size: 10))
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.05)).frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(accentColor.opacity(0.4)).frame(width: 10, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(accentColor).frame(width: 10, height: 10)
                Text("Více").font(.system(size: 10))
            }
            .foregroundStyle(.white.opacity(0.3))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}
