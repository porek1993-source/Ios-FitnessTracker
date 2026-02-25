// WorkoutView.swift
// Agilní Fitness Trenér — Aktivní trénink
// OPRAVENO: AI response, gamification, audio coach, Jakub chat, finish flow

import SwiftUI
import SwiftData

struct WorkoutView: View {
    @StateObject private var vm: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onFinish: (([XPGain], [PREvent]) -> Void)?

    @State private var showSummary = false
    @State private var summaryXPGains: [XPGain] = []
    @State private var summaryPREvents: [PREvent] = []
    @State private var summaryCoachMsg = ""
    @State private var showThorChat = false

    init(
        session: WorkoutSession,
        plan: PlannedWorkoutDay,
        planLabel: String,
        aiResponse: TrainerResponse? = nil,
        gamificationEngine: GamificationEngine? = nil,
        onFinish: (([XPGain], [PREvent]) -> Void)? = nil
    ) {
        _vm = StateObject(wrappedValue: WorkoutViewModel(
            session: session,
            plan: plan,
            planLabel: planLabel,
            aiResponse: aiResponse
        ))
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                WorkoutHeaderView(vm: vm)

                if vm.exercises.isEmpty {
                    emptyWorkoutPlaceholder
                } else {
                    TabView(selection: $vm.currentExerciseIndex) {
                        ForEach(vm.exercises.indices, id: \.self) { index in
                            ExerciseCardView(exercise: vm.exercises[index], vm: vm)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: vm.currentExerciseIndex)
                }

                // Bottom action bar
                bottomBar
            }

            if vm.isResting {
                RestTimerOverlay(vm: vm)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .sheet(isPresented: $showThorChat) {
            WorkoutChatView(vm: vm)
        }
        .fullScreenCover(isPresented: $showSummary) {
            WorkoutSummaryView(
                session: vm.session,
                coachMessage: summaryCoachMsg,
                xpGains: summaryXPGains,
                prEvents: summaryPREvents,
                hkResult: nil,
                onDismiss: {
                    showSummary = false
                    dismiss()
                }
            )
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Jakub chat
            Button { showThorChat = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 12))
                    Text("Jakub")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }

            Spacer()

            // Audio coach
            Button { vm.toggleAudio() } label: {
                Image(systemName: vm.audioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(vm.audioEnabled ? .blue : .white.opacity(0.35))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.09)))
            }

            // Finish workout
            Button { finishWorkout() } label: {
                Text("Dokončit")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(red: 0.25, green: 0.9, blue: 0.5)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(white: 0.06))
    }

    // MARK: - Empty State

    private var emptyWorkoutPlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "wand.and.sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Načítám cviky...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            Text("Jakub připravuje tvůj trénink")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Finish

    private func finishWorkout() {
        vm.finishWorkout(modelContext: modelContext)

        let gamEngine = GamificationEngine()
        gamEngine.loadRecords(from: modelContext)
        let input = buildGamificationInput()
        let gains = gamEngine.process(input: input, context: modelContext)
        try? modelContext.save()

        summaryXPGains = gains
        summaryPREvents = detectPRs()
        summaryCoachMsg = buildCoachMessage(gains: gains, prs: summaryPREvents)
        onFinish?(gains, summaryPREvents)

        withAnimation { showSummary = true }
    }

    private func buildGamificationInput() -> SessionGamificationInput {
        let exercises: [SessionGamificationInput.ExerciseResult] = vm.exercises.map { ex in
            let sets = ex.sets.filter { $0.isCompleted }.map {
                SessionGamificationInput.SetResult(
                    weightKg: $0.weightKg ?? 0,
                    reps: $0.reps ?? 0,
                    isWarmup: $0.isWarmup
                )
            }
            let sessionEx = vm.session.exercises.first { $0.exercise?.slug == ex.slug }
            return SessionGamificationInput.ExerciseResult(
                exerciseName: ex.name,
                musclesTarget: sessionEx?.exercise?.musclesTarget ?? [],
                musclesSecondary: sessionEx?.exercise?.musclesSecondary ?? [],
                completedSets: sets
            )
        }
        return SessionGamificationInput(exercises: exercises, personalRecords: [])
    }

    private func detectPRs() -> [PREvent] {
        var prs: [PREvent] = []
        for ex in vm.exercises {
            let sessionEx = vm.session.exercises.first { $0.exercise?.slug == ex.slug }
            guard let exercise = sessionEx?.exercise else { continue }
            let max = ex.sets.filter { $0.isCompleted && !$0.isWarmup }.compactMap { $0.weightKg }.max() ?? 0
            let prev = exercise.lastUsedWeight ?? 0
            if max > prev && prev > 0 {
                prs.append(PREvent(
                    exerciseName: ex.name,
                    muscleGroup: exercise.musclesTarget.first ?? .pecs,
                    oldValue: prev,
                    newValue: max,
                    type: .weight
                ))
            }
        }
        return prs
    }

    private func buildCoachMessage(gains: [XPGain], prs: [PREvent]) -> String {
        if !prs.isEmpty {
            return "Nový osobní rekord na \(prs.first!.exerciseName)! \(String(format: "%.1f", prs.first!.newValue)) kg — jsi silnější než kdy dřív. 💪"
        }
        let levelUps = gains.filter { $0.didLevelUp }
        if !levelUps.isEmpty {
            return "Level up! \(levelUps.first!.muscleGroup.displayName) → \(levelUps.first!.newLevel.displayName). Tvůj panáček roste! 🔥"
        }
        let vol = Int(gains.reduce(0) { $0 + $1.volumeKg })
        return "Hotovo! \(vol) kg objemu. Každý trénink tě posouvá blíž k cíli — jdeme dál!"
    }
}

// MARK: - Workout Chat View

struct WorkoutChatView: View {
    @ObservedObject var vm: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var userInput = ""
    @State private var messages: [(role: String, text: String)] = [
        (role: "assistant", text: "Ahoj! Tady jsem — cokoliv tě bolí, chybí vybavení, nebo chceš vyměnit cvik, jen napiš. 💬")
    ]
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(messages.indices, id: \.self) { i in
                                    ChatBubble(role: messages[i].role, text: messages[i].text)
                                        .id(i)
                                }
                                if isLoading { TypingIndicator().frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16) }
                            }
                            .padding(16)
                        }
                        .onChange(of: messages.count) { _, _ in
                            withAnimation { proxy.scrollTo(messages.count - 1) }
                        }
                    }

                    HStack(spacing: 10) {
                        TextField("Napiš Jakubovi...", text: $userInput)
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 22).fill(Color.white.opacity(0.08)))
                        Button { sendMessage() } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(userInput.isEmpty ? Color.white.opacity(0.3) : Color.blue)
                        }
                        .disabled(userInput.isEmpty || isLoading)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(red: 0.07, green: 0.07, blue: 0.10))
                }
            }
            .navigationTitle("Jakub — AI trenér")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Hotovo") { dismiss() }.foregroundStyle(.blue) } }
            .preferredColorScheme(.dark)
        }
    }

    private func sendMessage() {
        let text = userInput.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        userInput = ""
        messages.append((role: "user", text: text))
        isLoading = true
        Task {
            let responseText = await fetchGeminiResponse(userText: text)
            await MainActor.run {
                messages.append((role: "assistant", text: responseText))
                isLoading = false
            }
        }
    }

    private func fetchGeminiResponse(userText: String) async -> String {
        let client = GeminiAPIClient(apiKey: AppConstants.geminiAPIKey)
        let systemPrompt = """
        Jsi Jakub, elitní, lehce drsný, ale motivující silový trenér (Agilní Fitness Trenér). 
        Uživatel má právě trénink a napsal ti do chatu. 
        Odpověz stručně, poraď s technikou, navrhni alternativu nebo ho namotivuj (max 2 věty). Mluv česky.
        Vrať JSON objekt s klíčem "reply".
        """
        
        let currentExercise = vm.exercises.indices.contains(vm.currentExerciseIndex) ? vm.exercises[vm.currentExerciseIndex].name : "Neznámý cvik"
        let fullUserMessage = "Aktuálně cvičím: \(currentExercise). Moje zpráva zní: \(userText)"

        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "reply": ["type": "STRING"]
            ],
            "required": ["reply"]
        ]
        
        do {
            let responseString = try await client.generate(
                systemPrompt: systemPrompt,
                userMessage: fullUserMessage,
                responseSchema: schema
            )
            
            let cleaned = responseString
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```",     with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let data = cleaned.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let reply = json["reply"] as? String else {
                return "Zrovna to padá. Makej a nevymlouvej se!"
            }
            return reply
        } catch {
            return "Spojení vypadlo. Napiš mi později, teď cvič!"
        }
    }
}

private struct ChatBubble: View {
    let role: String
    let text: String
    var isUser: Bool { role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isUser {
                Circle().fill(Color.blue.opacity(0.7)).frame(width: 28, height: 28)
                    .overlay(Text("J").font(.system(size: 13, weight: .black)).foregroundStyle(.white))
            }
            if isUser { Spacer(minLength: 40) }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 16)
                    .fill(isUser ? Color.blue.opacity(0.55) : Color.white.opacity(0.09)))
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

private struct TypingIndicator: View {
    @State private var dot = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle().fill(Color.blue.opacity(dot == i ? 0.9 : 0.3))
                    .frame(width: 7, height: 7).scaleEffect(dot == i ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: dot)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.08)))
        .onReceive(timer) { _ in dot = (dot + 1) % 3 }
    }
}
