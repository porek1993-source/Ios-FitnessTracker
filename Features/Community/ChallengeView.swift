// ChallengeView.swift
// Sociální Výzvy — žebříčky a soutěže s přáteli

import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - Main Community Hub

struct CommunityHubView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var coop = CoOpSessionService.shared
    @Query private var challenges: [Challenge]
    @State private var showCreateChallenge = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                if auth.isAuthenticated {
                    authenticatedContent
                } else {
                    signInPrompt
                }
            }
            .navigationTitle("Komunita")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if auth.isAuthenticated {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateChallenge = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(AppColors.primaryAccent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateChallenge) {
                CreateChallengeView()
            }
            .onAppear { coop.startListening() }
            .onDisappear { coop.stopListening() }
        }
    }

    // MARK: - Authenticated Content

    private var authenticatedContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                userHeader

                // ✅ Oblast E — Live Co-Op Strip
                if !coop.activeFriends.isEmpty {
                    liveNowStrip
                }

                // Active Challenges
                if !challenges.filter(\.isActive).isEmpty {
                    challengeSection(title: "Probíhající výzvy", icon: "flame.fill", color: .orange, items: challenges.filter(\.isActive))
                }

                // Upcoming / finished
                let finished = challenges.filter(\.isFinished)
                if !finished.isEmpty {
                    challengeSection(title: "Dokončené výzvy", icon: "checkmark.seal.fill", color: AppColors.success, items: finished)
                }

                if challenges.isEmpty {
                    emptyChallengesPlaceholder
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
    }

    // MARK: - Live Now Strip

    private var liveNowStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                    .overlay(Circle().fill(Color.green.opacity(0.4)).frame(width: 14, height: 14))
                Text("Právě cvičí")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("(\(coop.activeFriends.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textMuted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(coop.activeFriends) { friend in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.primaryAccent.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(AppColors.primaryAccent)
                            }
                            .overlay(alignment: .bottomTrailing) {
                                Circle().fill(Color.green).frame(width: 10, height: 10)
                                    .offset(x: 2, y: 2)
                            }
                            Text(friend.displayName.components(separatedBy: " ").first ?? friend.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppColors.textSecondary)
                            Text(friend.exerciseName)
                                .font(.system(size: 9))
                                .foregroundStyle(AppColors.textMuted)
                                .lineLimit(1)
                                .frame(maxWidth: 60)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.green.opacity(0.2), lineWidth: 1))
    }

    // MARK: - User Header

    private var userHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.primaryAccent.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.primaryAccent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(auth.currentUser?.email ?? "Uživatel")
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Člen komunity")
                    .font(.system(.caption))
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Button {
                Task { await auth.signOut() }
            } label: {
                Text("Odhlásit")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.07), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Challenge Section

    private func challengeSection(title: String, icon: String, color: Color, items: [Challenge]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
            }

            ForEach(items) { challenge in
                NavigationLink(value: challenge) {
                    ChallengeCard(challenge: challenge)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(for: Challenge.self) { challenge in
            ChallengeDetailView(challenge: challenge)
        }
    }

    // MARK: - Empty State

    private var emptyChallengesPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.circle")
                .font(.system(size: 52))
                .foregroundStyle(AppColors.primaryAccent.opacity(0.4))
            Text("Žádné výzvy")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
            Text("Vytvoř novou výzvu nebo pozvi přátele")
                .font(.callout)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
            Button {
                showCreateChallenge = true
            } label: {
                Label("Vytvořit výzvu", systemImage: "plus")
                    .font(.system(.body).weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(AppColors.primaryAccent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 40)
    }

    // MARK: - Sign In Prompt

    private var signInPrompt: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "person.2.badge.gearshape.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AppColors.primaryAccent)
                Text("Připoj se ke komunitě")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Přihlas se, sdílej pokroky s přáteli a zapoj se do výzev.")
                    .font(.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 14) {
                // Apple Sign In
                SignInWithAppleButton(.continue, onRequest: { request in
                    let req = AuthManager.shared.startAppleSignIn()
                    request.requestedScopes = req.requestedScopes
                    request.nonce = req.nonce
                }, onCompletion: { result in
                    Task { await AuthManager.shared.handleAppleSignInResult(result: result) }
                })
                .signInWithAppleButtonStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if let errorMsg = auth.errorMessage {
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundStyle(AppColors.error)
                }
            }
            .padding(.horizontal, 28)

            Spacer()
        }
    }
}

// MARK: - Challenge Card

struct ChallengeCard: View {
    let challenge: Challenge

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(typeGradient)
                    .frame(width: 52, height: 52)
                Image(systemName: typeIcon)
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(challenge.metric.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                    Text("·")
                        .foregroundStyle(AppColors.textMuted)
                    Text(durationText)
                        .font(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if challenge.isActive {
                    Text("ŽIVĚ")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.green, in: Capsule())
                } else if challenge.isFinished {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.success)
                }
                Text("\(challenge.participants.count) hráčů")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textMuted)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var durationText: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: challenge.startDate, to: challenge.endDate)
    }

    private var typeIcon: String {
        switch challenge.type {
        case .weekendSprint:  return "bolt.fill"
        case .monthlyMarathon: return "calendar"
        case .yearlyVolume:  return "chart.bar.fill"
        case .custom:        return "star.fill"
        }
    }

    private var typeGradient: LinearGradient {
        switch challenge.type {
        case .weekendSprint:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .monthlyMarathon:
            return LinearGradient(colors: [Color(hue: 0.6, saturation: 0.8, brightness: 0.9), .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .yearlyVolume:
            return LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .custom:
            return LinearGradient(colors: [AppColors.primaryAccent, AppColors.accentCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Challenge Detail / Leaderboard

struct ChallengeDetailView: View {
    let challenge: Challenge

    var sortedParticipants: [ChallengeParticipant] {
        challenge.participants.sorted { $0.currentScore > $1.currentScore }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    heroHeader
                    leaderboard
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
        }
        .navigationTitle(challenge.title)
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.type.rawValue)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(AppColors.primaryAccent)
                        .textCase(.uppercase)
                    Text(challenge.challengeDescription)
                        .font(.callout)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 16) {
                statPill(icon: "target", label: challenge.metric.rawValue)
                statPill(icon: "clock", label: daysRemainingText)
                statPill(icon: "person.2", label: "\(challenge.participants.count) hráčů")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statPill(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(AppColors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.07), in: Capsule())
    }

    private var daysRemainingText: String {
        if challenge.isFinished { return "Ukončeno" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: challenge.endDate).day ?? 0
        return "Zbývá \(days)d"
    }

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "list.number")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.warning)
                Text("Žebříček")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
            }

            if sortedParticipants.isEmpty {
                Text("Zatím žádní účastníci. Pozvi přátele!")
                    .font(.callout)
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(sortedParticipants.enumerated()), id: \.element.id) { rank, participant in
                    LeaderboardRow(rank: rank + 1, participant: participant, metric: challenge.metric)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let participant: ChallengeParticipant
    let metric: ChallengeMetric

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 34, height: 34)
                if rank <= 3 {
                    Text(rankEmoji).font(.system(size: 16))
                } else {
                    Text("\(rank)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(rankColor)
                }
            }

            // Avatar
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: "person.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Text(participant.displayName)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            Text(formattedScore)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(rankColor)
        }
        .padding(.vertical, 6)
    }

    private var rankEmoji: String {
        switch rank { case 1: return "🥇"; case 2: return "🥈"; case 3: return "🥉"; default: return "\(rank)" }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return AppColors.textSecondary
        }
    }

    private var formattedScore: String {
        switch metric {
        case .calories: return "\(Int(participant.currentScore)) kcal"
        case .volume:   return "\(Int(participant.currentScore)) kg"
        case .workouts: return "\(Int(participant.currentScore)) tréninků"
        case .xp:       return "\(Int(participant.currentScore)) XP"
        }
    }
}

// MARK: - Create Challenge Sheet

struct CreateChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var auth = AuthManager.shared

    @State private var title: String = ""
    @State private var desc: String = ""
    @State private var selectedType: ChallengeType = .weekendSprint
    @State private var selectedMetric: ChallengeMetric = .xp
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 7) // 7 dní default

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        formField(title: "Název výzvy", placeholder: "Např. Nohy v březnu") {
                            TextField("", text: $title)
                                .foregroundStyle(AppColors.textPrimary)
                        }

                        formField(title: "Popis", placeholder: "") {
                            TextField("Stručný popis pravidel...", text: $desc, axis: .vertical)
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(3, reservesSpace: true)
                        }

                        pickerField(title: "Typ výzvy") {
                            Picker("", selection: $selectedType) {
                                ForEach([ChallengeType.weekendSprint, .monthlyMarathon, .yearlyVolume, .custom], id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(AppColors.primaryAccent)
                        }

                        pickerField(title: "Skórování") {
                            Picker("", selection: $selectedMetric) {
                                ForEach([ChallengeMetric.xp, .calories, .volume, .workouts], id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(AppColors.primaryAccent)
                        }

                        formField(title: "Trvání") {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Začátek").font(.caption).foregroundStyle(AppColors.textMuted)
                                    DatePicker("", selection: $startDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                }
                                Spacer()
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Konec").font(.caption).foregroundStyle(AppColors.textMuted)
                                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                        .labelsHidden()
                                        .colorScheme(.dark)
                                }
                            }
                        }

                        // Duration presets
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Rychlé délky")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textMuted)
                            HStack(spacing: 10) {
                                durationPreset("V/E", days: 2)
                                durationPreset("Týden", days: 7)
                                durationPreset("Měsíc", days: 30)
                                durationPreset("Čtvrtrok", days: 91)
                                durationPreset("Rok", days: 365)
                            }
                        }

                        Button {
                            createChallenge()
                        } label: {
                            Text("Vytvořit výzvu")
                                .font(.body.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(LinearGradient(colors: [AppColors.primaryAccent, AppColors.secondaryAccent],
                                                             startPoint: .leading, endPoint: .trailing))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(title.isEmpty)
                        .opacity(title.isEmpty ? 0.5 : 1)

                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Nová výzva")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavřít") { dismiss() }.foregroundStyle(AppColors.textSecondary)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func durationPreset(_ label: String, days: Int) -> some View {
        let end = startDate.addingTimeInterval(Double(days) * 86400)
        let isSelected = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day == days
        return Button {
            endDate = end
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    isSelected ? AppColors.primaryAccent.opacity(0.25) : Color.white.opacity(0.07),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(isSelected ? AppColors.primaryAccent.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func formField<Content: View>(title: String, placeholder: String = "", @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(AppColors.textMuted)
            content()
                .padding(12)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private func pickerField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(AppColors.textMuted)
            HStack {
                content()
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func createChallenge() {
        let challenge = Challenge(
            title: title,
            description: desc,
            type: selectedType,
            metric: selectedMetric,
            startDate: startDate,
            endDate: endDate
        )

        // Automaticky přidat zakladatele jako prvního účastníka
        if let user = auth.currentUser {
            let participant = ChallengeParticipant(
                userId: user.id.uuidString,
                displayName: user.email ?? "Já",
                currentScore: 0
            )
            challenge.participants.append(participant)
        }

        modelContext.insert(challenge)
        try? modelContext.save()
        dismiss()
    }
}
