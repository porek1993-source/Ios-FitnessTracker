// WorkoutViewModelTests.swift
import XCTest
@testable import AgileTrainer

@MainActor
final class WorkoutViewModelTests: XCTestCase {

    func testViewModelInitialization() {
        let planDay = PlannedWorkoutDay(
            dayOfWeek: 1,
            label: "Test Workout",
            isRestDay: false
        )
        
        let session = WorkoutSession(
            plan: nil,
            plannedDay: planDay
        )
        
        let vm = WorkoutViewModel(session: session, plan: planDay, planLabel: "Day 1")
        
        XCTAssertEqual(vm.currentExerciseIndex, 0)
        XCTAssertEqual(vm.isResting, false)
        XCTAssertEqual(vm.restSecondsRemaining, 0)
        XCTAssertEqual(vm.elapsedSeconds, 0)
        XCTAssertEqual(vm.planLabel, "Day 1")
    }
}
