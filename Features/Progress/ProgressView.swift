// ProgressView.swift
import SwiftUI

struct AppProgressView: View {
    // Mock Data pro ukázku (normálně napojeno na SwiftData / ViewModel)
    let maxRecords: [MaxRecord] = [
        MaxRecord(date: Calendar.current.date(byAdding: .day, value: -28, to: Date())!, exercise: "Benchpress", weight: 80),
        MaxRecord(date: Calendar.current.date(byAdding: .day, value: -21, to: Date())!, exercise: "Benchpress", weight: 82.5),
        MaxRecord(date: Calendar.current.date(byAdding: .day, value: -14, to: Date())!, exercise: "Benchpress", weight: 85),
        MaxRecord(date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!, exercise: "Benchpress", weight: 87.5),
        MaxRecord(date: Date(), exercise: "Benchpress", weight: 90),
        
        MaxRecord(date: Calendar.current.date(byAdding: .day, value: -14, to: Date())!, exercise: "Dřep", weight: 110),
        MaxRecord(date: Date(), exercise: "Dřep", weight: 115)
    ]
    
    let volumeRecords: [VolumeRecord] = [
        VolumeRecord(date: Calendar.current.date(byAdding: .day, value: -28, to: Date())!, volumeKg: 12500),
        VolumeRecord(date: Calendar.current.date(byAdding: .day, value: -21, to: Date())!, volumeKg: 13200),
        VolumeRecord(date: Calendar.current.date(byAdding: .day, value: -14, to: Date())!, volumeKg: 11800),
        VolumeRecord(date: Calendar.current.date(byAdding: .day, value: -7, to: Date())!, volumeKg: 14500),
        VolumeRecord(date: Date(), volumeKg: 15100)
    ]
    
    let historyRecords: [WorkoutHistoryRecord] = [
        WorkoutHistoryRecord(date: Date(), splitName: "Push Day", durationSeconds: 3800, personalRecordsCount: 2),
        WorkoutHistoryRecord(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, splitName: "Pull Day", durationSeconds: 4100, personalRecordsCount: 0),
        WorkoutHistoryRecord(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, splitName: "Legs", durationSeconds: 4500, personalRecordsCount: 1),
        WorkoutHistoryRecord(date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, splitName: "Push Day", durationSeconds: 3600, personalRecordsCount: 0)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // 1RM Graf
                        OneRepMaxChartView(records: maxRecords)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // Volume Graf
                        VolumeChartView(records: volumeRecords)
                            .padding(.horizontal, 16)
                        
                        // Historie Tréninků
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Historie tréninků")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(historyRecords) { record in
                                    WorkoutHistoryCardView(record: record)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Progres")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
