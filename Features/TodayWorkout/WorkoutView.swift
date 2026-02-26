// WorkoutView.swift
// Agilní Fitness Trenér — Aktivní trénink

import SwiftUI
import SwiftData

struct WorkoutView: View {
    @StateObject private var vm: WorkoutViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onFinish: (([XPGain], [PREvent]) -> Void)?
    let bodyWeightKg: Double  // Skutečná váha uživatele pro HealthKit záznam

    @State private var showSummary = false
    @State private var summaryXPGains: [XPGain] = []
    @State private var summaryPREvents: [PREvent] = []
    @State private var summaryCoachMsg = ""
    @State private var showJakubChat = false
    @State private var showFinishConfirm = false

    init(
        session: WorkoutSession,
        plan: PlannedWorkoutDay,
        planLabel: String,
        aiResponse: TrainerResponse? = nil,
        bodyWeightKg: Double = 75.0,
        onFinish: (([XPGain], [PREvent]) -> Void)? = nil
    ) {
        _vm = StateObject(wrappedValue: WorkoutViewModel(
            session: session,
            plan: plan,
            planLabel: planLabel,
            aiResponse: aiResponse
        ))
        self.bodyWeightKg = bodyWeightKg
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            // Background — sjednoceně s app theme
            Color(hue: 0.62, saturation: 0.18, brightness: 0.07).ignoresSafeArea()

            VStack(spacing: 0) {
                WorkoutHeaderView(vm: vm, onFinish: { finishWorkout() })

                if vm.exercises.isEmpty {
                    emptyWorkoutPlaceholder
                } else {
                    ZStack(alignment: .top) {
                        TabView(selection: $vm.currentExerciseIndex) {
                            ForEach(vm.exercises.indices, id: \.self) { index in
                                ExerciseCardView(
                                    exercise: vm.exercises[index],
                                    exerciseIndex: index,
                                    vm: vm
                                )
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.spring(response: 0.44, dampingFraction: 0.82), value: vm.currentExerciseIndex)

                        // Exercise counter pill
                        let workingExercises = vm.exercises.filter { !$0.isWarmupOnly }
                        let workingIdx = vm.exercises.prefix(vm.currentExerciseIndex + 1).filter { !$0.isWarmupOnly }.count
                        HStack(spacing: 6) {
                            Text(vm.exercises[min(vm.currentExerciseIndex, vm.exercises.count-1)].isWarmupOnly
                                 ? "ROZCVIČKA"
                                 : "\(workingIdx) / \(workingExercises.count)")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white.opacity(0.5))
                                .kerning(1.2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                        .padding(.top, 8)

                        // Všechny cviky hotové — banner
                        if vm.allExercisesDone {
                            allDoneBanner
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .zIndex(10)
                                .padding(.top, 8)
                                .padding(.horizontal, 20)
                        }
                    }
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
        .onChange(of: vm.allExercisesDone) { _, done in
            if done {
                // Všechny cviky hotové — zobraz completion banner s výzvou ukončit
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { showFinishConfirm = true }
                }
            }
        }
        .confirmationDialog("Trénink dokončen! 💪", isPresented: $showFinishConfirm, titleVisibility: .visible) {
            Button("Uložit a zobrazit výsledky") { finishWorkout() }
            Button("Pokračovat", role: .cancel) {}
        } message: {
            Text("Všechny cviky máš za sebou. Skvělý výkon!")
        }
        .sheet(isPresented: $showJakubChat) {
            WorkoutChatView(vm: vm)
        }
        .fullScreenCover(isPresented: $showSummary) {
            WorkoutSummaryView(
                session: vm.session,
                coachMessage: summaryCoachMsg,
                xpGains: summaryXPGains,
                prEvents: summaryPREvents,
                hkResult: vm.hkWriteResult,
                onDismiss: {
                    showSummary = false
                    dismiss()
                }
            )
        }
    }

    // MARK: - All Done Banner

    private var allDoneBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Všechny cviky hotové! 💪")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("Klepni Hotovo pro zobrazení výsledků")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Button { finishWorkout() } label: {
                Text("Hotovo")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(Color.green))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.1, green: 0.25, blue: 0.15))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.green.opacity(0.35), lineWidth: 1))
        )
        .shadow(color: .green.opacity(0.2), radius: 12, y: 4)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Jakub chat
            Button { showJakubChat = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 12))
                    Text("Jakub")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.white.opacity(0.09))
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)))
            }

            Spacer()

            // Remaining sets indicator
            if !vm.allExercisesDone, vm.exercises.indices.contains(vm.currentExerciseIndex) {
                let ex = vm.exercises[vm.currentExerciseIndex]
                let remaining = ex.sets.filter { !$0.isCompleted && !$0.isWarmup }.count
                if remaining > 0 {
                    Text("\(remaining) sérií")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            // Audio coach toggle
            Button { vm.toggleAudio() } label: {
                Image(systemName: vm.audioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(vm.audioEnabled ? .blue : .white.opacity(0.35))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.white.opacity(0.09)))
            }

            // Finish workout CTA
            Button { finishWorkout() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Ukončit")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(
                        vm.allExercisesDone
                        ? Color(red: 0.1, green: 0.72, blue: 0.4)
                        : Color.white.opacity(0.12)
                    )
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Color(hue: 0.62, saturation: 0.18, brightness: 0.07)
                .overlay(alignment: .top) { Divider().opacity(0.08) }
        )
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
        // Dokončení tréninku + zápis do DB (předáme skutečnou váhu uživatele)
        let (xpGains, prEvents) = vm.finishWorkout(
            modelContext: modelContext,
            bodyWeightKg: bodyWeightKg
        )

        // Sestavíme coach message pro summary
        summaryPREvents = prEvents
        summaryXPGains = xpGains
        summaryCoachMsg = buildCoachMessage(gains: summaryXPGains, prs: summaryPREvents)

        // Pošleme push notifikace za PR (mimo hlavní vlákno s malým delay)
        if !prEvents.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                for pr in prEvents {
                    NotificationService.shared.sendPersonalRecordNotification(
                        exerciseName: pr.exerciseName,
                        weight: pr.newValue
                    )
                }
            }
        }

        onFinish?(summaryXPGains, summaryPREvents)

        // Malý delay aby HK write stihlo dokončit a vrátit výsledek
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { showSummary = true }
        }
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
