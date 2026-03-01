// RestTimerLiveActivity.swift
// Agilní Fitness Trenér — Příprava na ActivityKit

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Attributes Data Model
// Definuje statická (neměnná) data pro Live Activity
struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamická data, která se průběžně mění (zbývající čas, RPE...)
        var remainingSeconds: Int
    }

    // Statická data (odpovídají jedné pauze)
    var exerciseName: String
    var nextSetNumber: Int
}

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
                    Text("\(context.state.remainingSeconds) s")
                        .font(.title)
                        .bold()
                        .foregroundStyle(.orange)
                        .contentTransition(.numericText())
                }
                
                Text("Další: \(context.attributes.exerciseName) (Série \(context.attributes.nextSetNumber))")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding()
            // Barva pozadí Live Activity
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.orange)

        } dynamicIsland: { context in
            // UI pro Dynamic Island
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Label("Pauza", systemImage: "timer")
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.remainingSeconds)s")
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.exerciseName) • Série \(context.attributes.nextSetNumber)")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text("\(context.state.remainingSeconds)")
                    .foregroundStyle(.orange)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.orange)
        }
    }
}
