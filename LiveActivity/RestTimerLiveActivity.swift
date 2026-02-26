// RestTimerLiveActivity.swift
// Cíl: Widget Extension target

import ActivityKit
import WidgetKit
import SwiftUI

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            LockScreenRestView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
            .widgetURL(URL(string: "agilefit://workout/session"))
            .keylineTint(Color.blue)
        }
    }
}

// MARK: - Lock Screen

struct LockScreenRestView: View {
    let context: ActivityViewContext<RestTimerAttributes>

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 4)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text(timerText)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("PAUZA")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .kerning(1.4)
                Text(context.state.currentExerciseName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(context.state.nextSetInfo)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let kg = context.state.suggestedWeightKg {
                    Text(String(format: "%.1f kg", kg))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("doporučená váha")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
                ProgressPillsView(progress: context.state.sessionProgress)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(white: 0.06), Color(white: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var timerProgress: Double {
        let remaining = context.state.restEndsAt.timeIntervalSinceNow
        let total = Double(context.state.totalRestSeconds)
        guard total > 0 else { return 0 }
        return max(0, min(1, remaining / total))
    }

    private var timerText: String {
        let secs = Int(max(0, context.state.restEndsAt.timeIntervalSinceNow))
        return secs >= 60 ? "\(secs / 60):\(String(format: "%02d", secs % 60))" : "\(secs)s"
    }
}

// MARK: - Dynamic Island Expanded

struct ExpandedLeadingView: View {
    let context: ActivityViewContext<RestTimerAttributes>
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(context.attributes.planLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
            Text(context.state.currentExerciseName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.leading, 4)
    }
}

struct ExpandedTrailingView: View {
    let context: ActivityViewContext<RestTimerAttributes>
    var body: some View {
        if let kg = context.state.suggestedWeightKg {
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.1f", kg))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("kg")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.trailing, 4)
        }
    }
}

struct ExpandedCenterView: View {
    let context: ActivityViewContext<RestTimerAttributes>
    var body: some View {
        VStack(spacing: 2) {
            Text(timerText)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
            Text(context.state.nextSetInfo)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
    private var timerText: String {
        let secs = Int(max(0, context.state.restEndsAt.timeIntervalSinceNow))
        return secs >= 60 ? "\(secs / 60):\(String(format: "%02d", secs % 60))" : "\(secs)s"
    }
}

struct ExpandedBottomView: View {
    let context: ActivityViewContext<RestTimerAttributes>
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.1)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * timerProgress, height: 4)
                        .animation(.linear(duration: 1), value: timerProgress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 16)

            HStack {
                Text("Cvičení \(context.attributes.currentExerciseIndex + 1)/\(context.attributes.totalExercises)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                let p = context.state.sessionProgress
                Text("\(p.completedSets)/\(p.totalSets) sérií hotovo")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }
    private var timerProgress: Double {
        let remaining = context.state.restEndsAt.timeIntervalSinceNow
        let total = Double(context.state.totalRestSeconds)
        guard total > 0 else { return 0 }
        return max(0, min(1, remaining / total))
    }
}

// MARK: - Dynamic Island Compact / Minimal

struct CompactLeadingView: View {
    let context: ActivityViewContext<RestTimerAttributes>
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.blue)
            Text(timerText)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .monospacedDigit()
        }
        .padding(.leading, 6)
    }
    private var timerText: String {
        let secs = Int(max(0, context.state.restEndsAt.timeIntervalSinceNow))
        return secs >= 60 ? "\(secs / 60):\(String(format: "%02d", secs % 60))" : "\(secs)s"
    }
}

struct CompactTrailingView: View {
    let context: ActivityViewContext<RestTimerAttributes>
    var body: some View {
        Text(context.state.currentExerciseName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            .padding(.trailing, 6)
    }
}

struct MinimalView: View {
    let context: ActivityViewContext<RestTimerAttributes>
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: timerProgress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 22, height: 22)
            Text(minimalText)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }
    private var timerProgress: Double {
        let remaining = context.state.restEndsAt.timeIntervalSinceNow
        let total = Double(context.state.totalRestSeconds)
        guard total > 0 else { return 0 }
        return max(0, min(1, remaining / total))
    }
    private var minimalText: String {
        let secs = Int(max(0, context.state.restEndsAt.timeIntervalSinceNow))
        return secs >= 60 ? "\(secs / 60)m" : "\(secs)"
    }
}

// MARK: - Progress Pills

struct ProgressPillsView: View {
    let progress: SessionProgress
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<progress.totalSets, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < progress.completedSets ? Color.green : Color.white.opacity(0.15))
                    .frame(width: 10, height: 4)
            }
        }
    }
}
