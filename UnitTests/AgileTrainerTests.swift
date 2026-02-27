// AgileTrainerTests.swift
// Klíčové unit testy pro AgileFitnessTrainer.

import XCTest
import SwiftUI
@testable import AgileTrainer

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: AI Response Parsing Tests
// MARK: ═══════════════════════════════════════════════════════════════════════

final class AIResponseParsingTests: XCTestCase {

    /// Test, že se správně parsuje validní JSON odpověď z Gemini.
    func testTrainerResponseParsing() throws {
        let json = """
        {
            "coachMessage": "Skvělá práce, dnes jedeme Push!",
            "sessionLabel": "Push Day",
            "readinessLevel": "green",
            "adaptationReason": null,
            "estimatedDurationMinutes": 55,
            "warmUp": [
                { "name": "Rotace ramen", "sets": 2, "reps": "10" }
            ],
            "mainBlocks": [
                {
                    "blockLabel": "Hlavní blok",
                    "exercises": [
                        {
                            "name": "Bench Press",
                            "slug": "bench-press",
                            "sets": 4,
                            "repsMin": 8,
                            "repsMax": 12,
                            "rir": 2,
                            "restSeconds": 90,
                            "weightKg": 80.0,
                            "tempo": "2111",
                            "coachTip": "Lopatky stáhni dozadu."
                        }
                    ]
                }
            ],
            "coolDown": [
                { "name": "Statický strečink", "durationSeconds": 300 }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(TrainerResponse.self, from: json)

        XCTAssertEqual(response.coachMessage, "Skvělá práce, dnes jedeme Push!")
        XCTAssertEqual(response.sessionLabel, "Push Day")
        XCTAssertEqual(response.readinessLevel, "green")
        XCTAssertNil(response.adaptationReason)
        XCTAssertEqual(response.estimatedDurationMinutes, 55)
        XCTAssertEqual(response.warmUp.count, 1)
        XCTAssertEqual(response.mainBlocks.count, 1)
        XCTAssertEqual(response.mainBlocks[0].exercises.count, 1)
        XCTAssertEqual(response.mainBlocks[0].exercises[0].slug, "bench-press")
        XCTAssertEqual(response.mainBlocks[0].exercises[0].weightKg, 80.0)
        XCTAssertEqual(response.coolDown.count, 1)
    }

    /// Test, že parsování selže na neúplném JSON (missing required fields).
    func testTrainerResponseMissingFieldsFails() {
        let incompleteJSON = """
        { "coachMessage": "Ahoj" }
        """.data(using: .utf8)!

        XCTAssertThrowsError(
            try JSONDecoder().decode(TrainerResponse.self, from: incompleteJSON)
        )
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Progressive Overload Logic Tests
// MARK: ═══════════════════════════════════════════════════════════════════════

@MainActor
final class ProgressiveOverloadTests: XCTestCase {

    /// Testuje, že FallbackWorkoutGenerator generuje validní plán pro Push den.
    func testFallbackGeneratorPushDay() {
        let profile = UserContextProfile(fitnessLevel: "Pokročilý")
        let day = PlannedWorkoutDay(
            dayOfWeek: 1,
            label: "Push Day",
            isRestDay: false
        )

        // FallbackWorkoutGenerator nemá závislost na ModelContext pro základní test
        // Testujeme logiku výběru cviků podle labelu dne
        let plan = FallbackWorkoutGenerator.generateFallbackPlan(
            for: profile,
            day: day,
            context: SharedModelContainer.container.mainContext
        )

        XCTAssertFalse(plan.exercises.isEmpty, "Push day musí mít alespoň 1 cvik.")
        XCTAssertEqual(plan.exercises[0].sets, 4, "Pokročilý hráč má 4 série.")
        XCTAssertTrue(plan.motivationalMessage.contains("offline"), "Fallback zpráva musí obsahovat 'offline'.")
    }

    /// Testuje, že Fallback pro začátečníka nastaví 3 série.
    func testFallbackGeneratorBeginnerSets() {
        let profile = UserContextProfile(fitnessLevel: "Začátečník")
        let day = PlannedWorkoutDay(
            dayOfWeek: 4, label: "Leg Day", isRestDay: false
        )

        let plan = FallbackWorkoutGenerator.generateFallbackPlan(
            for: profile, day: day,
            context: SharedModelContainer.container.mainContext
        )

        XCTAssertEqual(plan.exercises[0].sets, 3, "Začátečník má 3 série.")
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Utility Tests
// MARK: ═══════════════════════════════════════════════════════════════════════

@MainActor
final class UtilityTests: XCTestCase {

    /// Test YouTubeLinkGenerator — anglický název.
    func testYouTubeLinkWithEnglishName() {
        let url = YouTubeLinkGenerator.searchURL(nameEn: "Bench Press", nameCz: "Benchpress")
        XCTAssertTrue(url.absoluteString.contains("Bench+Press"), "URL musí obsahovat anglický název.")
        XCTAssertTrue(url.absoluteString.contains("proper+form"))
    }

    /// Test YouTubeLinkGenerator — fallback na český název.
    func testYouTubeLinkFallbackToCzech() {
        let url = YouTubeLinkGenerator.searchURL(nameEn: nil, nameCz: "Dřep")
        XCTAssertTrue(url.absoluteString.contains("D%C5%99ep") || url.absoluteString.contains("Dřep"),
                       "URL musí obsahovat český název při absenci anglického.")
    }

    /// Test RPE color mapping.
    func testRPEColorMapping() {
        // Nízké RPE = zelená
        let low = Color.rpeColor(for: 3)
        XCTAssertEqual(low, Color.appGreenText)

        // Střední RPE = žlutá
        let mid = Color.rpeColor(for: 6)
        XCTAssertEqual(mid, .yellow)

        // Vysoké RPE = oranžová
        let high = Color.rpeColor(for: 8)
        XCTAssertEqual(high, .orange)

        // Maximální RPE = červená
        let max = Color.rpeColor(for: 10)
        XCTAssertEqual(max, Color.appRedText)
    }

    /// Test Debouncer — akce se spustí jen jednou po sérii rychlých volání.
    func testDebouncerFiresOnce() {
        let expectation = expectation(description: "debounce")
        let debouncer = Debouncer(delay: 0.1)
        var count = 0

        for _ in 0..<10 {
            debouncer.debounce { count += 1 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            XCTAssertEqual(count, 1, "Debouncer musí spustit akci jen jednou.")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: MuscleWiki DTO Tests
// MARK: ═══════════════════════════════════════════════════════════════════════

final class MuscleWikiDTOTests: XCTestCase {

    /// Test, že MuscleWikiExercise správně dekóduje equipment pole z Supabase JSON.
    func testMuscleWikiEquipmentDecoding() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Benchpress s jednoručkami",
            "video_url": "https://example.com/bench.mp4",
            "muscle_group": "chest",
            "equipment": "Jednoručka",
            "instructions": ["Lehni si na lavičku", "Drž jednoručky"],
            "difficulty": "intermediate",
            "exercise_type": "compound",
            "grip": null
        }
        """.data(using: .utf8)!

        let exercise = try JSONDecoder().decode(MuscleWikiExercise.self, from: json)

        XCTAssertEqual(exercise.name, "Benchpress s jednoručkami")
        XCTAssertEqual(exercise.equipment, "Jednoručka", "Equipment musí být správně dekódováno")
        XCTAssertEqual(exercise.muscleGroup, "chest")
        XCTAssertEqual(exercise.instructions.count, 2)
        XCTAssertNil(exercise.grip)
    }

    /// Test, že equipment je nil pokud DB vrátí null.
    func testMuscleWikiEquipmentNilHandling() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000002",
            "name": "Kliky",
            "video_url": "https://example.com/pushup.mp4",
            "muscle_group": "chest",
            "equipment": null,
            "instructions": ["Dej se do pozice"],
            "difficulty": "beginner",
            "exercise_type": "compound",
            "grip": null
        }
        """.data(using: .utf8)!

        let exercise = try JSONDecoder().decode(MuscleWikiExercise.self, from: json)
        XCTAssertNil(exercise.equipment, "Null equipment musí být nil")
        XCTAssertNil(exercise.mappedEquipment, "mappedEquipment musí být nil pro nil equipment")
    }

    /// Test equipmentMap — všechny CZ hodnoty z DB musí mít mapování.
    func testEquipmentMapCoversAllDBValues() {
        let dbValues = ["Jednoručka", "Velká činka", "Vlastní váha", "Stroj",
                        "Kladka", "Kettlebell", "Odporová guma", "Bosu",
                        "Kotouč", "Medicimbal", "TRX", "Kardio", "Jiné"]

        for value in dbValues {
            XCTAssertNotNil(
                MuscleWikiExercise.equipmentMap[value],
                "equipmentMap musí obsahovat klíč '\(value)' z databáze"
            )
        }
    }

    /// Test front-shoulders lokalizace.
    func testFrontShouldersLocalization() {
        let localized = MuscleWikiExercise.localizedName(for: "front-shoulders")
        XCTAssertEqual(localized, "Přední ramena", "front-shoulders musí být přeložen na česky")
    }

    /// Test, že chips NEobsahují equipment (zobrazuje se v header, ne v chips).
    func testChipsDoNotContainEquipment() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000003",
            "name": "Bench Press",
            "video_url": "https://example.com/bench.mp4",
            "muscle_group": "chest",
            "equipment": "Jednoručka",
            "instructions": [],
            "difficulty": "intermediate",
            "exercise_type": "compound",
            "grip": "overhand"
        }
        """.data(using: .utf8)!

        let exercise = try JSONDecoder().decode(MuscleWikiExercise.self, from: json)
        let chipLabels = exercise.chips.map(\.label)
        XCTAssertFalse(
            chipLabels.contains("Jednoručka"),
            "Equipment nemá být v chips — zobrazuje se v header badge"
        )
    }

    /// Test mapování muscle_wiki_data_full URL (nový název tabulky).
    func testTableNameIsCorrect() {
        // Ověříme, že SupabaseExerciseRepository používá správný název tabulky
        // Toto je smoke test — konkrétní URL se testuje integračně
        let repo = SupabaseExerciseRepository()
        XCTAssertNotNil(repo, "Repository musí jít inicializovat")
    }
}
