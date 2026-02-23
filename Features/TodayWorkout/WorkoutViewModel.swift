// WorkoutViewModel.swift
import SwiftUI

// MARK: - ViewModel

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published var exercises: [SessionExerciseState]
    @Published var currentExerciseIndex = 0
    @Published var isResting = false
    @Published var restSecondsRemaining = 0
    @Published var totalRestSeconds = 90
    @Published var elapsedSeconds = 0

    private var restTimer: Timer?
    private var elapsedTimer: Timer?
    let session: WorkoutSession
    let planLabel: String

    init(session: WorkoutSession, plan: PlannedWorkoutDay, planLabel: String) {
        self.session   = session
        self.planLabel = planLabel
        self.exercises = plan.plannedExercises
            .sorted { $0.order < $1.order }
            .map { SessionExerciseState(from: $0) }
        startElapsedTimer()
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.elapsedSeconds += 1 }
        }
    }

    func completeSet(exerciseIndex: Int, setIndex: Int) {
        guard
            exercises[exerciseIndex].sets[setIndex].weightKg != nil,
            exercises[exerciseIndex].sets[setIndex].reps     != nil
        else { return }

        withAnimation(.spring(response: 0.3)) {
            exercises[exerciseIndex].sets[setIndex].isCompleted = true
        }

        let exercise    = exercises[exerciseIndex]
        let restSeconds = exercise.restSeconds

        Task {
            await LiveActivityManager.shared.startRestActivity(
                session:          session,
                currentExercise:  exercise,
                completedSetIndex: setIndex,
                restSeconds:      restSeconds,
                planLabel:        planLabel
            )
        }

        startRestTimer(seconds: restSeconds)

        let allDone = exercises[exerciseIndex].sets.allSatisfy(\.isCompleted)
        if allDone {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(restSeconds) + 0.5) { [weak self] in
                self?.advanceToNextExercise()
            }
        }
    }

    private func startRestTimer(seconds: Int) {
        guard seconds > 0 else { return }
        restTimer?.invalidate()
        totalRestSeconds     = seconds
        restSecondsRemaining = seconds
        withAnimation { isResting = true }

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.restSecondsRemaining > 1 {
                    self.restSecondsRemaining -= 1
                } else {
                    self.skipRest()
                }
            }
        }
    }

    func skipRest() {
        restTimer?.invalidate()
        withAnimation(.spring(response: 0.35)) { isResting = false }
        Task { await LiveActivityManager.shared.endWithDismissalDelay(2) }
    }

    func adjustRest(by delta: Int) {
        restSecondsRemaining = max(0, restSecondsRemaining + delta)
        if restSecondsRemaining == 0 { skipRest(); return }
        let newEndsAt = Date.now.addingTimeInterval(Double(restSecondsRemaining))
        Task {
            await LiveActivityManager.shared.updateRestTimer(
                newEndsAt: newEndsAt,
                totalSeconds: restSecondsRemaining
            )
        }
    }

    func skipExercise() { withAnimation { advanceToNextExercise() } }

    private func advanceToNextExercise() {
        guard currentExerciseIndex < exercises.count - 1 else { return }
        withAnimation(.easeInOut) { currentExerciseIndex += 1 }
    }

    func finishWorkout() {
        restTimer?.invalidate()
        elapsedTimer?.invalidate()
        Task { await LiveActivityManager.shared.endCurrentActivity() }
    }

    var restProgress: Double {
        guard totalRestSeconds > 0 else { return 0 }
        return Double(restSecondsRemaining) / Double(totalRestSeconds)
    }

    var restTimeFormatted: String {
        let m = restSecondsRemaining / 60
        let s = restSecondsRemaining % 60
        return m > 0 ? "\(m):\(String(format: "%02d", s))" : "\(s)"
    }

    var elapsedTimeFormatted: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

// MARK: - State Models

struct SessionExerciseState: Identifiable {
    let id: UUID
    let name: String
    let slug: String
    let coachTip: String?
    let tempo: String?
    let restSeconds: Int
    var sets: [SetState]

    var nextIncompleteSetIndex: Int? {
        sets.indices.first { !sets[$0].isCompleted }
    }

    init(from planned: PlannedExercise) {
        self.id          = UUID()
        self.name        = planned.exercise?.name ?? ""
        self.slug        = planned.exercise?.slug ?? ""
        self.coachTip    = nil
        self.tempo       = nil
        self.restSeconds = planned.restSeconds
        self.sets = (0..<planned.targetSets).map { _ in
            SetState(
                targetRepsMin:    planned.targetRepsMin,
                targetRepsMax:    planned.targetRepsMax,
                previousWeightKg: planned.exercise?.lastUsedWeight
            )
        }
    }

    init(from response: ResponseExercise) {
        self.id          = UUID()
        self.name        = response.name
        self.slug        = response.slug
        self.coachTip    = response.coachTip
        self.tempo       = response.tempo
        self.restSeconds = response.restSeconds
        self.sets = (0..<response.sets).map { _ in
            SetState(
                targetRepsMin:    response.repsMin,
                targetRepsMax:    response.repsMax,
                previousWeightKg: response.weightKg
            )
        }
    }
}

struct SetState {
    var weightKg: Double?
    var reps: Int?
    var rpe: Int?
    var isCompleted = false
    let targetRepsMin: Int
    let targetRepsMax: Int
    let previousWeightKg: Double?
}
