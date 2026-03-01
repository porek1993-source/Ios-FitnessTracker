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
    @State private var showCancelDlg  = false
    @State private var showPlateCalculator = false
    @State private var isWarmupDone   = false

    init(session: WorkoutSession, plan: PlannedWorkoutDay, planLabel: String, bodyWeightKg: Double = 75.0) {
        _vm = StateObject(wrappedValue: WorkoutViewModel(
            session: session, plan: plan, planLabel: planLabel, bodyWeightKg: bodyWeightKg
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
                SessionHeaderBar(vm: vm, onFinish: { showFinishDlg = true }, onCancel: { showCancelDlg = true })
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
            
            // ── Fáze rozcvičky
            if !isWarmupDone {
                WarmupPhaseView(
                    exercises: vm.exercises,
                    onFinishWarmup: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isWarmupDone = true
                        }
                    },
                    onCancel: { showCancelDlg = true }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(30)
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
        .confirmationDialog("Opravdu chceš trénink ukončit předčasně?", isPresented: $showCancelDlg, titleVisibility: .visible) {
            Button("Ukončit a uložit") {
                vm.finishWorkout(modelContext: modelContext) // Uloží dosavadní progress
                dismiss()
            }
            Button("Zrušit trénink (zahodit data)", role: .destructive) {
                vm.cancelWorkout(modelContext: modelContext)
                dismiss()
            }
            Button("Zpět k cvičení", role: .cancel) {}
        } message: {
            Text("Trénink ještě není kompletní.")
        }
        .sheet(isPresented: $showPlateCalculator) {
            let idx = vm.currentExerciseIndex
            if vm.exercises.indices.contains(idx) {
                let currentEx = vm.exercises[idx]
                // Najdeme první nedokončenou sérii, abychom z ní vzali váhu, nebo poslední známou váhu
                let targetWeight = currentEx.sets.first(where: { !$0.isCompleted })?.weightKg ?? currentEx.sets.last?.weightKg ?? 20.0
                
                PlateCalculatorView(targetWeight: targetWeight, barbellWeight: 20.0)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(AppColors.secondaryBg)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowPlateCalculator"))) { _ in
            showPlateCalculator = true
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Session Header Bar
// MARK: ═══════════════════════════════════════════════════════════════════════

private struct SessionHeaderBar: View {
    @ObservedObject var vm: WorkoutViewModel
    let onFinish: () -> Void
    let onCancel: () -> Void

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
                    let ex = vm.exercises[i]
                    let isSupersetWithNext = i < vm.exercises.count - 1 && ex.supersetId != nil && ex.supersetId == vm.exercises[i + 1].supersetId
                    
                    HStack(spacing: 7) {
                        ExerciseDot(
                            state: i < vm.currentExerciseIndex ? .done
                                 : i == vm.currentExerciseIndex ? .active
                                 : .pending,
                            isSuperset: ex.supersetId != nil
                        )
                        
                        if isSupersetWithNext {
                            // Spojovací linka mezi cviky v supersérii (HStack)
                            Rectangle()
                                .fill(AppColors.primaryAccent.opacity(0.8))
                                .frame(width: 12, height: 2)
                                .padding(.horizontal, -4)
                        }
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                // Zrušit trénink
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.red.opacity(0.75))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.red.opacity(0.12))
                                .overlay(Circle().stroke(.red.opacity(0.20), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                // Hotovo / Ukončit
                let isWorkoutComplete = vm.exercises.allSatisfy { ex in ex.sets.allSatisfy { $0.isCompleted } } || vm.allExercisesDone
                
                Button(action: {
                    if isWorkoutComplete {
                        onFinish()
                    } else {
                        onCancel() // Uses the alert for Early Exit
                    }
                }) {
                    Text(isWorkoutComplete ? "Dokončit" : "Ukončit")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isWorkoutComplete ? Color.green : .white.opacity(0.72))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isWorkoutComplete ? Color.green.opacity(0.15) : .white.opacity(0.09))
                                .overlay(Capsule().stroke(isWorkoutComplete ? Color.green.opacity(0.3) : .white.opacity(0.11), lineWidth: 1))
                        )
                }
            }
            .frame(width: 120, alignment: .trailing)
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
    let isSuperset: Bool // True, pokud je cvik součástí supersérie

    var body: some View {
        ZStack {
            Circle()
                .fill(dotFill)
                .frame(width: dotSize, height: dotSize)
            
            if isSuperset {
                Circle()
                    .stroke(AppColors.primaryAccent, lineWidth: 1.5)
                    .frame(width: dotSize + 4, height: dotSize + 4)
            }
            
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

                    ExerciseNoteView(slug: exercise.slug)

                    SetLoggerBlock(exercise: $exercise, onComplete: onComplete)
                    
                    if exercise.exercise?.equipment.contains(.barbell) == true {
                        Button {
                            // Nastavíme showPlateCalculator (musíme to propagovat přes binding,
                            // nebo použít notifikaci/callback, protože jsme v oddělené view hierarchii.
                            // Protože `showPlateCalculator` je v root View, přidáme callback sem:)
                            NotificationCenter.default.post(name: NSNotification.Name("ShowPlateCalculator"), object: nil)
                        } label: {
                            HStack {
                                Image(systemName: "plus.forwardslash.minus")
                                Text("Kalkulačka kotoučů")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.blue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }

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
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // Ambient glow
            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 140, height: 140)
                .blur(radius: 32)
                .scaleEffect(glowPulse ? 1.25 : 0.85)
                .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: glowPulse)
                .offset(y: -30)

            // ✅ Sjednocené video/GIF view z ExerciseMediaView
            ExerciseMediaView(
                gifURL: exercise.videoUrl.flatMap { URL(string: $0) },
                exerciseName: exercise.name,
                exerciseNameEn: exercise.nameEN.isEmpty ? exercise.exercise?.nameEN : exercise.nameEN
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

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
                            
                        if exercise.supersetId != nil {
                            Text("SUPERSÉRIE")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.primaryAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.primaryAccent.opacity(0.15))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppColors.primaryAccent.opacity(0.3), lineWidth: 1))
                                .padding(.top, 2)
                        }
                    }

                    Spacer(minLength: 12)

                    // Smart Swap button
                    Button(action: onSwap) {
                        VStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Vyměnit cvik")
                                .font(.system(size: 10, weight: .bold))
                                .kerning(0.3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1))
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
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .onAppear { glowPulse = true }
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
                             isGraphicTempo: true,
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
    let icon: String; let label: String; let value: String
    var isGraphicTempo: Bool = false
    let color: Color
    @ObservedObject var vm: WorkoutViewModel
    
    // Vizualizace tempa např "3111" -> "⬇️ 3s ⏸️ 1s ⬆️ 1s ⏸️ 1s"
    private var formattedValue: String {
        guard isGraphicTempo, value.count == 4 else { return value }
        let chars = Array(value)
        return "⬇️ \(chars[0])s  ⏸️ \(chars[1])s  ⬆️ \(chars[2])s  ⏸️ \(chars[3])s"
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 7.5, weight: .black))
                    .foregroundStyle(.white.opacity(0.30))
                    .kerning(0.5)
                Text(formattedValue)
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
                        WorkoutSetRowView(
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
                        WorkoutSetRowView(
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

// Removed ActiveSetRow, SetBadge, InlineField, RPECell, CompleteButton and RPEPickerView as they were extracted to WorkoutSetRowView.swift

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
            SummaryPill(icon: "scalemass.fill",   value: volume.formatVolume(), label: "objem",  tint: .blue)
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
        VStack(spacing: 24) {
            CircularRestTimerView(
                progress: vm.restProgress,
                timeFormatted: vm.restTimeFormatted,
                secondsRemaining: vm.restSecondsRemaining,
                onAdjust: { delta in vm.adjustRest(by: delta) },
                onSkip: { vm.skipRest() }
            )
            
            // Živý tepový odpočinek (Apple Watch integrace)
            HRZonedRestTimer(targetBPM: 110.0, onTargetReached: {
                // Může notifikovat nebo přeskočit pauzu, ale počkáme na uživatele
            })
            .padding(.horizontal, 24)
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
