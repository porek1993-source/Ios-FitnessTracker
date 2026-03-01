// WeeklyCalendarView.swift
// Agilní Fitness Trenér — Živý kalendář na Dashboardu

import SwiftUI

enum DailyWorkoutState {
    case completed
    case planned
    case missed
    case empty
    case todayPlanned
    case todayEmpty
}

struct WeeklyCalendarView: View {
    let completedCount: Int
    let plannedCount: Int
    let weekDaysState: [DailyWorkoutState]

    private let days = ["Po", "Út", "St", "Čt", "Pá", "So", "Ne"]
    
    private var todayIndex: Int {
        let wd = Calendar.current.component(.weekday, from: .now)
        return wd == 1 ? 6 : wd - 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TENTO TÝDEN")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white.opacity(0.3))
                    .kerning(1.2)

                Spacer()

                Text("\(completedCount) / \(plannedCount) tréninků")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { i in
                    let state = weekDaysState.indices.contains(i) ? weekDaysState[i] : .empty
                    LiveDayDot(
                        label: days[i],
                        state: state,
                        isToday: i == todayIndex
                    )
                }
            }
        }
    }
}

private struct LiveDayDot: View {
    let label: String
    let state: DailyWorkoutState
    let isToday: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(dotFill)
                    .frame(width: 38, height: 38)
                
                if isToday {
                    Circle()
                        .stroke(Color.white.opacity(0.7), lineWidth: 2)
                        .frame(width: 42, height: 42)
                }
                
                // Icon or inner style
                switch state {
                case .completed:
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.black)
                case .planned, .todayPlanned:
                    Circle()
                        .fill(AppColors.primaryAccent)
                        .frame(width: 8, height: 8)
                case .missed:
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                case .empty, .todayEmpty:
                    if isToday {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            Text(label)
                .font(.system(size: 11, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? .white : .white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
    
    // Logika barev koleček: Modrá = plánováno, Zelená = hotovo, Šedá = zmeškano/prázdné.
    private var dotFill: Color {
        switch state {
        case .completed:
            return Color(red: 0.15, green: 0.82, blue: 0.45) // Zelená
        case .planned, .todayPlanned:
            return AppColors.primaryAccent.opacity(0.2) // Modrá poloprůhledná pozadí
        case .missed:
            return Color.white.opacity(0.08) // Šedá pro zmeškané
        case .empty, .todayEmpty:
            return Color.white.opacity(0.04) // Šedá (tmavší)
        }
    }
}
