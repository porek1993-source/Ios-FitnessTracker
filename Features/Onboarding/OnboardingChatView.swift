// OnboardingChatView.swift
// Agilní Fitness Trenér — Konverzační onboarding s AI trenérem Thorem
//
// Nahraď stávající OnboardingView v StubViews.swift za tuto implementaci.
// Přidej OnboardingSystemPrompt.txt do Resources group v Xcode.

import SwiftUI
import SwiftData

// MARK: - Root Onboarding View

struct OnboardingChatView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var manager: OnboardingAIManager

    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var showTransition = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var inputFocused: Bool

    init() {
        _manager = StateObject(wrappedValue: OnboardingAIManager(apiKey: AppConstants.geminiAPIKey))
    }

    var body: some View {
        ZStack {
            // ── Background ────────────────────────────────────────────
            backgroundLayer

            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────────────
                headerBar

                // ── Messages ──────────────────────────────────────────
                messagesScrollView

                // ── Input Bar ─────────────────────────────────────────
                inputBar
            }

            // ── Profile-ready transition overlay ─────────────────────
            if showTransition {
                transitionOverlay
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(.dark)
        .task { await manager.startConversation() }
        .onChange(of: manager.profileReady) { _, ready in
            if ready { triggerTransition() }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.09)
                .ignoresSafeArea()

            // Subtle radial glow at top
            RadialGradient(
                colors: [
                    Color(red: 0.15, green: 0.30, blue: 0.70).opacity(0.25),
                    Color.clear
                ],
                center: .init(x: 0.5, y: -0.1),
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 14) {
            // Thor avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red:0.25, green:0.55, blue:1.0),
                                     Color(red:0.10, green:0.35, blue:0.85)],
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)

                Text("T")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                // Online indicator
                Circle()
                    .fill(Color(red:0.15, green:0.90, blue:0.50))
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color(red:0.06, green:0.06, blue:0.09), lineWidth: 2))
                    .offset(x: 14, y: 14)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Thor")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 5) {
                    if manager.isLoading {
                        TypingIndicatorDots()
                    } else {
                        Circle()
                            .fill(Color(red:0.15, green:0.90, blue:0.50))
                            .frame(width: 6, height: 6)
                        Text("Tvůj AI trenér")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }

            Spacer()

            // Step indicator
            ProgressStepsView(filledCount: collectedFieldsCount, total: 6)
                .opacity(manager.messages.count > 1 ? 1 : 0)
                .animation(.easeIn, value: manager.messages.count)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)   // safe area
        .padding(.bottom, 16)
        .background(
            // Frosted glass
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.6)
                .ignoresSafeArea()
        )
        .overlay(alignment: .bottom) {
            Divider().opacity(0.1)
        }
    }

    // MARK: - Messages Scroll View

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    // Spacer at top
                    Color.clear.frame(height: 12).id("top")

                    ForEach(manager.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.85, anchor: msg.role == .user ? .bottomTrailing : .bottomLeading)
                                    .combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    // Anchor for scroll-to-bottom
                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.horizontal, 16)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: manager.messages.count)
            }
            .onAppear { scrollProxy = proxy }
            .onChange(of: manager.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: manager.messages.last?.text) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.1)

            HStack(spacing: 12) {
                // Text field
                ZStack(alignment: .leading) {
                    if inputText.isEmpty {
                        Text("Napiš Thorovi…")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.25))
                            .padding(.horizontal, 16)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $inputText, axis: .vertical)
                        .lineLimit(1...5)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .focused($inputFocused)
                        .disabled(manager.inputDisabled)
                        .onSubmit { sendMessage() }
                }
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(
                                    inputFocused
                                        ? Color.blue.opacity(0.5)
                                        : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                )
                .animation(.easeOut(duration: 0.2), value: inputFocused)

                // Send button
                SendButton(
                    isEnabled: !inputText.trimmingCharacters(in: .whitespaces).isEmpty
                               && !manager.isLoading
                               && !manager.inputDisabled,
                    isLoading: manager.isLoading
                ) {
                    sendMessage()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 8)
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.8)
                .ignoresSafeArea()
        )
    }

    // MARK: - Transition Overlay

    private var transitionOverlay: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.09)
                .ignoresSafeArea()
                .opacity(showTransition ? 1 : 0)

            VStack(spacing: 24) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint:   .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .shadow(color: .blue.opacity(0.4), radius: 24, y: 8)

                    Image(systemName: "checkmark")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(showTransition ? 1 : 0.3)
                .animation(.spring(response: 0.6, dampingFraction: 0.65), value: showTransition)

                VStack(spacing: 8) {
                    Text("Profil vytvořen!")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Thor má vše co potřebuje.\nJdeme na to!")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .opacity(showTransition ? 1 : 0)
                .offset(y: showTransition ? 0 : 16)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: showTransition)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { await manager.send(message: text) }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func triggerTransition() {
        // Persist profile
        if let profile = manager.extractedProfile {
            modelContext.insert(profile)
        }

        // Show success animation, then pop to root (RootView re-renders)
        withAnimation(.easeInOut(duration: 0.4)) {
            showTransition = true
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Helpers

    /// Rough estimate of how many data fields Thor has collected
    private var collectedFieldsCount: Int {
        let texts = manager.messages.map(\.text).joined()
        var count = 0
        if texts.count > 50 { count += 1 }   // name
        if texts.localizedCaseInsensitiveContains("kg") { count += 1 }  // weight
        if texts.localizedCaseInsensitiveContains("cm") { count += 1 }  // height
        if texts.contains("let") || texts.contains("roků") { count += 1 }  // age
        if texts.localizedCaseInsensitiveContains("cíl")
            || texts.localizedCaseInsensitiveContains("síla")
            || texts.localizedCaseInsensitiveContains("hubn") { count += 1 }
        if texts.localizedCaseInsensitiveContains("dní")
            || texts.localizedCaseInsensitiveContains("dny")
            || texts.localizedCaseInsensitiveContains("krát") { count += 1 }
        return min(count, 6)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: - Sub-components
// MARK: ─────────────────────────────────────────────────────────────────────

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            if !isUser {
                // Thor avatar (small)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red:0.25, green:0.55, blue:1.0),
                                     Color(red:0.10, green:0.35, blue:0.85)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text("T")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    )
                    .padding(.bottom, 2)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if message.isStreaming && message.text.isEmpty {
                    // Typing dots bubble
                    TypingBubble()
                } else {
                    // Text bubble
                    Text(message.text)
                        .font(.system(size: 16))
                        .foregroundStyle(isUser ? .white : .white.opacity(0.92))
                        .lineSpacing(3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            BubbleShape(isUser: isUser)
                                .fill(bubbleColor)
                        )
                        .if(!isUser) { view in
                            view.overlay(
                                BubbleShape(isUser: false)
                                    .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                            )
                        }
                }

                // Timestamp
                Text(timeString)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.horizontal, 6)
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.vertical, 2)
    }

    private var bubbleColor: LinearGradient {
        if isUser {
            return LinearGradient(
                colors: [Color(red:0.20, green:0.50, blue:1.0),
                         Color(red:0.10, green:0.38, blue:0.88)],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(red:0.16, green:0.16, blue:0.22),
                         Color(red:0.13, green:0.13, blue:0.19)],
                startPoint: .top,
                endPoint:   .bottom
            )
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.timestamp)
    }
}

// MARK: - Bubble Shape (iMessage tail)

private struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6
        var path = Path()

        if isUser {
            // Right-side tail
            path.addRoundedRect(
                in: CGRect(x: rect.minX, y: rect.minY,
                           width: rect.width - tailSize, height: rect.height),
                cornerRadii: .init(
                    topLeading: radius, bottomLeading: radius,
                    bottomTrailing: 4, topTrailing: radius
                )
            )
            // Tail at bottom-right
            path.move(to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY - 12))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 4))
            path.addLine(to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY - 4))
        } else {
            // Left-side tail
            path.addRoundedRect(
                in: CGRect(x: tailSize, y: rect.minY,
                           width: rect.width - tailSize, height: rect.height),
                cornerRadii: .init(
                    topLeading: radius, bottomLeading: 4,
                    bottomTrailing: radius, topTrailing: radius
                )
            )
            // Tail at bottom-left
            path.move(to: CGPoint(x: tailSize, y: rect.maxY - 12))
            path.addLine(to: CGPoint(x: 0, y: rect.maxY - 4))
            path.addLine(to: CGPoint(x: tailSize, y: rect.maxY - 4))
        }

        return path
    }
}

// MARK: - Typing Bubble (animated dots)

private struct TypingBubble: View {
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                BouncingDot(delay: Double(i) * 0.18)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            BubbleShape(isUser: false)
                .fill(
                    LinearGradient(
                        colors: [Color(red:0.16, green:0.16, blue:0.22),
                                 Color(red:0.13, green:0.13, blue:0.19)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        )
    }
}

private struct BouncingDot: View {
    let delay: Double
    @State private var offset: CGFloat = 0

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.5))
            .frame(width: 7, height: 7)
            .offset(y: offset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    offset = -6
                }
            }
    }
}

// MARK: - Typing Indicator (for header)

struct TypingIndicatorDots: View {
    @State private var active = 0
    let timer = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.blue.opacity(active == i ? 0.9 : 0.3))
                    .frame(width: 5, height: 5)
                    .scaleEffect(active == i ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3), value: active)
            }
        }
        .onReceive(timer) { _ in active = (active + 1) % 3 }
    }
}

// MARK: - Send Button

private struct SendButton: View {
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        isEnabled
                            ? LinearGradient(
                                colors: [Color(red:0.25, green:0.55, blue:1.0),
                                         Color(red:0.10, green:0.38, blue:0.88)],
                                startPoint: .topLeading,
                                endPoint:   .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.06)],
                                startPoint: .top, endPoint: .bottom
                            )
                    )
                    .frame(width: 42, height: 42)
                    .shadow(color: isEnabled ? .blue.opacity(0.4) : .clear, radius: 10, y: 4)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.65)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isEnabled ? .white : .white.opacity(0.25))
                }
            }
            .scaleEffect(pressed ? 0.91 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(.spring(response: 0.25), value: isEnabled)
        ._onButtonGesture(pressing: { p in
            withAnimation(.spring(response: 0.15)) { pressed = p }
        }, perform: {})
    }
}

// MARK: - Progress Steps Indicator

private struct ProgressStepsView: View {
    let filledCount: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i < filledCount
                          ? Color(red:0.25, green:0.60, blue:1.0)
                          : Color.white.opacity(0.12))
                    .frame(width: i < filledCount ? 14 : 8, height: 5)
                    .animation(.spring(response: 0.4), value: filledCount)
            }
        }
    }
}

// MARK: - View extension helper

extension View {
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: - Integration: RootView update
// MARK: ─────────────────────────────────────────────────────────────────────

// Nahraď stávající RootView v AgileFitnessTrainerApp.swift:
//
// struct RootView: View {
//     @Query private var profiles: [UserProfile]
//
//     var body: some View {
//         if profiles.isEmpty {
//             OnboardingChatView()          // ← Místo OnboardingView()
//                 .transition(.opacity)
//         } else {
//             DashboardView()
//                 .transition(.opacity)
//         }
//     }
// }

// MARK: - Preview

#Preview {
    OnboardingChatView()
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
