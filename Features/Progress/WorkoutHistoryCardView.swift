// WorkoutHistoryCardView.swift
import SwiftUI

struct WorkoutHistoryRecord: Identifiable {
    let id = UUID()
    let date: Date
    let splitName: String
    let durationSeconds: Int
    let personalRecordsCount: Int
}

struct WorkoutHistoryCardView: View {
    let record: WorkoutHistoryRecord
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Ikona s pozadím
            ZStack {
                Rectangle()
                    .fill(Color.appPrimaryAccent.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.appPrimaryAccent)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(record.splitName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text(formattedDate(record.date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                HStack(spacing: 12) {
                    Label(formattedDuration(record.durationSeconds), systemImage: "clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    if record.personalRecordsCount > 0 {
                        Label("\(record.personalRecordsCount) PRs", systemImage: "trophy.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.yellow)
                    }
                }
            }
        }
        .padding(16)
        .glassCardStyle(cornerRadius: 16)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "cs_CZ")
        return formatter.string(from: date)
    }
    
    private func formattedDuration(_ seconds: Int) -> String {
        let m = (seconds % 3600) / 60
        let h = seconds / 3600
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }
}
