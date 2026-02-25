// AICoachChatView.swift
// Konverzační AI trenér — úpravy tréninku přirozeným jazykem

import SwiftUI
import SwiftData

struct AICoachChatMessage: Identifiable {
    let id = UUID()
    var text: String
    var isUser: Bool
    var isLoading: Bool = false
}

struct AICoachChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Environment(\.dismiss) private var dismiss

    let plannedDay: PlannedWorkoutDay?
    let onWorkoutAdjusted: ((String) -> Void)?

    @State private var messages: [AICoachChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @FocusState private var inputFocused: Bool

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    messagesScrollView
                    Divider().overlay(Color.white.opacity(0.1))
                    inputBar
                }
            }
            .navigationTitle("Trenér Jakub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavřít") { dismiss() }
                }
            }
            .onAppear { sendWelcome() }
        }
    }

    // MARK: — Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func messageBubble(_ message: AICoachChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !message.isUser {
                // Avatar
                ZStack {
                    Circle().fill(Color.blue.opacity(0.3)).frame(width: 32, height: 32)
                    Text("J").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                }
            }

            if message.isUser { Spacer(minLength: 60) }

            if message.isLoading {
                loadingDots
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(message.isUser ? Color.blue : Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 18,
                        style: .continuous))
                    .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
    }

    private var loadingDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(Color.white.opacity(0.5)).frame(width: 6, height: 6)
                    .scaleEffect(isLoading ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: isLoading)
            }
        }
    }

    // MARK: — Input

    private var inputBar: some View {
        HStack(spacing: 12) {
            // Quick suggestions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    suggestionChip("Tahá mě koleno")
                    suggestionChip("Mám jen 30 minut")
                    suggestionChip("Jsem hodně unavený")
                    suggestionChip("Lavička je obsazená")
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(height: 40)
        .padding(.top, 8)

        return HStack(spacing: 10) {
            TextField("Řekni trenérovi co potřebuješ…", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Button {
                sendMessage()
            } label: {
                Image(systemName: inputText.isEmpty ? "mic" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(inputText.isEmpty ? .white.opacity(0.3) : .blue)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
    }

    // MARK: — Logic

    private func sendWelcome() {
        let greeting = "Čau! Jsem Jakub, tvůj osobní trenér. 💪\n\nMůžeš mi říct, co tě trápí nebo co potřebuješ upravit v dnešním tréninku. Třeba: *\"Tahá mě pravé koleno\"* nebo *\"Mám jen 30 minut\"*."
        messages.append(AICoachChatMessage(text: greeting, isUser: false))
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(AICoachChatMessage(text: text, isUser: true))
        inputText = ""
        isLoading = true

        let loadingId = UUID()
        messages.append(AICoachChatMessage(text: "", isUser: false, isLoading: true))

        Task {
            let response = await callAICoach(userMessage: text)

            await MainActor.run {
                // Odeber loading bubble
                messages.removeAll { $0.isLoading }
                messages.append(AICoachChatMessage(text: response, isUser: false))
                isLoading = false

                // Pokud AI navrhla úpravu, notifikuj caller
                onWorkoutAdjusted?(response)
            }
        }
    }

    private func callAICoach(userMessage: String) async -> String {
        let apiClient = GeminiAPIClient(apiKey: AppConstants.geminiAPIKey)

        let dayContext = plannedDay.map { day in
            "Dnešní plánovaný trénink: \(day.label), cviky: \(day.plannedExercises.compactMap { $0.exercise?.name }.joined(separator: ", "))"
        } ?? "Žádný plán na dnešek."

        let profileContext = profile.map { p in
            "Uživatel: cíl \(p.primaryGoal.displayName), úroveň \(p.fitnessLevel.displayName)"
        } ?? ""

        let systemPrompt = """
        Jsi Jakub, přátelský osobní fitness trenér. Komunikuješ vždy v češtině, přirozeně a lidsky.
        Jsi empatický, motivující a praktický. Nikdy nezní roboticky.
        
        \(profileContext)
        \(dayContext)
        
        Tvým úkolem je pomoci uživateli upravit trénink na základě jeho problémů nebo potřeb.
        Pokud zmiňuje bolest, navrhni vynechání nebo náhradu cviku.
        Pokud má málo času, navrhni zkrácení nebo supersérie.
        Pokud je unavený, navrhni snížení intenzity.
        Vždy buď konkrétní — navrhuj přesné cviky a změny.
        Odpovídej stručně (2–4 věty), ale věcně.
        """

        do {
            let response = try await apiClient.generate(
                systemPrompt: systemPrompt,
                userMessage: userMessage,
                responseSchema: nil
            )
            return response
        } catch {
            return "Promiň, momentálně mám problém se připojit. Ale pamatuj: pokud tě něco bolí, raději daný cvik vynechej a přejdi na bezpečnější alternativu. 💪"
        }
    }
}
