// AITrainerModelsTests.swift
import XCTest
@testable import AgileTrainer

final class AITrainerModelsTests: XCTestCase {

    func testDecodingResponsePlan() throws {
        let json = """
        {
            "motivationalMessage": "Skvělá práce!",
            "warmupUrl": "https://example.com",
            "exercises": [
                {
                    "name": "Dřep",
                    "nameEN": "Squat",
                    "slug": "squat",
                    "coachTip": "Kolena nepřesahují špičky",
                    "sets": 3,
                    "repsMin": 8,
                    "repsMax": 12,
                    "weightKg": 60.0,
                    "rpe": 7,
                    "tempo": "3111",
                    "restSeconds": 90
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ResponsePlan.self, from: json)
        
        XCTAssertEqual(response.motivationalMessage, "Skvělá práce!")
        XCTAssertEqual(response.warmupUrl, "https://example.com")
        XCTAssertEqual(response.exercises.count, 1)
        
        let exercise = response.exercises[0]
        XCTAssertEqual(exercise.name, "Dřep")
        XCTAssertEqual(exercise.slug, "squat")
        XCTAssertEqual(exercise.coachTip, "Kolena nepřesahují špičky")
        XCTAssertEqual(exercise.sets, 3)
        XCTAssertEqual(exercise.repsMin, 8)
        XCTAssertEqual(exercise.repsMax, 12)
        XCTAssertEqual(exercise.weightKg, 60.0)
        XCTAssertEqual(exercise.rpe, 7)
        XCTAssertEqual(exercise.tempo, "3111")
        XCTAssertEqual(exercise.restSeconds, 90)
    }

    func testResponsePlanSchemaValidation() throws {
        // Here we just test if the schema matches the defined structure.
        let dict = ResponsePlan.jsonSchema
        
        XCTAssertEqual(dict["type"] as? String, "object")
        let properties = dict["properties"] as? [String: Any]
        XCTAssertNotNil(properties)

        let exercises = properties?["exercises"] as? [String: Any]
        XCTAssertEqual(exercises?["type"] as? String, "array")
        
        let required = dict["required"] as? [String]
        XCTAssertNotNil(required)
        XCTAssertTrue(required!.contains("motivationalMessage"))
        XCTAssertTrue(required!.contains("exercises"))
    }
}
