// WorkoutViewWithAI.swift
// Agilní Fitness Trenér — AI wrapper pro WorkoutView
// Načte AI trénink (nebo offline fallback), pak spustí aktivní trénink.

import SwiftUI
import SwiftData

// MARK: - WorkoutViewWithAI

struct WorkoutViewWithAI: View {
    let session: WorkoutSession
    let plannedDay: PlannedWorkoutDay
    let profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService
    @Environment(\.dismiss) private var dismiss

    @State private var trainerResponse: TrainerResponse?
    @State private var isLoading = false   // false = zobraz filter screen nejdřív, true = loading AI
    @State private var loadError: String?
    @State private var showWorkout = false
    @State private var offlineMessage: String?

    // Equipment & time filters (pre-workout)
    @State private var showFilterSheet = false
    @State private var selectedEquipment: Set<Equipment> = []
    @State private var timeLimit: Int? = nil  // nil = neomezeno

    // Gamification handled in WorkoutViewModel.finishWorkout()

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()

            if showWorkout, let response = trainerResponse {
                WorkoutView(
                    session: session,
                    plan: plannedDay,
                    planLabel: plannedDay.label,
                    aiResponse: response,
                    bodyWeightKg: profile.weightKg,
                    onFinish: { xpGains, prEvents in
                        handleWorkoutFinish(xpGains: xpGains, prEvents: prEvents, response: response)
                    }
                )
            } else if isLoading {
                LoadingWorkoutView(
                    planLabel: plannedDay.label,
                    offlineMessage: offlineMessage
                )
            } else if let error = loadError {
                ErrorView(message: error) {
                    Task { await loadWorkout() }
                }
            } else {
                // Pre-workout filter sheet
                PreWorkoutFiltersView(
                    planLabel: plannedDay.label,
                    selectedEquipment: $selectedEquipment,
                    timeLimit: $timeLimit,
                    onStart: {
                        Task { await loadWorkout() }
                    },
                    onDismiss: { dismiss() }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Load AI Workout

    private func loadWorkout() async {
        isLoading = true
        loadError = nil

        let aiService = AITrainerService(modelContext: modelContext, healthKitService: healthKit)

        do {
            let response = try await aiService.generateTodayWorkout(
                for: .now,
                profile: profile,
                plannedDay: plannedDay,
                equipmentOverride: selectedEquipment.isEmpty ? nil : selectedEquipment,
                timeLimitMinutes: timeLimit
            )
            trainerResponse = response
            offlineMessage = aiService.offlineMessage

            // Uložíme sessionLabel do plánu pro budoucí kontext (Gemini continuity)
            if let activePlan = profile.workoutPlans.first(where: \.isActive) {
                activePlan.geminiSessionContext = response.sessionLabel
                try? modelContext.save()
            }

            withAnimation(.spring(response: 0.5)) {
                isLoading = false
                showWorkout = true
            }
        } catch {
            isLoading = false
            loadError = "Nepodařilo se načíst trénink: \(error.localizedDescription)"
        }
    }

    // MARK: - Post-Workout

    private func handleWorkoutFinish(
        xpGains: [XPGain],
        prEvents: [PREvent],
        response: TrainerResponse
    ) {
        // XP a gamification jsou zpracovány ve WorkoutViewModel.finishWorkout()
        // Uložíme kontext pro případ neuložených změn
        do {
            try modelContext.save()
        } catch {
            AppLogger.error("WorkoutViewWithAI: Chyba při ukládání po tréninku: \(error)")
        }

        // Notifikace o dokončení tréninku (streak z Dashboard VM)
        WeeklyReportService.sendWorkoutCompletionNotification(
            streakDays: 1,  // Skutečný streak načte DashboardViewModel při příštím otevření
            sessionLabel: response.sessionLabel
        )
    }
}

// MARK: - Loading View

struct LoadingWorkoutView: View {
    let planLabel: String
    let offlineMessage: String?

    @State private var dots = ""
    @State private var phase = 0

    private let loadingMessages = [
        "Čtu tvá zdravotní data...",
        "Analyzuji únavu svalů...",
        "Vybírám správné váhy...",
        "Připravuji rozcvičku...",
        "Skoro hotovo..."
    ]

    var body: some View {
        VStack(spacing: 32) {
            // Animated trainer avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.45, blue: 1.0), Color.blue.opacity(0.5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.4), radius: 20)

                Text("J")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .scaleEffect(1.0 + sin(Double(phase) * 0.3) * 0.05)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: phase)

            VStack(spacing: 12) {
                Text("Jakub připravuje")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Text(planLabel)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                // Animated loading message
                Text(loadingMessages[min(phase / 2, loadingMessages.count - 1)] + dots)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .animation(.easeInOut, value: phase)
            }

            if let offline = offlineMessage {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text(offline)
                        .font(.system(size: 12))
                        .foregroundStyle(.orange.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .multilineTextAlignment(.center)
            }

            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i <= (phase / 2) ? Color.blue : Color.white.opacity(0.15))
                        .frame(width: 8, height: 8)
                        .animation(.spring(response: 0.3), value: phase)
                }
            }
        }
        .padding(40)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Timer se automaticky zastaví po phase >= 9 (max 4.5s)
        let t = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { t in
            dots = dots.count < 3 ? dots + "." : ""
            if phase < 9 {
                phase += 1
            } else {
                t.invalidate()
            }
        }
        RunLoop.main.add(t, forMode: .common)
    }
}

// MARK: - Pre-Workout Filters View

struct PreWorkoutFiltersView: View {
    let planLabel: String
    @Binding var selectedEquipment: Set<Equipment>
    @Binding var timeLimit: Int?
    let onStart: () -> Void
    let onDismiss: () -> Void

    @State private var selectedPreset: WorkoutPreset? = nil

    enum WorkoutPreset: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case fullGym    = "Plné vybavení"
        case dumbbells  = "Jen jednoručky"
        case bodyweight = "Bez vybavení"
        case hotel      = "Hotelové fitko"
        case min30      = "30 minut"
        case min45      = "45 minut"

        var icon: String {
            switch self {
            case .fullGym:    return "dumbbell.fill"
            case .dumbbells:  return "dumbbell"
            case .bodyweight: return "figure.walk"
            case .hotel:      return "building.2"
            case .min30:      return "timer"
            case .min45:      return "timer"
            }
        }

        var equipment: Set<Equipment>? {
            switch self {
            case .fullGym:    return nil  // vše
            case .dumbbells:  return [.dumbbell]
            case .bodyweight: return [.bodyweight]
            case .hotel:      return [.dumbbell, .bodyweight, .resistanceBand]
            case .min30, .min45: return nil
            }
        }

        var minutes: Int? {
            switch self {
            case .min30: return 30
            case .min45: return 45
            default: return nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("TRÉNINK")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(.white.opacity(0.35))
                                .kerning(1.8)

                            Text(planLabel)
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Quick presets
                        VStack(alignment: .leading, spacing: 12) {
                            Text("RYCHLÉ NASTAVENÍ")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white.opacity(0.3))
                                .kerning(1.5)

                            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 10), count: 3), spacing: 10) {
                                ForEach(WorkoutPreset.allCases) { preset in
                                    PresetButton(
                                        preset: preset,
                                        isSelected: selectedPreset == preset
                                    ) {
                                        withAnimation(.spring(response: 0.25)) {
                                            if selectedPreset == preset {
                                                selectedPreset = nil
                                                selectedEquipment = []
                                                timeLimit = nil
                                            } else {
                                                selectedPreset = preset
                                                selectedEquipment = preset.equipment ?? []
                                                timeLimit = preset.minutes
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Active filter summary
                        if selectedPreset != nil || !selectedEquipment.isEmpty || timeLimit != nil {
                            FilterSummaryView(
                                equipment: selectedEquipment,
                                timeLimit: timeLimit
                            )
                            .padding(.horizontal, 20)
                        }

                        // Start button
                        VStack(spacing: 12) {
                            Button(action: onStart) {
                                HStack(spacing: 12) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Začít trénink")
                                        .font(.system(size: 18, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.20, green: 0.52, blue: 1.0),
                                                    Color(red: 0.08, green: 0.35, blue: 0.85)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: .blue.opacity(0.45), radius: 18, y: 6)
                                )
                            }
                            .buttonStyle(.plain)

                            Button(action: onDismiss) {
                                Text("Zrušit")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

private struct PresetButton: View {
    let preset: PreWorkoutFiltersView.WorkoutPreset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .black : .blue)
                Text(preset.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? .black : .white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FilterSummaryView: View {
    let equipment: Set<Equipment>
    let timeLimit: Int?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                if let t = timeLimit {
                    Text("Časový limit: \(t) minut")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                if !equipment.isEmpty {
                    Text("Vybavení: \(equipment.map { $0.rawValue }.joined(separator: ", "))")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.green.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.green.opacity(0.2), lineWidth: 1))
        )
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("Chyba načítání")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Button("Zkusit znovu", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding(40)
    }
}

// MARK: - Manual Workout Start (when no plan today)

struct ManualWorkoutStartView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                Text("Dnes není plánovaný trénink")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Uprav svůj týdenní plán nebo si přidej trénink na dnes.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                Button(action: onDismiss) {
                    Text("Zavřít")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.1)))
                }
            }
            .padding(40)
        }
        .preferredColorScheme(.dark)
    }
}
