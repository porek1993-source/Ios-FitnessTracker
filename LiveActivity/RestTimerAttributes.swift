// RestTimerAttributes.swift
// Sdílený soubor — přidat do OBOU targetů: hlavní app i Widget Extension

import ActivityKit
import Foundation

struct RestTimerAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var restEndsAt: Date
        var totalRestSeconds: Int
        var currentExerciseName: String
        var nextSetInfo: String
        var suggestedWeightKg: Double?
        var sessionProgress: SessionProgress
    }

    let workoutSessionId: UUID
    let exerciseSlug: String
    let planLabel: String
    let totalExercises: Int
    let currentExerciseIndex: Int
}

struct SessionProgress: Codable, Hashable {
    var completedSets: Int
    var totalSets: Int
    var completedExercises: Int
}
