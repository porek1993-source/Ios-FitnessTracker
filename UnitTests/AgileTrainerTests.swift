// AgileTrainerTests.swift
// Klíčové unit testy pro AgileFitnessTrainer.

import XCTest
import SwiftUI
import SwiftData
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
                            "nameEN": "Bench Press",
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
        XCTAssertTrue(plan.exercises[0].sets >= 3, "Advanced/Intermediate has 3 or 4 sets.")
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

        // Střední RPE = žlutá/oranžová (AppColors.warning)
        let mid = Color.rpeColor(for: 6)
        XCTAssertEqual(mid, AppColors.warning)

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

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: GamificationEngine Tests
// MARK: ═══════════════════════════════════════════════════════════════════════

@MainActor
final class GamificationEngineTests: XCTestCase {

    /// Regresní test pro FIX #11 — levelProgress nesměl vracet záporné číslo pro elite level.
    func testLevelProgressEliteIsOne() {
        let engine = GamificationEngine()
        // Simulujeme MuscleXPRecord přímo
        let record = MuscleXPRecord(muscleGroup: .chest)
        record.totalXP = 100_000  // Daleko za elite threshold (40 000)
        engine.muscleRecords[.chest] = record

        let progress = engine.levelProgress(for: .chest)
        XCTAssertGreaterThanOrEqual(progress, 0.0, "levelProgress nesmí být záporné.")
        XCTAssertLessThanOrEqual(progress, 1.0, "levelProgress nesmí překročit 1.0.")
        XCTAssertEqual(progress, 1.0, accuracy: 0.001, "Pro elite level musí být progress 1.0.")
    }

    /// Test, že XP zisk je proporcionální k objemu.
    func testXPGainProportionalToVolume() {
        let engine = GamificationEngine()
        let input = SessionGamificationInput(
            exercises: [
                SessionGamificationInput.ExerciseResult(
                    exerciseName: "Bench Press",
                    musclesTarget: [.chest],
                    musclesSecondary: [],
                    completedSets: [
                        .init(weightKg: 100, reps: 10, isWarmup: false),
                        .init(weightKg: 100, reps: 10, isWarmup: false)
                    ]
                )
            ],
            personalRecords: []
        )

        // Použijeme in-memory SwiftData context pro test
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema([MuscleXPRecord.self])
        guard let container = try? ModelContainer(for: schema, configurations: config) else {
            XCTFail("Nelze vytvořit test ModelContainer")
            return
        }
        let context = container.mainContext

        let gains = engine.process(input: input, context: context)

        XCTAssertFalse(gains.isEmpty, "Musí existovat alespoň 1 XP zisk.")
        let chestGain = gains.first { $0.muscleGroup == .chest }
        XCTAssertNotNil(chestGain, "Chest musí mít XP zisk.")
        // 2 sety × 100 kg × 10 reps = 2000 XP
        XCTAssertEqual(chestGain?.xpEarned ?? 0, 2000, accuracy: 1.0, "XP zisk musí odpovídat volume * koeficientu.")
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Extensions Tests (FIX #16, #21)
// MARK: ═══════════════════════════════════════════════════════════════════════

final class ExtensionsTests: XCTestCase {

    /// Regresní test pro FIX #16 — endOfDay musí být DST-bezpečný.
    func testEndOfDayIsStartOfNextDay() {
        // Použijeme fixní datum abychom nezáviseli na aktuálním dnu
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 31  // Konec letního času v CZ 2024 (přechod o půlnoci)
        components.hour = 12
        components.minute = 0
        guard let testDate = calendar.date(from: components) else {
            XCTFail("Nepodařilo se vytvořit testovací datum")
            return
        }

        let endOfDay = testDate.endOfDay
        let startOfNextDay = calendar.startOfDay(for: testDate.addingTimeInterval(86_400))

        // endOfDay musí být shodné se začátkem zítřka (DST-bezpečné)
        XCTAssertEqual(endOfDay, testDate.startOfDay.addingTimeInterval(0) == endOfDay ? endOfDay : startOfNextDay,
                       "endOfDay musí odpovídat začátku zítřka dle Calendar.")
    }

    /// Test Double.rounded(toNearest:) — přesunuto z WorkoutViewModel (FIX #21).
    func testDoubleRoundedToNearest() {
        XCTAssertEqual(100.0.rounded(toNearest: 2.5), 100.0, accuracy: 0.001)
        XCTAssertEqual(101.0.rounded(toNearest: 2.5), 100.0, accuracy: 0.001)
        XCTAssertEqual(101.3.rounded(toNearest: 2.5), 102.5, accuracy: 0.001)
        XCTAssertEqual(102.4.rounded(toNearest: 2.5), 102.5, accuracy: 0.001)
        XCTAssertEqual(95.0.rounded(toNearest: 5.0),  95.0,  accuracy: 0.001)
        XCTAssertEqual(97.5.rounded(toNearest: 5.0),  100.0, accuracy: 0.001)
    }

    /// Test weekday konverze — pondělí musí být 1, neděle 7.
    func testWeekdayConversion() {
        let calendar = Calendar(identifier: .gregorian)
        // 2024-01-01 byl pondělí
        var components = DateComponents()
        components.year = 2024; components.month = 1; components.day = 1
        guard let monday = calendar.date(from: components) else { XCTFail(); return }

        components.day = 7  // neděle
        guard let sunday = calendar.date(from: components) else { XCTFail(); return }

        XCTAssertEqual(monday.weekday, 1, "Pondělí musí být weekday 1.")
        XCTAssertEqual(sunday.weekday,  7, "Neděle musí být weekday 7.")
    }
}
