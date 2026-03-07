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
        nextExercise: SessionExerciseState? = nil,
        currentExerciseIndex: Int,
        totalExercises: Int,
        completedExercisesCount: Int,
        completedSetIndex: Int,
        restSeconds: Int,
        planLabel: String
    ) async {
        await endCurrentActivity()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = RestTimerAttributes(
            workoutSessionId:      session.id,
            exerciseSlug:          currentExercise.slug,
            planLabel:             planLabel,
            totalExercises:        totalExercises,
            currentExerciseIndex:  currentExerciseIndex
        )

        let isLastSet = completedSetIndex == currentExercise.sets.count - 1
        let titleName: String
        let nextSetText: String
        let upcomingWeight: Double?
        
        if isLastSet, let nextEx = nextExercise {
            titleName = "Připrav se: \(nextEx.name)"
            let firstSet = nextEx.sets.first
            let repsMin = firstSet?.targetRepsMin ?? 0
            let repsMax = firstSet?.targetRepsMax ?? repsMin
            nextSetText = "1. série · \(repsMin)\(repsMin != repsMax ? "–\(repsMax)" : "") opakování"
            upcomingWeight = firstSet?.previousWeightKg ?? firstSet?.weightKg
        } else {
            titleName = currentExercise.name
            let completedSets = completedSetIndex + 1
            let nextSetNumber = completedSets + 1
            let nextSet = currentExercise.sets[safe: completedSets] ?? currentExercise.sets.last
            
            if let safeSet = nextSet {
                nextSetText = "Série \(nextSetNumber) · \(safeSet.targetRepsMin)\(safeSet.targetRepsMin != safeSet.targetRepsMax ? "–\(safeSet.targetRepsMax)" : "") opakování"
                upcomingWeight = safeSet.previousWeightKg ?? safeSet.weightKg
            } else {
                nextSetText = "Hotovo"
                upcomingWeight = nil
            }
        }

        let state = RestTimerAttributes.ContentState(
            restEndsAt:          Date.now.addingTimeInterval(Double(restSeconds)),
            totalRestSeconds:    restSeconds,
            currentExerciseName: titleName,
            nextSetInfo:         nextSetText,
            suggestedWeightKg:   upcomingWeight,
            sessionProgress:     SessionProgress(
                completedSets:      completedSetIndex + 1,
                totalSets:          currentExercise.sets.count,
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
