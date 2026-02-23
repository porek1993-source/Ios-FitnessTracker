// WorkoutViewModelTests.swift
import XCTest
@testable import AgileFitnessTrainer

@MainActor
final class WorkoutViewModelTests: XCTestCase {

    func testViewModelInitialization() {
        let planDay = PlannedWorkoutDay(
            id: UUID(),
            date: Date(),
            dayType: .workout,
            label: "Test Workout",
            plannedExercises: []
        )
        
        let session = WorkoutSession(
            id: UUID(),
            date: Date(),
            durationSeconds: 0,
            log: []
        )
        
        let vm = WorkoutViewModel(session: session, plan: planDay, planLabel: "Day 1")
        
        XCTAssertEqual(vm.currentExerciseIndex, 0)
        XCTAssertEqual(vm.isResting, false)
        XCTAssertEqual(vm.restSecondsRemaining, 0)
        XCTAssertEqual(vm.elapsedSeconds, 0)
        XCTAssertEqual(vm.planLabel, "Day 1")
    }
}
