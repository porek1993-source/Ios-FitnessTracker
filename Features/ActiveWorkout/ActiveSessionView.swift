// ActiveSessionView.swift
// Agilní Fitness Trenér — Aktivní tréninková session
//
// Drop-in náhrada za WorkoutView.swift
// Zachovává 100% kompatibilitu s WorkoutViewModel, SetState, SessionExerciseState

import SwiftUI
import SwiftData
import AVFoundation

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ActiveSessionView — Root Container
// MARK: ═══════════════════════════════════════════════════════════════════════

struct ActiveSessionView: View {

    @StateObject private var vm: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showSwap       = false
    @State private var showFinishDlg  = false

    init(session: WorkoutSession, plan: PlannedWorkoutDay, planLabel: String) {
        _vm = StateObject(wrappedValue: WorkoutViewModel(
            session: session, plan: plan, planLabel: planLabel
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Static background
            AppColors.background.ignoresSafeArea()

            // ── Paged exercise cards
            TabView(selection: $vm.currentExerciseIndex) {
                ForEach(vm.exercises.indices, id: \.self) { idx in
                    ExercisePageView(
                        exercise:      $vm.exercises[idx],
                        vm:            vm,
                        exerciseIndex: idx,
                        onSwap:        { showSwap = true },
                        onComplete:    { setIdx in
                            vm.completeSet(exerciseIndex: idx, setIndex: setIdx)
                        }
                    )
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .animation(.spring(response: 0.44, dampingFraction: 0.80), value: vm.currentExerciseIndex)

            // ── Pinned header
            VStack {
                SessionHeaderBar(vm: vm, onFinish: { showFinishDlg = true })
                Spacer()
            }

            // ── Rest timer — slides up from bottom
            if vm.isResting {
                RestTimerDock(vm: vm)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal:   .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .zIndex(20)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .sheet(isPresented: $showSwap) {
            let idx = vm.currentExerciseIndex
            if vm.exercises.indices.contains(idx) {
                SmartSwapSheet(exercise: vm.exercises[idx]) { newName, newSlug in
                    vm.swapExercise(at: idx, newName: newName, newSlug: newSlug)
                    showSwap = false
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(AppColors.secondaryBg)
            }
        }
        .confirmationDialog("Dokončit trénink?", isPresented: $showFinishDlg, titleVisibility: .visible) {
            Button("Uložit a ukončit") { vm.finishWorkout(modelContext: modelContext); dismiss() }
            Button("Pokračovat", role: .cancel) {}
        } message: {
            Text("Všechny zalogované série budou uloženy.")
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Session Header Bar
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct SessionHeaderBar: View {
    @ObservedObject var vm: WorkoutViewModel
    let onFinish: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text("ČAS")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.white.opacity(0.32))
                    .kerning(1.6)
                Text(vm.elapsedTimeFormatted)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(width: 80, alignment: .leading)

            Spacer()

            HStack(spacing: 7) {
                ForEach(vm.exercises.indices, id: \.self) { i in
                    ExerciseDot(
                        state: i < vm.currentExerciseIndex ? .done
                             : i == vm.currentExerciseIndex ? .active
                             : .pending
                    )
                }
            }

            Spacer()

            Button(action: onFinish) {
                Text("Hotovo")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.09))
                            .overlay(Capsule().stroke(.white.opacity(0.11), lineWidth: 1))
                    )
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 22)
        .padding(.top, 56)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial.opacity(0.92))
        .overlay(alignment: .bottom) { Divider().opacity(0.07) }
    }
}

private struct ExerciseDot: View {
    enum DotState { case done, active, pending }
    let state: DotState

    var body: some View {
        ZStack {
            Circle()
                .fill(dotFill)
                .frame(width: dotSize, height: dotSize)
            if state == .done {
                Image(systemName: "checkmark")
                    .font(.system(size: 4.5, weight: .black))
                    .foregroundStyle(.black)
            }
        }
        .animation(.spring(response: 0.28), value: state == .active)
    }

    private var dotFill: Color {
        switch state {
        case .done:    return Color(red: 0.15, green: 0.82, blue: 0.45)
        case .active:  return .white
        case .pending: return .white.opacity(0.18)
        }
    }
    private var dotSize: CGFloat { state == .active ? 9 : 6 }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ExercisePageView
// MARK: ═══════════════════════════════════════════════════════════════════════

struct ExercisePageView: View {
    @Binding var exercise: SessionExerciseState
    @ObservedObject var vm: WorkoutViewModel
    let exerciseIndex: Int
    let onSwap:        () -> Void
    let onComplete:    (Int) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 110)

                ExerciseHero(exercise: exercise, onSwap: onSwap)

                VStack(spacing: 20) {
                    if let tip = exercise.coachTip {
                        CoachTipCard(text: tip)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    TechniquePillRow(exercise: exercise, vm: vm)

                    SetLoggerBlock(exercise: $exercise, onComplete: onComplete)

                    Button(action: vm.skipExercise) {
                        Label("Přeskočit cvik", systemImage: "forward.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .padding(.bottom, 48)
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ExerciseHero
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct ExerciseHero: View {
    let exercise: SessionExerciseState
    let onSwap:   () -> Void

    @State private var glowPulse = false
    @State private var videoPlayer: AVQueuePlayer?
    @State private var playerLooper: AVPlayerLooper?

    private var completedSets: Int { exercise.sets.filter(\.isCompleted).count }
    private var totalSets: Int     { exercise.sets.count }
    private var progress: Double   { totalSets > 0 ? Double(completedSets) / Double(totalSets) : 0 }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [AppColors.tertiaryBg,
                         AppColors.background],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 230)

            // Ambient glow
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 140, height: 140)
                .blur(radius: 32)
                .scaleEffect(glowPulse ? 1.25 : 0.85)
                .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: glowPulse)
                .offset(y: -30)

            // Video / ikona cviku — používá videoUrl z muscle_wiki_data_full pokud je k dispozici
            VStack(spacing: 0) {
                if let player = videoPlayer {
                    // ✅ Reálné video z Supabase Storage (muscle_wiki_data_full.video_url)
                    LoopingVideoPlayer(player: player)
                        .frame(height: 230)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.3), Color.clear, Color.clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                } else {
                    // Fallback ikona pokud video URL není k dispozici
                    Image(systemName: iconForSlug(exercise.slug))
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan.opacity(0.75)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                        .padding(.top, 28)

                    Text("VIDEO TECHNIKY")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.white.opacity(0.16))
                        .kerning(1.0)
                        .padding(.top, 10)

                    Spacer()
                }
            }
            .frame(height: 230)
            .onAppear { setupVideoPlayer() }
            .onDisappear { videoPlayer?.pause() }
            .onChange(of: exercise.id) { setupVideoPlayer() }

            // Bottom: name + progress + swap button
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, Color(hue: 0.62, saturation: 0.18, brightness: 0.07)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 76)

                HStack(alignment: .bottom, spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) {
                        // Set capsule progress
                        HStack(spacing: 4) {
                            ForEach(0..<totalSets, id: \.self) { i in
                                Capsule()
                                    .fill(i < completedSets
                                          ? Color(red:0.15, green:0.82, blue:0.45)
                                          : Color.white.opacity(0.15))
                                    .frame(width: i < completedSets ? 16 : 10, height: 4)
                                    .animation(.spring(response: 0.3), value: completedSets)
                            }
                        }
                        Text(exercise.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 12)

                    // Smart Swap button
                    Button(action: onSwap) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Swap")
                                .font(.system(size: 9, weight: .bold))
                                .kerning(0.3)
                        }
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 54, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppColors.glassBg)
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppColors.border, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
                .background(AppColors.background)

                // Progress bar
                ZStack(alignment: .leading) {
                    Rectangle().fill(.white.opacity(0.05))
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [AppColors.primaryAccent, AppColors.accentCyan.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: UIScreen.main.bounds.width * progress)
                        .animation(.spring(response: 0.5), value: progress)
                }
                .frame(height: 2.5)
            }
        }
        .onAppear { glowPulse = true }
    }

    private func setupVideoPlayer() {
        // Zastavit předchozí přehrávání
        videoPlayer?.pause()
        playerLooper = nil
        videoPlayer = nil

        guard let urlString = exercise.videoUrl,
              let url = URL(string: urlString) else { return }

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: item)
        playerLooper = AVPlayerLooper(player: player, templateItem: item)
        player.isMuted = true   // Video jako vizuální reference — bez zvuku
        player.play()
        videoPlayer = player
    }

    private func iconForSlug(_ slug: String) -> String {
        if slug.contains("bench") || slug.contains("chest") { return "scalemass.fill" }
        if slug.contains("press") && !slug.contains("leg")  { return "scalemass.fill" }
        if slug.contains("squat") || slug.contains("leg")   { return "figure.strengthtraining.traditional" }
        if slug.contains("pull")  || slug.contains("row")   { return "figure.gymnastics" }
        if slug.contains("curl")  || slug.contains("bicep") { return "figure.arms.open" }
        if slug.contains("dead")                            { return "figure.strengthtraining.functional" }
        return "figure.core.training"
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: CoachTipCard
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct CoachTipCard: View {
    let text: String
    @State private var revealed = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red:0.20, green:0.52, blue:1.0),
                                 Color(red:0.08, green:0.32, blue:0.82)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 30, height: 30)
                Text("iK")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("iKorba")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.38))
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.87))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red:0.09, green:0.14, blue:0.26))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1))
        )
        .offset(y: revealed ? 0 : 6)
        .opacity(revealed ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.45).delay(0.12)) { revealed = true } }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Technique Pills
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct TechniquePillRow: View {
    let exercise: SessionExerciseState
    @ObservedObject var vm: WorkoutViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let t = exercise.tempo {
                    TechPill(icon: "metronome.fill", label: "Tempo",    value: t,
                             color: Color(red:0.28, green:0.55, blue:1.0),
                             vm: vm)
                }
                TechPill(icon: "wind",              label: "Dýchání",  value: "Výdech při zdvihu",
                         color: Color(red:0.12, green:0.72, blue:0.62),
                         vm: vm)
                if exercise.restSeconds > 0 {
                    TechPill(icon: "timer",          label: "Pauza",    value: "\(exercise.restSeconds)s",
                             color: .orange,
                             vm: vm)
                }
                TechPill(icon: "repeat",            label: "Série",    value: "\(exercise.sets.count)×",
                         color: Color(red:0.65, green:0.35, blue:1.0),
                         vm: vm)
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct TechPill: View {
    let icon: String; let label: String; let value: String; let color: Color
    @ObservedObject var vm: WorkoutViewModel

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 7.5, weight: .black))
                    .foregroundStyle(.white.opacity(0.30))
                    .kerning(0.5)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            
            // Metronome button for Tempo
            if label == "Tempo" {
                Button {
                    vm.startTempoForCurrentExercise()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(color.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(color.opacity(0.18), lineWidth: 1))
        )
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: SetLoggerBlock
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct SetLoggerBlock: View {
    @Binding var exercise: SessionExerciseState
    let onComplete: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            setList
            summary
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1))
        )
    }
    
    private var header: some View {
        HStack {
            Text("#")         .frame(width: 38, alignment: .center)
            Text("VÁHA")      .frame(maxWidth: .infinity)
            Text("REPS")      .frame(width: 66)
            Text("RPE")       .frame(width: 52)
            Spacer()          .frame(width: 48)
        }
        .font(.system(size: 9, weight: .black))
        .foregroundStyle(.white.opacity(0.26))
        .kerning(1.0)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var setList: some View {
        VStack(spacing: 12) {
            let warmupSets = exercise.sets.enumerated().filter { $0.element.isWarmup }
            let workingSets = exercise.sets.enumerated().filter { !$0.element.isWarmup }
            
            if !warmupSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Zahřívací série", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange.opacity(0.8))
                        .padding(.horizontal, 12)
                    
                    ForEach(warmupSets, id: \.offset) { i, _ in
                        ActiveSetRow(
                            setNumber: 0,
                            currentSet: $exercise.sets[i],
                            isActive: i == exercise.nextIncompleteSetIndex,
                            onComplete: { onComplete(i) }
                        )
                    }
                }
            }
            
            if !workingSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Pracovní série", systemImage: "target")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.blue.opacity(0.8))
                        .padding(.horizontal, 12)
                    
                    ForEach(workingSets, id: \.offset) { i, _ in
                        ActiveSetRow(
                            setNumber: calculateWorkingSetNumber(for: i),
                            currentSet: $exercise.sets[i],
                            isActive: i == exercise.nextIncompleteSetIndex,
                            onComplete: { onComplete(i) }
                        )
                    }
                }
            }
        }
    }
    
    private func calculateWorkingSetNumber(for index: Int) -> Int {
        if exercise.sets[index].isWarmup { return 0 }
        // Sečteme jen pracovní série před tímto indexem
        let workingSetsBefore = exercise.sets[...index].filter { !$0.isWarmup }.count
        return workingSetsBefore
    }

    @ViewBuilder
    private var summary: some View {
        if exercise.sets.contains(where: \.isCompleted) {
            VolumeSummary(sets: exercise.sets)
                .padding(.top, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ActiveSetRow (SetRowView)
// MARK: ═══════════════════════════════════════════════════════════════════════

struct ActiveSetRow: View {

    let setNumber:  Int
    @Binding var currentSet: SetState
    let isActive:   Bool
    let onComplete: () -> Void

    @FocusState private var wFocus: Bool
    @FocusState private var rFocus: Bool

    @State private var weightText = ""
    @State private var repsText   = ""
    @State private var showRPE    = false
    @State private var bounce:    CGFloat = 1

    var body: some View {
        HStack(spacing: 0) {

            // ① Badge
            // Zjistíme pořadové číslo pracovní série (zahřívací se nepočítají do pracovního progresu)
            SetBadge(number: setNumber, isCompleted: currentSet.isCompleted, isActive: isActive, isWarmup: currentSet.isWarmup)
                .frame(width: 38)

            // ② Weight
            InlineField(
                text:        $weightText,
                hint:        previousWeightHint,
                suffix:      "kg",
                keyboard:    .decimalPad,
                isFocused:   _wFocus,
                isActive:    isActive,
                isCompleted: currentSet.isCompleted
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
            .onChange(of: weightText) { _, v in
                currentSet.weightKg = Double(v.replacingOccurrences(of: ",", with: "."))
            }

            // ③ Reps
            InlineField(
                text:        $repsText,
                hint:        "\(currentSet.targetRepsMin)–\(currentSet.targetRepsMax)",
                suffix:      nil,
                keyboard:    .numberPad,
                isFocused:   _rFocus,
                isActive:    isActive,
                isCompleted: currentSet.isCompleted
            )
            .frame(width: 66)
            .padding(.horizontal, 4)
            .onChange(of: repsText) { _, v in currentSet.reps = Int(v) }

            // ④ RPE
            RPECell(value: $currentSet.rpe, isActive: isActive, isCompleted: currentSet.isCompleted)
                .frame(width: 52)
                .onTapGesture { if isActive && !currentSet.isCompleted { showRPE = true } }
                .sheet(isPresented: $showRPE) {
                    RPEPickerView(selected: $currentSet.rpe)
                        .presentationDetents([.height(280)])
                }

            // ⑤ Complete
            CompleteButton(
                canComplete: canComplete,
                isActive:    isActive,
                isCompleted: currentSet.isCompleted,
                bounce:      bounce,
                action:      handleComplete
            )
            .frame(width: 48)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(enhancedRowBackground)
        .opacity(rowOpacity)
        .animation(.easeInOut(duration: 0.18), value: isActive)
        .animation(.easeInOut(duration: 0.18), value: currentSet.isCompleted)
        .onAppear {
            if let prev = currentSet.previousWeightKg {
                weightText   = prev.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", prev) : String(format: "%.1f", prev)
                currentSet.weightKg = prev
            }
        }
    }

    private var previousWeightHint: String {
        guard let prev = currentSet.previousWeightKg else { return "—" }
        return prev.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", prev) : String(format: "%.1f", prev)
    }

    private var isBodyweight: Bool { currentSet.previousWeightKg == nil && currentSet.weightKg == nil }
    private var canComplete: Bool { currentSet.reps != nil && (isBodyweight || currentSet.weightKg != nil) }

    private func handleComplete() {
        withAnimation(.spring(response: 0.12, dampingFraction: 0.45)) { bounce = 0.80 }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55).delay(0.1)) { bounce = 1.0 }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        onComplete()
    }

    // ✅ OPRAVENO: Vylepšený kontrast pro fitness studio (nahrazuje původní rowBG)
    // Aktuální série: výraznější rámeček v akcentní barvě, lépe čitelné pod přímým světlem
    private var rowBG: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isActive
                   ? Color(red: 0.14, green: 0.14, blue: 0.20)   // světlejší než AppColors.tertiaryBg
                   : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isActive
                            ? AppColors.primaryAccent.opacity(0.6)  // výraznější akcent
                            : Color.clear,
                        lineWidth: isActive ? 1.5 : 0
                    )
            )
            .shadow(
                color: isActive ? AppColors.primaryAccent.opacity(0.15) : .clear,
                radius: 8, x: 0, y: 0
            )
    }

    private var rowOpacity: Double {
        // Dokončená série: enhancedRowBackground zobrazuje zelené pozadí — nefadovat
        // Neaktivní nedokončená: 45% průhlednost pro focus na aktivní sérii
        if currentSet.isCompleted { return 0.85 }
        return isActive ? 1.0 : 0.45
    }
}

// MARK: - Sub-views for SetRow

private struct SetBadge: View {
    let number: Int; let isCompleted: Bool; let isActive: Bool; let isWarmup: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(bgColor)
                .frame(width: 30, height: 30)
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.black)
            } else {
                Text(isWarmup ? "W" : "\(number)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.32))
            }
        }
        .animation(.spring(response: 0.22), value: isCompleted)
    }

    private var bgColor: Color {
        if isCompleted { return Color(red:0.13, green:0.80, blue:0.43) }
        if isActive && isWarmup { return Color.orange.opacity(0.4) }
        if isActive    { return .white.opacity(0.14) }
        if isWarmup    { return Color.orange.opacity(0.15) }
        return .white.opacity(0.05)
    }
}

private struct InlineField: View {
    @Binding var text: String
    let hint: String; let suffix: String?
    let keyboard: UIKeyboardType
    @FocusState var isFocused: Bool
    let isActive: Bool; let isCompleted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fieldBg)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isFocused ? Color.blue.opacity(0.65) : Color.clear, lineWidth: 1.5))

            if text.isEmpty && !isFocused {
                Text(hint)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.20))
            }

            HStack(spacing: 2) {
                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .focused($isFocused)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .disabled(!isActive || isCompleted)
                if let s = suffix, !text.isEmpty {
                    Text(s).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.28))
                }
            }
        }
        .frame(height: 52)
    }

    private var fieldBg: Color {
        if isFocused { return .white.opacity(0.10) }
        return isActive ? .white.opacity(0.07) : .clear
    }
}

private struct RPECell: View {
    @Binding var value: Int?
    let isActive: Bool; let isCompleted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive && !isCompleted ? Color.white.opacity(0.07) : Color.clear)

            if let v = value {
                VStack(spacing: 1) {
                    Text("\(v)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(rpeColor(v))
                    Text("RPE")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.white.opacity(0.26))
                        .kerning(0.4)
                }
            } else {
                Image(systemName: "dial.low")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(isActive ? 0.30 : 0.13))
            }
        }
        .frame(height: 52)
        .contentShape(Rectangle())
    }

    private func rpeColor(_ v: Int) -> Color {
        Color.rpeColor(for: v)
    }
}

private struct CompleteButton: View {
    let canComplete: Bool; let isActive: Bool; let isCompleted: Bool
    let bounce: CGFloat; let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(btnFill)
                    .frame(width: 42, height: 42)
                    .shadow(
                        color: isActive && canComplete
                            ? Color(red:0.13, green:0.80, blue:0.43).opacity(0.38) : .clear,
                        radius: 8, y: 4
                    )
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark")
                    .font(.system(size: isCompleted ? 21 : 15, weight: .bold))
                    .foregroundStyle(btnIcon)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isActive && !isCompleted)
        .scaleEffect(bounce)
        .animation(.spring(response: 0.22), value: isCompleted)
    }

    private var btnFill: Color {
        if isCompleted             { return .clear }
        if isActive && canComplete { return AppColors.success.opacity(0.88) }
        return .white.opacity(0.07)
    }
    private var btnIcon: Color {
        if isCompleted             { return AppColors.success }
        if isActive && canComplete { return .white }
        return .white.opacity(0.18)
    }
}

// MARK: - RPE Picker Sheet

private struct RPEPickerView: View {
    @Binding var selected: Int?
    @Environment(\.dismiss) private var dismiss

    private let labels = [
        1:"Velmi lehce", 2:"Lehce", 3:"Mírně", 4:"Trochu snaha", 5:"Střední",
        6:"Náročné",     7:"Těžké", 8:"Velmi těžké", 9:"Maximální", 10:"Absolutní max"
    ]

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(.white.opacity(0.2)).frame(width: 36, height: 4).padding(.top, 10)
            Text("Jak těžká série?")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                spacing: 8
            ) {
                ForEach(1...10, id: \.self) { i in
                    Button {
                        selected = i
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(i)").font(.system(size: 21, weight: .black, design: .rounded))
                            Text(labels[i] ?? "").font(.system(size: 7.5)).multilineTextAlignment(.center).lineLimit(2)
                        }
                        .foregroundStyle(selected == i ? .black : .white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(selected == i ? rpeColor(i) : Color.white.opacity(0.09)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 20)
        }
        .background(AppColors.secondaryBg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func rpeColor(_ v: Int) -> Color {
        Color.rpeColor(for: v)
    }
}

// MARK: - Volume Summary

private struct VolumeSummary: View {
    let sets: [SetState]
    private var done: [SetState] { sets.filter(\.isCompleted) }
    private var volume: Double {
        done.reduce(0) { $0 + (($1.weightKg ?? 0) * Double($1.reps ?? 0)) }
    }
    private var avgRPE: Double? {
        let r = done.compactMap(\.rpe); guard !r.isEmpty else { return nil }
        return Double(r.reduce(0,+)) / Double(r.count)
    }

    var body: some View {
        HStack {
            SummaryPill(icon: "scalemass.fill",   value: "\(Int(volume)) kg", label: "objem",  tint: .blue)
            Spacer()
            SummaryPill(icon: "checkmark.circle", value: "\(done.count)×",    label: "série",  tint: Color(red:0.13, green:0.80, blue:0.43))
            if let r = avgRPE {
                Spacer()
                SummaryPill(icon: "dial.medium",  value: String(format:"%.1f",r), label: "ø RPE", tint: .orange)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1))
        )
        .padding(.horizontal, 10)
    }
}

private struct SummaryPill: View {
    let icon: String; let value: String; let label: String; let tint: Color
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(tint)
            Text(value).font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.system(size: 9)).foregroundStyle(.white.opacity(0.28))
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Rest Timer Dock
// MARK: ═══════════════════════════════════════════════════════════════════════

struct RestTimerDock: View {
    @ObservedObject var vm: WorkoutViewModel
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35)) { expanded.toggle() }
            } label: {
                VStack(spacing: 6) {
                    Capsule()
                        .fill(.white.opacity(0.22))
                        .frame(width: 36, height: 4)
                        .padding(.top, 10)

                    if !expanded {
                        collapsedRow
                            .padding(.bottom, 12)
                            .transition(.opacity)
                    }
                }
            }
            .buttonStyle(.plain)

            if expanded {
                expandedContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: expanded ? 0 : 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: expanded ? 0 : 24, style: .continuous)
                    .stroke(.white.opacity(0.09), lineWidth: 1))
        )
        .ignoresSafeArea(edges: expanded ? .bottom : [])
        .padding(.horizontal, expanded ? 0 : 14)
        .padding(.bottom, expanded ? 0 : 20)
        .onAppear { withAnimation(.spring(response: 0.5).delay(0.15)) { expanded = true } }
    }

    private var collapsedRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(.white.opacity(0.08), lineWidth: 3).frame(width: 30, height: 30)
                Circle()
                    .trim(from: 0, to: vm.restProgress)
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: vm.restProgress)
            }
            Text("Pauza  \(vm.restTimeFormatted)")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.up").font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 20)
    }

    private var expandedContent: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle().stroke(.white.opacity(0.06), lineWidth: 11).frame(width: 190, height: 190)
                Circle()
                    .trim(from: 0, to: vm.restProgress)
                    .stroke(
                        AngularGradient(
                            colors: [Color(red:0.20, green:0.52, blue:1.0).opacity(0.5), Color.cyan],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 11, lineCap: .round)
                    )
                    .frame(width: 190, height: 190)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: vm.restProgress)

                Circle().fill(Color.cyan.opacity(0.08)).frame(width: 90, height: 90).blur(radius: 18)

                VStack(spacing: 2) {
                    Text(vm.restTimeFormatted)
                        .font(.system(size: 58, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.spring(response: 0.25), value: vm.restSecondsRemaining)
                    Text("PAUZA")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white.opacity(0.30))
                        .kerning(2.5)
                }
            }
            .padding(.top, 8)

            HStack(spacing: 14) {
                DockAdjustBtn(label: "−15s") { vm.adjustRest(by: -15) }
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    vm.skipRest()
                } label: {
                    Text("Přeskočit pauzu")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Capsule().fill(.white)
                            .shadow(color: .white.opacity(0.18), radius: 14, y: 5))
                }
                .buttonStyle(.plain)
                DockAdjustBtn(label: "+15s") { vm.adjustRest(by: +15) }
            }
            .padding(.horizontal, 22).padding(.bottom, 36)
        }
    }
}

private struct DockAdjustBtn: View {
    let label: String; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .frame(width: 64, height: 52)
                .background(Capsule().fill(.white.opacity(0.10))
                    .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1)))
        }.buttonStyle(.plain)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: SmartSwapSheet
// MARK: ═══════════════════════════════════════════════════════════════════════

struct SmartSwapSheet: View {
    let exercise:  SessionExerciseState
    let onSwap:    (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var filter:     EquipmentFilter = .all
    @State private var appeared    = false
    @State private var searchText  = ""

    private var candidates: [WorkoutSwapCandidate] {
        SwapDatabase.candidates(for: exercise.slug, filter: filter)
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 12).padding(.bottom, 16)

            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NAHRADIT CVIK")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white.opacity(0.30)).kerning(1.4)
                    Text(exercise.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.white.opacity(0.10)))
                }
            }
            .padding(.horizontal, 20)

            // Search
            SearchBar(text: $searchText)
                .padding(.horizontal, 16).padding(.top, 12)

            // Filters
            FilterScroll(selected: $filter)
                .padding(.top, 12)

            // Content
            if candidates.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 42)).foregroundStyle(.white.opacity(0.18))
                    Text("Žádné alternativy")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.35))
                    Text("Zkus jiný filtr")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.22))
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(candidates.enumerated()), id: \.element.id) { idx, c in
                            SwapCandidateCard(candidate: c, rank: idx) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onSwap(c.name, c.slug)
                            }
                            .offset(y: appeared ? 0 : 20)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.48, dampingFraction: 0.78).delay(Double(idx) * 0.065),
                                value: appeared
                            )
                        }
                        Spacer(minLength: 44)
                    }
                    .padding(.horizontal, 16).padding(.top, 14)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(.spring(response: 0.5)) { appeared = true } }
    }
}

// MARK: - Search Bar

private struct SearchBar: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(.white.opacity(0.35))
            TextField("Hledat alternativu…", text: $text)
                .font(.system(size: 14)).foregroundStyle(.white).tint(.blue)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(.white.opacity(0.09), lineWidth: 1))
        )
    }
}

// MARK: - Equipment Filter

enum EquipmentFilter: String, CaseIterable {
    case all        = "Vše"
    case dumbbell   = "Jednoručky"
    case bodyweight = "Bodyweight"
    case cable      = "Kabelák"
    case machine    = "Stroj"
    case barbell    = "Činka"
}

private struct FilterScroll: View {
    @Binding var selected: EquipmentFilter
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EquipmentFilter.allCases, id: \.self) { f in
                    Button {
                        withAnimation(.spring(response: 0.26)) { selected = f }
                    } label: {
                        Text(f.rawValue)
                            .font(.system(size: 13, weight: selected == f ? .bold : .medium))
                            .foregroundStyle(selected == f ? .black : .white.opacity(0.58))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                Capsule().fill(selected == f ? Color.blue : .white.opacity(0.09))
                                    .overlay(Capsule().stroke(
                                        selected == f ? .clear : .white.opacity(0.10), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.24), value: selected == f)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Candidate Card

private struct SwapCandidateCard: View {
    let candidate: WorkoutSwapCandidate
    let rank:      Int
    let onSelect:  () -> Void
    @State private var expanded = false

    private var scoreColor: Color {
        candidate.matchScore >= 85 ? Color(red:0.13, green:0.80, blue:0.43)
            : candidate.matchScore >= 68 ? .blue
            : .white.opacity(0.35)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Score ring
                ZStack {
                    Circle().stroke(.white.opacity(0.07), lineWidth: 4).frame(width: 46, height: 46)
                    Circle()
                        .trim(from: 0, to: CGFloat(candidate.matchScore) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 46, height: 46)
                        .rotationEffect(.degrees(-90))
                    Text("\(candidate.matchScore)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(scoreColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(candidate.name)
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        if rank == 0 {
                            Text("DOPORUČENO")
                                .font(.system(size: 7.5, weight: .black)).foregroundStyle(.black)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color(red:0.13, green:0.80, blue:0.43)))
                        }
                    }
                    HStack(spacing: 6) {
                        Label(candidate.equipment, systemImage: candidate.equipIcon)
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.38))
                        Text("·").foregroundStyle(.white.opacity(0.18))
                        Text(candidate.muscles)
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.38)).lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.22))
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.spring(response: 0.32)) { expanded.toggle() } }

            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().background(.white.opacity(0.08))

                    if let tip = candidate.coachTip {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 11)).foregroundStyle(.yellow).padding(.top, 1)
                            Text(tip)
                                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.72)).lineSpacing(2)
                        }
                        .padding(.horizontal, 16)
                    }

                    Button(action: onSelect) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Nahradit za \(candidate.name)")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color(red:0.20, green:0.52, blue:1.0),
                                             Color(red:0.08, green:0.32, blue:0.82)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14).padding(.bottom, 14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(rank == 0
                      ? Color(hue: 0.62, saturation: 0.28, brightness: 0.15)
                      : Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(rank == 0 ? Color.blue.opacity(0.20) : Color.white.opacity(0.07),
                            lineWidth: 1))
        )
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: SwapCandidate Data Layer
// MARK: ═══════════════════════════════════════════════════════════════════════

struct WorkoutSwapCandidate: Identifiable {
    let id          = UUID()
    let name:       String
    let slug:       String
    let matchScore: Int
    let equipment:  String
    let muscles:    String
    let coachTip:   String?

    var equipIcon: String {
        switch equipment {
        case "Jednoručky":  return "scalemass.fill"
        case "Bodyweight":  return "figure.strengthtraining.functional"
        case "Kabelák":     return "arrow.up.and.down.circle"
        case "Stroj":       return "gearshape.fill"
        case "Činka":       return "barbell"
        default:            return "dumbbell"
        }
    }
}

enum SwapDatabase {
    static func candidates(for slug: String, filter: EquipmentFilter) -> [WorkoutSwapCandidate] {
        let pool: [WorkoutSwapCandidate]
        switch slugCategory(slug) {
        case "chest":    pool = chest
        case "back":     pool = back
        case "legs":     pool = legs
        case "shoulder": pool = shoulders
        case "arms":     pool = arms
        default:         pool = chest + back + legs
        }

        let filtered = filter == .all
            ? pool
            : pool.filter { $0.equipment == filter.rawValue }

        return filtered.sorted { $0.matchScore > $1.matchScore }
    }

    private static func slugCategory(_ slug: String) -> String {
        if slug.contains("bench") || slug.contains("chest") || slug.contains("fly")  { return "chest" }
        if slug.contains("row")   || slug.contains("pull")  || slug.contains("lat")  { return "back" }
        if slug.contains("squat") || slug.contains("leg")   || slug.contains("dead") { return "legs" }
        if slug.contains("shoulder") || (slug.contains("press") && slug.contains("over")) { return "shoulder" }
        if slug.contains("curl") || slug.contains("tricep") || slug.contains("bicep") { return "arms" }
        return "general"
    }

    static let chest: [WorkoutSwapCandidate] = [
        WorkoutSwapCandidate(name: "Tlaky s jednoručkami",  slug: "db-bench-press",       matchScore: 95,
                      equipment: "Jednoručky", muscles: "Prsní, triceps, deltoid",
                      coachTip: "Větší rozsah pohybu než s osou — cítíš protažení v dolní poloze."),
        WorkoutSwapCandidate(name: "Chest Press (stroj)",   slug: "machine-chest-press",  matchScore: 90,
                      equipment: "Stroj",       muscles: "Prsní, triceps",
                      coachTip: "Ideální pokud je volná lavička obsazená. Konstantní napětí svalů."),
        WorkoutSwapCandidate(name: "Cable Fly (kabelák)",   slug: "cable-fly",            matchScore: 82,
                      equipment: "Kabelák",     muscles: "Prsní (izolace)",
                      coachTip: "Mírně pokrčené lokty po celou dobu. Setkej ruce před hrudníkem."),
        WorkoutSwapCandidate(name: "Dips na tyčích",        slug: "dips",                 matchScore: 78,
                      equipment: "Bodyweight",  muscles: "Prsní, triceps",
                      coachTip: "Nakloň se dopředu pro větší zapojení prsního vs. tricepsu."),
        WorkoutSwapCandidate(name: "Push-up (kliky)",       slug: "push-up",              matchScore: 65,
                      equipment: "Bodyweight",  muscles: "Prsní, triceps, core",
                      coachTip: "Kliky na stupních zvýší rozsah a efektivitu."),
    ]

    static let back: [WorkoutSwapCandidate] = [
        WorkoutSwapCandidate(name: "Přítahy jednoručkou",  slug: "db-row",               matchScore: 93,
                      equipment: "Jednoručky", muscles: "Lat, zadní deltoid, biceps",
                      coachTip: "Loket blízko těla, v horní pozici rotuj pro max kontrakci latu."),
        WorkoutSwapCandidate(name: "Lat Pulldown (kabel)", slug: "lat-pulldown",          matchScore: 88,
                      equipment: "Kabelák",     muscles: "Latissimus, teres major",
                      coachTip: "Mírně lean dozadu, stahuj k hrudníku — ne za hlavu."),
        WorkoutSwapCandidate(name: "Seated Row (stroj)",   slug: "seated-cable-row",     matchScore: 85,
                      equipment: "Stroj",       muscles: "Střed zad, romboid",
                      coachTip: nil),
        WorkoutSwapCandidate(name: "TRX Row",              slug: "trx-row",               matchScore: 74,
                      equipment: "Bodyweight",  muscles: "Záda, biceps, core",
                      coachTip: "Čím nižší úhel těla k zemi, tím větší obtížnost."),
    ]

    static let legs: [WorkoutSwapCandidate] = [
        WorkoutSwapCandidate(name: "Leg Press",            slug: "leg-press",             matchScore: 91,
                      equipment: "Stroj",       muscles: "Kvadriceps, hýžďové, hamstringy",
                      coachTip: "Šíře nohou mění zapojení svalů — nohy nahoře = více hýždě."),
        WorkoutSwapCandidate(name: "Bulharský dřep",       slug: "bulgarian-split-squat", matchScore: 88,
                      equipment: "Jednoručky",  muscles: "Kvadriceps, hýžďové (unilat.)",
                      coachTip: "Opřená noha jen stabilizuje — veškerá práce vpředu."),
        WorkoutSwapCandidate(name: "Výpady s jednoručkami",slug: "dumbbell-lunge",        matchScore: 84,
                      equipment: "Jednoručky",  muscles: "Kvadriceps, hýžďové",
                      coachTip: "Přední koleno nepřesahuje špičku. Vzpřímený trup."),
        WorkoutSwapCandidate(name: "Goblet Squat",         slug: "goblet-squat",          matchScore: 78,
                      equipment: "Jednoručky",  muscles: "Kvadriceps, hýžďové, core",
                      coachTip: "Váha před hrudníkem vynucuje přirozeně vzpřímený trup."),
    ]

    static let shoulders: [WorkoutSwapCandidate] = [
        WorkoutSwapCandidate(name: "Arnold Press",         slug: "arnold-press",          matchScore: 89,
                      equipment: "Jednoručky",  muscles: "Přední + boční deltoid, triceps",
                      coachTip: "Rotace v pohybu zapojí více svalových vláken než standard press."),
        WorkoutSwapCandidate(name: "Shoulder Press (stroj)",slug: "machine-shoulder-press",matchScore: 85,
                      equipment: "Stroj",       muscles: "Deltoid, triceps",
                      coachTip: nil),
        WorkoutSwapCandidate(name: "Upright Row (kabel)",  slug: "cable-upright-row",    matchScore: 75,
                      equipment: "Kabelák",     muscles: "Boční deltoid, trapéz",
                      coachTip: "Lokty vedou pohyb výše než zápěstí po celou dobu tahu."),
    ]

    static let arms: [WorkoutSwapCandidate] = [
        WorkoutSwapCandidate(name: "Hammer Curl",          slug: "hammer-curl",           matchScore: 90,
                      equipment: "Jednoručky",  muscles: "Biceps, brachialis",
                      coachTip: "Neutrální grip zapojuje brachialis — klíč k šíři paže."),
        WorkoutSwapCandidate(name: "Cable Curl",           slug: "cable-curl",            matchScore: 86,
                      equipment: "Kabelák",     muscles: "Biceps (konst. napětí)",
                      coachTip: "I v horní poloze je stálý tah — výhoda oproti čince."),
        WorkoutSwapCandidate(name: "Tricep Pushdown",      slug: "cable-pushdown",        matchScore: 85,
                      equipment: "Kabelák",     muscles: "Triceps",
                      coachTip: nil),
    ]
}
