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
        XCTAssertFalse(vm.isResting, "Po inicializaci nesmí být aktivní odpočinek.")
        XCTAssertEqual(vm.restSecondsRemaining, 0, "Zbývající odpočinek musí být 0.")
        XCTAssertEqual(vm.elapsedSeconds, 0, "Elapsed time musí začínat na 0.")
        XCTAssertEqual(vm.planLabel, "Day 1", "planLabel musí odpovídat parametru.")
        XCTAssertTrue(vm.audioEnabled, "Audio musí být defaultně zapnuto pro lepší UX.")
    }

    // ✅ FIX #14: Nové smysluplné testy — předchozí testovaly pouze initial state
    // který je triviálně správný a nepokrývá žádnou business logiku.

    func testRestDayViewModelHasNoExercises() {
        let restDay = PlannedWorkoutDay(dayOfWeek: 7, label: "Volno", isRestDay: true)
        let session = WorkoutSession(plan: nil, plannedDay: restDay)
        let vm = WorkoutViewModel(session: session, plan: restDay, planLabel: "Volno")
        
        XCTAssertTrue(vm.exercises.isEmpty, "Volný den nesmí mít žádné cviky.")
    }

    func testElapsedTimeFormattingUnderAnHour() {
        let planDay = PlannedWorkoutDay(dayOfWeek: 1, label: "Push", isRestDay: false)
        let session = WorkoutSession(plan: nil, plannedDay: planDay)
        let vm = WorkoutViewModel(session: session, plan: planDay, planLabel: "Push")
        
        // Simulujeme 65 sekund
        vm.elapsedSeconds = 65
        XCTAssertEqual(vm.elapsedTimeFormatted, "1:05", "65 sekund musí být zobrazeno jako 1:05.")
        
        // Simulujeme 3600 sekund (1 hodina)
        vm.elapsedSeconds = 3600
        XCTAssertEqual(vm.elapsedTimeFormatted, "1:00:00", "3600 sekund musí být zobrazeno jako 1:00:00.")
    }

    func testCompletionProgressWithNoExercises() {
        let planDay = PlannedWorkoutDay(dayOfWeek: 1, label: "Push", isRestDay: false)
        let session = WorkoutSession(plan: nil, plannedDay: planDay)
        let vm = WorkoutViewModel(session: session, plan: planDay, planLabel: "Push")
        
        XCTAssertEqual(vm.completionProgress, 0, accuracy: 0.001, "Progres bez cviků musí být 0.")
    }
}
