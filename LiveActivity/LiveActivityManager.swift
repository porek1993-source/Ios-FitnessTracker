// LiveActivityManager.swift

import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager: ObservableObject {

    static let shared = LiveActivityManager()
    @MainActor private var currentActivity: Activity<RestTimerAttributes>?

    func startRestActivity(
        session: WorkoutSession,
        currentExercise: SessionExerciseState,
        currentExerciseIndex: Int,
        completedExercisesCount: Int,
        completedSetIndex: Int,
        restSeconds: Int,
        planLabel: String
    ) async {
        await endCurrentActivity()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let completedSets = completedSetIndex + 1
        let nextSetNumber = completedSets + 1
        let totalSets     = currentExercise.sets.count

        let attributes = RestTimerAttributes(
            workoutSessionId:      session.id,
            exerciseSlug:          currentExercise.slug,
            planLabel:             planLabel,
            totalExercises:        6, // Možná nahradit realným počtem ze session
            currentExerciseIndex:  currentExerciseIndex
        )

        let nextSet = currentExercise.sets[safe: completedSets] ?? currentExercise.sets.last ?? currentExercise.sets[0]
        
        let state = RestTimerAttributes.ContentState(
            restEndsAt:          Date.now.addingTimeInterval(Double(restSeconds)),
            totalRestSeconds:    restSeconds,
            currentExerciseName: currentExercise.name,
            nextSetInfo:         "Série \(nextSetNumber) · \(nextSet.targetRepsMin)\(nextSet.targetRepsMin != nextSet.targetRepsMax ? "–\(nextSet.targetRepsMax)" : "") opakování",
            suggestedWeightKg:   nextSet.weightKg,
            sessionProgress:     SessionProgress(
                completedSets:      completedSets,
                totalSets:          totalSets,
                completedExercises: completedExercisesCount
            )
        )

        let content = ActivityContent(
            state: state,
            staleDate: Date.now.addingTimeInterval(Double(restSeconds) + 5)
        )

        do {
            currentActivity = try Activity<RestTimerAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            AppLogger.error("LiveActivityManager: start error — \(error.localizedDescription)")
        }
    }

    func updateRestTimer(newEndsAt: Date, totalSeconds: Int) async {
        guard let activity = currentActivity else { return }
        var updatedState = activity.content.state
        updatedState.restEndsAt       = newEndsAt
        updatedState.totalRestSeconds = totalSeconds
        let updated = ActivityContent(state: updatedState, staleDate: newEndsAt.addingTimeInterval(5))
        nonisolated(unsafe) let safeActivity = activity
        await safeActivity.update(updated)
    }

    func endCurrentActivity() async {
        guard let activity = currentActivity else { return }
        nonisolated(unsafe) let safeActivity = activity
        await safeActivity.end(activity.content, dismissalPolicy: .immediate)
        currentActivity = nil
    }

    func endWithDismissalDelay(_ seconds: TimeInterval = 3) async {
        guard let activity = currentActivity else { return }
        let dismissDate = Date.now.addingTimeInterval(seconds)
        nonisolated(unsafe) let safeActivity = activity
        await safeActivity.end(activity.content, dismissalPolicy: .after(dismissDate))
        currentActivity = nil
    }
}
