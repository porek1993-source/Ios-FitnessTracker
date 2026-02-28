// HeatmapViewModel.swift
// Sdílený ViewModel pro správu svalové únavy a připravenosti

import SwiftUI

@MainActor
final class HeatmapViewModel: ObservableObject {
    @Published var affectedAreas: [FatigueEntry] = []
    @Published var lastTappedArea: MuscleArea?
    @Published var readinessScore: Double = 0
    @Published var muscleProgressMap: [String: Double] = [:]

    var muscleGroupIntensity: [MuscleGroup: Double] {
        var intensity: [MuscleGroup: Double] = [:]
        for entry in affectedAreas {
            if let group = MuscleGroup.from(supabaseKey: entry.areaSlug) {
                let severityVal = Double(entry.severity) / 5.0
                let current = intensity[group] ?? 0
                intensity[group] = max(current, severityVal)
            }
        }
        return intensity
    }

    /// Načte readiness z HealthKit — stejný výpočet jako Dashboard
    func loadReadiness(healthKit: HealthKitService) {
        Task {
            guard let summary = try? await healthKit.fetchDailySummary(for: .now) else {
                await MainActor.run { readinessScore = 65 }
                return
            }
            var score = 70.0
            if let sleep = summary.sleepDurationHours {
                if sleep >= 8   { score += 15 }
                else if sleep >= 7 { score += 8 }
                else if sleep >= 6 { score += 0 }
                else if sleep >= 5 { score -= 15 }
                else { score -= 25 }
            }
            if let hrv = summary.hrv {
                if hrv > 60  { score += 10 }
                else if hrv > 40  { score += 3 }
                else { score -= 5 }
            }
            if let rhr = summary.restingHeartRate {
                if rhr < 55  { score += 5 }
                else if rhr < 65  { score += 2 }
                else if rhr > 80  { score -= 10 }
            }
            let final = max(10, min(100, score))
            await MainActor.run {
                withAnimation(.spring(response: 0.8)) {
                    readinessScore = final
                }
            }
        }
    }

    func state(for area: MuscleArea) -> MuscleState {
        guard let entry = affectedAreas.first(where: { $0.areaSlug == area.slug }) else { return .healthy }
        if entry.isJointPain   { return .jointPain }
        if entry.severity >= 4 { return .fatigued }
        return .sore
    }

    func muscleProgress(for area: MuscleArea) -> Double {
        muscleProgressMap[area.slug] ?? 0
    }

    func confirmFatigue(area: MuscleArea, severity: Int, isJointPain: Bool) {
        withAnimation(.spring(response: 0.4)) {
            if let idx = affectedAreas.firstIndex(where: { $0.areaSlug == area.slug }) {
                affectedAreas[idx] = FatigueEntry(areaSlug: area.slug, severity: severity, isJointPain: isJointPain)
            } else {
                affectedAreas.append(FatigueEntry(areaSlug: area.slug, severity: severity, isJointPain: isJointPain))
            }
        }
        // FatigueStore refaktoring na areaSlug namísto celého klonovaného objektu
        // FatigueStore.save(affectedAreas) - Tohle zkontroluji v dalším kroku
    }

    func removeFatigue(area: MuscleArea) {
        affectedAreas.removeAll { $0.areaSlug == area.slug }
        // FatigueStore.save(affectedAreas)
    }
}
