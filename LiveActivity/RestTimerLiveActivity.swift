// RestTimerLiveActivity.swift
// Agilní Fitness Trenér — Příprava na ActivityKit

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Attributes Data Model
// Definuje statická (neměnná) data pro Live Activity


// MARK: - Live Activity UI
// (Tento kód je nutné přiřadit do widget targetu)
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // UI pro Lock Screen
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                    Text("Pauza")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text(timerInterval: context.state.restEndsAt.addingTimeInterval(-Double(context.state.totalRestSeconds))...context.state.restEndsAt, countsDown: true)
                        .font(.title)
                        .bold()
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
                
                Text("Další: \(context.state.currentExerciseName) • \(context.state.nextSetInfo)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                
                ProgressView(value: Double(context.state.sessionProgress.completedSets), total: Double(context.state.sessionProgress.totalSets))
                    .tint(.orange)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Pauza", systemImage: "timer").foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.restEndsAt.addingTimeInterval(-Double(context.state.totalRestSeconds))...context.state.restEndsAt, countsDown: true)
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.currentExerciseName).bold()
                        Text(context.state.nextSetInfo).font(.caption).foregroundStyle(.gray)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(.orange)
            } compactTrailing: {
                Text(timerInterval: context.state.restEndsAt.addingTimeInterval(-Double(context.state.totalRestSeconds))...context.state.restEndsAt, countsDown: true)
                    .foregroundStyle(.orange)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer").foregroundStyle(.orange)
            }
            .keylineTint(Color.orange)
        }
    }
}
