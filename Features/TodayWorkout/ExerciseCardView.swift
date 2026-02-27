// ExerciseCardView.swift
import SwiftUI
import AVFoundation

struct ExerciseCardView: View {
    let exercise: SessionExerciseState
    let exerciseIndex: Int  // Vlastní index tohoto cviku (ne vm.currentExerciseIndex!)
    @ObservedObject var vm: WorkoutViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ExerciseAnimationView(
                    slug: exercise.slug,
                    nameCz: exercise.name,
                    nameEn: exercise.exercise?.nameEN,
                    videoUrl: exercise.videoUrl   // ✅ Předáváme videoUrl z muscle_wiki_data_full
                )
                .frame(height: 260)

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text(exercise.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        if let tip = exercise.coachTip {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.system(size: 13))
                                    .padding(.top, 1)
                                Text(tip)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.yellow.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.yellow.opacity(0.2), lineWidth: 1))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    TechTipsRow(exercise: exercise)
                        .padding(.horizontal, 20)

                    VStack(spacing: 10) {
                        SetHeaderRow()
                        ForEach(exercise.sets.indices, id: \.self) { i in
                            SetRowView(
                                setNumber: i + 1,
                                setData:   $vm.exercises[exerciseIndex].sets[i],
                                isActive:  i == exercise.nextIncompleteSetIndex,
                                onComplete: {
                                    HapticManager.shared.playMediumClick()
                                    vm.completeSet(
                                        exerciseIndex: exerciseIndex,
                                        setIndex: i
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    Button { vm.skipExercise() } label: {
                        Label("Přeskočit cvik", systemImage: "forward.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)  // iOS 16+ - keyboard dismiss on scroll
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - Tech Tips

struct TechTipsRow: View {
    let exercise: SessionExerciseState
    var body: some View {
        HStack(spacing: 10) {
            if let tempo = exercise.tempo {
                TechBadge(icon: "metronome.fill", label: "Tempo", value: tempo, color: .blue)
            }
            TechBadge(icon: "wind", label: "Dýchání", value: "Výdech při zdvihu", color: .teal)
            if exercise.restSeconds > 0 {
                TechBadge(icon: "timer", label: "Pauza", value: "\(exercise.restSeconds)s", color: .orange)
            }
        }
    }
}

struct TechBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 12))
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .kerning(0.8)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.1)))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Exercise Animation

struct ExerciseAnimationView: View {
    let slug: String
    let nameCz: String
    let nameEn: String?
    var videoUrl: String? = nil   // ✅ Video z muscle_wiki_data_full (Supabase Storage)

    @Environment(\.openURL) private var openURL

    // Video state — lazy init jen pokud máme URL
    @State private var videoPlayer: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?

    var body: some View {
        ZStack {
            if let player = videoPlayer {
                // ── REÁLNÉ VIDEO z Supabase Storage ───────────────────────
                ZStack(alignment: .bottomTrailing) {
                    LoopingVideoPlayer(player: player)
                        .clipped()

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .init(x: 0.5, y: 0.5), endPoint: .bottom
                    )
                    .allowsHitTesting(false)

                    // YouTube button jako fallback / doplněk
                    Button {
                        HapticManager.shared.playMediumClick()
                        let url = YouTubeLinkGenerator.searchURL(nameEn: nameEn, nameCz: nameCz)
                        openURL(url)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 11))
                            Text("Technika")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                                .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
                        )
                    }
                    .padding(.bottom, 10)
                    .padding(.trailing, 12)
                }
            } else {
                // ── SF SYMBOL FALLBACK (bez video URL) ────────────────────
                LinearGradient(
                    colors: [Color(white: 0.08), Color.black],
                    startPoint: .top, endPoint: .bottom
                )
                VStack(spacing: 16) {
                    Spacer()
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(exerciseColor(slug).opacity(0.12))
                            .frame(width: 130, height: 130)
                        Circle()
                            .stroke(exerciseColor(slug).opacity(0.2), lineWidth: 1)
                            .frame(width: 130, height: 130)
                        Image(systemName: exerciseIcon(slug))
                            .font(.system(size: 58, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [exerciseColor(slug), exerciseColor(slug).opacity(0.6)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .symbolEffect(.pulse)
                    }

                    VStack(spacing: 4) {
                        Text(exerciseCategoryLabel(slug))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(exerciseColor(slug).opacity(0.6))
                            .kerning(1.5)
                            .textCase(.uppercase)

                        Button {
                            HapticManager.shared.playMediumClick()
                            let url = YouTubeLinkGenerator.searchURL(nameEn: nameEn, nameCz: nameCz)
                            openURL(url)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 12))
                                Text("Technika")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.8))
                                    .shadow(color: .red.opacity(0.3), radius: 4, y: 2)
                            )
                        }
                        .padding(.top, 4)
                    }

                    Spacer()
                }
                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .init(x: 0.5, y: 0.55), endPoint: .bottom
                )
            }
        }
        .onAppear { setupVideo() }
        .onDisappear {
            videoPlayer?.pause()
            playerLooper = nil
            videoPlayer = nil
        }
        .onChange(of: videoUrl) { setupVideo() }
    }

    // MARK: Video Setup

    private func setupVideo() {
        videoPlayer?.pause()
        playerLooper = nil
        videoPlayer = nil

        guard let urlString = videoUrl, let url = URL(string: urlString) else { return }
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: item)
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted = true
        player.play()
        videoPlayer = player
    }

    private func exerciseIcon(_ slug: String) -> String {
        let s = slug.lowercased()
        // POZOR: "dumbbell.fill" existuje jen v iOS 18+ → nepoužíváme
        if s.contains("bench") || s.contains("chest") || s.contains("fly") { return "figure.strengthtraining.traditional" }
        if s.contains("press") && (s.contains("shoulder") || s.contains("overhead") || s.contains("ohp")) { return "figure.arms.open" }
        if s.contains("press") { return "figure.strengthtraining.traditional" }
        if s.contains("squat") { return "figure.strengthtraining.traditional" }
        if s.contains("leg-press") || s.contains("leg_press") { return "figure.strengthtraining.traditional" }
        if s.contains("deadlift") || s.contains("rdl") || s.contains("hip-thrust") { return "figure.strengthtraining.functional" }
        if s.contains("pull-up") || s.contains("pullup") || s.contains("chin") { return "figure.gymnastics" }
        if s.contains("row") || s.contains("pull") || s.contains("lat") { return "figure.rowing" }
        if s.contains("curl") || s.contains("bicep") { return "figure.arms.open" }
        if s.contains("tricep") || s.contains("extension") || s.contains("pushdown") { return "figure.arms.open" }
        if s.contains("calf") || s.contains("raise") { return "figure.walk" }
        if s.contains("lateral") || s.contains("shoulder") || s.contains("delt") { return "figure.arms.open" }
        if s.contains("plank") || s.contains("core") || s.contains("ab") || s.contains("crunch") { return "figure.core.training" }
        if s.contains("run") || s.contains("cardio") || s.contains("treadmill") { return "figure.run" }
        if s.contains("warmup") || s.contains("warm") || s.contains("stretch") { return "figure.flexibility" }
        return "figure.strengthtraining.traditional"
    }

    private func exerciseColor(_ slug: String) -> Color {
        let s = slug.lowercased()
        if s.contains("bench") || s.contains("chest") || s.contains("press") { return .blue }
        if s.contains("pull") || s.contains("row") || s.contains("lat") { return .purple }
        if s.contains("squat") || s.contains("leg") || s.contains("deadlift") { return Color(red: 0.3, green: 0.8, blue: 0.4) }
        if s.contains("shoulder") || s.contains("lateral") || s.contains("overhead") { return .orange }
        if s.contains("curl") || s.contains("bicep") { return .cyan }
        if s.contains("tricep") || s.contains("pushdown") { return Color(red: 0.9, green: 0.5, blue: 0.2) }
        if s.contains("core") || s.contains("plank") || s.contains("ab") { return .yellow }
        if s.contains("warmup") || s.contains("stretch") { return .teal }
        return .blue
    }

    private func exerciseCategoryLabel(_ slug: String) -> String {
        let s = slug.lowercased()
        if s.contains("bench") || s.contains("chest") { return "Hrudník" }
        if s.contains("pull") || s.contains("row") || s.contains("lat") { return "Záda" }
        if s.contains("squat") || s.contains("leg") { return "Nohy" }
        if s.contains("deadlift") || s.contains("rdl") { return "Zadní řetězec" }
        if s.contains("shoulder") || s.contains("lateral") || s.contains("overhead") { return "Ramena" }
        if s.contains("curl") || s.contains("bicep") { return "Biceps" }
        if s.contains("tricep") || s.contains("pushdown") || s.contains("extension") { return "Triceps" }
        if s.contains("core") || s.contains("plank") || s.contains("ab") { return "Střed těla" }
        if s.contains("warmup") || s.contains("stretch") { return "Rozcvička" }
        if s.contains("calf") { return "Lýtka" }
        return "Silový trénink"
    }
}
