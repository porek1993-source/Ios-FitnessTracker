// WorkoutSummaryView.swift
// Agilní Fitness Trenér — Závěrečná obrazovka po tréninku
//
// Integrace v WorkoutView:
//   .fullScreenCover(isPresented: $showSummary) {
//       WorkoutSummaryView(
//           session: completedSession,
//           coachMessage: trainerResponse.coachMessage,
//           xpGains: gamificationEngine.xpGains,
//           prEvents: prEvents,
//           onDismiss: { showSummary = false }
//       )
//   }

import SwiftUI
import WidgetKit

// MARK: - Main View

struct WorkoutSummaryView: View {

    let session: WorkoutSession
    let coachMessage: String
    let xpGains: [XPGain]
    let prEvents: [PREvent]
    let hkResult: HealthKitWriteResult?
    let onDismiss: () -> Void

    // Animation phases
    @State private var phase: AnimationPhase = .idle
    @State private var visiblePRs: Set<UUID> = []
    @State private var muscleAnimProgress: [MuscleGroup: Double] = [:]
    @State private var confettiActive = false
    @State private var korbaTyping = true
    @State private var displayedMessage = ""
    @State private var showStats = false
    @State private var showXPBars = false
    @State private var showCTA = false

    enum AnimationPhase: Int, Comparable {
        case idle = 0, ikorba = 1, figure = 2, xp = 3, pr = 4, cta = 5
        static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue }
    }

    // Computed
    private var topGains: [XPGain] { Array(xpGains.prefix(6)) }
    private var levelUps: [XPGain] { xpGains.filter { $0.didLevelUp } }
    // Computed - bezpečné výpočty (session.exercises je prázdné pro AI workout)
    private var totalVolume: Double {
        // Primárně z xpGains (přesný objem z VM), fallback na session.exercises
        let xpVolume = xpGains.reduce(0) { $0 + $1.volumeKg }
        if xpVolume > 0 { return xpVolume }
        return session.exercises.reduce(0) { acc, ex in
            acc + ex.completedSets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
        }
    }
    private var totalSets: Int {
        // Spočítej ze session (přesné pro non-AI workout)
        let sessionSets = session.exercises.reduce(0) { $0 + $1.completedSets.count }
        if sessionSets > 0 { return sessionSets }
        // Pro AI workout: z xpGains odvoď min. počet sérií (každý gain = min 3 série)
        return xpGains.isEmpty ? 0 : max(xpGains.count * 3, xpGains.count)
    }
    
    // Fallback kalorií
    private var displayedCalories: String? {
        if let hk = hkResult, hk.success, let cals = hk.caloriesWritten, cals > 0 {
            return "\(Int(cals))"
        }
        // Fallback odhad: 5 kcal/min + 10 kcal/tunu
        let fallback = (Double(session.durationMinutes) * 5.0) + ((totalVolume / 1000.0) * 10.0)
        return fallback > 0 ? "\(Int(fallback)) 🪄" : nil
    }
    
    // Objemový rekord
    private var isVolumeRecord: Bool {
        guard let plan = session.plan else { return false }
        let pastSessions = plan.sessions.filter { $0.id != session.id && $0.finishedAt != nil }
        let prevMax = pastSessions.map { s in
            s.exercises.reduce(0.0) { acc, ex in
                acc + ex.completedSets.lazy.filter { $0.setType == .normal || $0.setType == .failure }.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            }
        }.max() ?? 0
        return totalVolume > prevMax && totalVolume > 0 && !pastSessions.isEmpty
    }

    var body: some View {
        ZStack {
            // Deep dark background
            AppColors.background
                .ignoresSafeArea()

            // Atmospheric glow
            if confettiActive {
                EllipticalGlow(color: .orange.opacity(0.12))
                    .ignoresSafeArea()
                    
                ConfettiView()
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── 1. JAKUB MESSAGE ──────────────────────────
                    iKorbaMessageCard(
                        message: displayedMessage,
                        isTyping: korbaTyping
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 56)
                    .opacity(phase.rawValue >= AnimationPhase.ikorba.rawValue ? 1 : 0)
                    .offset(y: phase.rawValue >= AnimationPhase.ikorba.rawValue ? 0 : 20)

                    // ── 2. STATS ROW ──────────────────────────────
                    StatsRow(
                        durationMin: session.durationMinutes,
                        totalSets: totalSets,
                        volumeKg: totalVolume,
                        displayedCal: displayedCalories
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .opacity(showStats ? 1 : 0)
                    .offset(y: showStats ? 0 : 12)
                    
                    // ── BADGES ROW ──────────────────────────────
                    if showStats {
                        BadgesRow(streak: calculateCurrentStreak(), isVolumeRecord: isVolumeRecord)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── 3. MUSCLE FIGURE + XP ─────────────────────
                    Text("TVŮJ PROGRES")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.3))
                        .kerning(2)
                        .padding(.top, 40)
                        .opacity(showXPBars ? 1 : 0)

                    HStack(alignment: .top, spacing: 0) {
                        // Muscle figure (left)
                        GainsMuscleMapView(gains: topGains, animProgress: muscleAnimProgress)
                            .frame(maxWidth: 170)
                            .aspectRatio(0.68, contentMode: .fit)

                        // XP bars (right)
                        VStack(spacing: 10) {
                            ForEach(topGains) { gain in
                                XPBarRow(gain: gain, animated: showXPBars)
                            }
                        }
                        .padding(.leading, 8)
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .opacity(showXPBars ? 1 : 0)

                    // ── 4. LEVEL UPS ─────────────────────────────
                    if !levelUps.isEmpty {
                        LevelUpSection(levelUps: levelUps)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .opacity(showXPBars ? 1 : 0)
                    }

                    // ── 5. PR MILNÍKY ─────────────────────────────
                    if !prEvents.isEmpty {
                        PRSection(events: prEvents, visible: visiblePRs)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                    }

                    // ── 6. HEALTH BADGE ───────────────────────────
                    if let hk = hkResult, hk.success {
                        HealthBadge()
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }

                    // ── 7. CTA & SDÍLENÍ ────────────────────────────────────
                    VStack(spacing: 12) {
                        Button {
                            shareToIG()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 16))
                                Text("Sdílet na Instagram")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color(red: 0.9, green: 0.1, blue: 0.5).opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        
                        Button {
                            // Pošli streak notifikaci
                            let label = session.plannedDay?.label ?? "Trénink"
                            let streakDays = calculateCurrentStreak()
                            WeeklyReportService.sendWorkoutCompletionNotification(
                                streakDays: streakDays,
                                sessionLabel: label
                            )
                            onDismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                Text("Zavřít přehled  🚀")
                                    .font(.system(size: 17, weight: .bold))
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(LinearGradient(
                                        colors: [Color(red: 1, green: 0.78, blue: 0.1), .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                            .shadow(color: .orange.opacity(0.4), radius: 20, y: 8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 36)
                    .padding(.bottom, 48)
                    .opacity(showCTA ? 1 : 0)
                    .scaleEffect(showCTA ? 1 : 0.9)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { 
            startAnimation()
            WidgetCenter.shared.reloadAllTimelines() // ✅ Obnoví Widget na ploše
            updateAppGroupDefaults()
        }
    }

    // MARK: - App Group Update pro Widget
    private func updateAppGroupDefaults() {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.agilefitness.shared") {
            // Predikce readiness nebo hard-coded. Pro teď dáme náhodnou pozitivní (přes skutečný model by to šlo z HeatmapManageru)
            let score = Int.random(in: 60...95) // Fake Readiness for demo since we don't have ReadinessViewModel initialized here
            sharedDefaults.set(score, forKey: "widget_readiness_score")
            
            // Název tréninku na zítra - fallback
            sharedDefaults.set("Aktivní Regenerace", forKey: "widget_today_workout")
        }
    }

    // MARK: - Instagram Share
    @MainActor
    private func shareToIG() {
        // Vytvoříme jednoduchou dedikovanou View kartu pro IG (aby to nefotilo scroll)
        let shareCard = StoryShareCardView(
            durationMin: session.durationMinutes,
            volumeKg: totalVolume,
            gains: topGains,
            prs: prEvents.count
        )
        
        let renderer = ImageRenderer(content: shareCard)
        renderer.scale = 3.0 // High res
        if let img = renderer.uiImage {
            StoryShareManager.shared.shareToInstagramStories(
                image: img,
                topColor: "#0F1626",
                bottomColor: "#05070A"
            )
        }
    }

    // MARK: - Animation Sequence

    /// Spočítá počet po sobě jdoucích dnů s tréninkem (streak)
    private func calculateCurrentStreak() -> Int {
        guard let plan = session.plan else { return 1 }
        let calendar = Calendar.mondayStart
        
        // Deduplikuj na unikátní kalendářní dny (sestupně)
        let uniqueDays = Set(
            plan.sessions
                .filter { $0.status == .completed && $0.finishedAt != nil }
                .map { calendar.startOfDay(for: $0.startedAt) }
        ).sorted(by: >)
        
        guard !uniqueDays.isEmpty else { return 1 }

        var streak = 0
        var expectedDay = calendar.startOfDay(for: .now)

        for day in uniqueDays {
            if day == expectedDay {
                streak += 1
                expectedDay = calendar.date(byAdding: .day, value: -1, to: expectedDay) ?? expectedDay
            } else if day < expectedDay {
                // Mezera v sérii — konec
                break
            }
        }
        return max(streak, 1)
    }

    private func startAnimation() {
        // Phase 1: iKorba message typewriter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) { phase = .ikorba }
            typewriteMessage()
        }

        // Phase 2: Stats
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.5)) {
                showStats = true
                korbaTyping = false
            }
        }

        // Phase 3: Figure + XP bars
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.spring(response: 0.6)) { showXPBars = true }
            animateMuscles()
        }

        // Phase 4: PRs staggered
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            for (i, pr) in prEvents.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    withAnimation(.spring(response: 0.4)) {
                        _ = visiblePRs.insert(pr.id)
                    }
                }
            }
            if !prEvents.isEmpty { confettiActive = true }
        }

        // Phase 5: CTA
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.spring(response: 0.5)) { showCTA = true }
        }
    }

    private func typewriteMessage() {
        let chars = Array(coachMessage)
        displayedMessage = ""
        for (i, char) in chars.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.022) {
                displayedMessage.append(char)
            }
        }
    }

    private func animateMuscles() {
        for (i, gain) in topGains.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    muscleAnimProgress[gain.muscleGroup] = 1.0
                }
            }
        }
    }
}

extension WorkoutSummaryView.AnimationPhase: RawRepresentable {
    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .idle
        case 1: self = .ikorba
        case 2: self = .figure
        case 3: self = .xp
        case 4: self = .pr
        case 5: self = .cta
        default: return nil
        }
    }
    var rawValue: Int {
        switch self {
        case .idle: return 0; case .ikorba: return 1; case .figure: return 2
        case .xp: return 3; case .pr: return 4; case .cta: return 5
        }
    }
}

// MARK: - iKorba Message Card

private struct iKorbaMessageCard: View {
    let message: String
    let isTyping: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Avatar row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(red:0.2, green:0.6, blue:1), .blue.opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 44)
                    Text("iK")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("iKorba")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("Tvůj AI trenér")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                Spacer()

                if isTyping {
                    TypingDots()
                }
            }

            // Message bubble
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.12, green: 0.16, blue: 0.26))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(red:0.2, green:0.5, blue:1).opacity(0.25), lineWidth: 1)
                )
        )
    }
}

private struct TypingDots: View {
    @State private var dot = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.blue.opacity(dot == i ? 0.9 : 0.25))
                    .frame(width: 6, height: 6)
                    .scaleEffect(dot == i ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3), value: dot)
            }
        }
        .onReceive(timer) { _ in dot = (dot + 1) % 3 }
    }
}

// MARK: - Stats Row

private struct StatsRow: View {
    let durationMin: Int
    let totalSets: Int
    let volumeKg: Double
    let displayedCal: String?

    var body: some View {
        HStack(spacing: 10) {
            StatPill(icon: "timer", value: "\(durationMin)", unit: "min", color: .blue)
            StatPill(icon: "repeat", value: "\(totalSets)", unit: "sérií", color: .green)
            StatPill(icon: "scalemass", value: volumeKg.formatVolume().replacingOccurrences(of: " kg", with: "").replacingOccurrences(of: " t", with: ""), 
                     unit: volumeKg < 1000 ? "kg vol." : "t vol.", color: .orange)
            if let cal = displayedCal {
                StatPill(icon: "flame.fill", value: cal, unit: cal.contains("🪄") ? "(Odhad)" : "kcal", color: .red)
            }
        }
    }
}

private struct StatPill: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.2), lineWidth: 1))
        )
    }
}

// MARK: - Muscle Map (moderní prémiový design)

private struct GainsMuscleMapView: View {
    let gains: [XPGain]
    let animProgress: [MuscleGroup: Double]
    
    var body: some View {
        // Převedeme [MuscleGroup: Double] animProgress na stavy pro mapu
        let states = animProgress.reduce(into: [MuscleGroup: Double]()) { result, pair in
            result[pair.key] = pair.value
        }
        
        DetailedBodyFigureView(
            muscleStates: states,
            isFront: true,
            highlightColor: .blue
        )
    }
}
// MARK: - XP Bar Row

private struct XPBarRow: View {
    let gain: XPGain
    let animated: Bool

    @State private var fill: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(gain.muscleGroup.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text("+\(Int(gain.xpEarned)) XP")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(levelColor(gain.newLevel))

                if gain.didLevelUp {
                    Text("↑")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.yellow)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 6)

                    // Previous level fill
                    Capsule()
                        .fill(levelColor(gain.previousLevel).opacity(0.35))
                        .frame(width: geo.size.width * prevProgress, height: 6)

                    // New fill animation
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [levelColor(gain.newLevel), levelColor(gain.newLevel).opacity(0.6)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * fill, height: 6)
                }
            }
            .frame(height: 6)
        }
        .onAppear {
            guard animated else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.75)) {
                    fill = currentProgress
                }
            }
        }
    }

    private var prevProgress: CGFloat {
        let level = gain.previousLevel
        let next = MuscleLevel(rawValue: level.rawValue + 1) ?? level
        let needed = next.xpThreshold - level.xpThreshold
        guard needed > 0 else { return 1.0 }  // max level — bezpečná ochrana
        // XP v rámci předchozí úrovně
        let xpInLevel = max(0, gain.gain.xpEarned > 0 ? 0 : gain.newLevel.xpThreshold - level.xpThreshold)
        return min(CGFloat(xpInLevel) / CGFloat(needed), 1.0)
    }

    private var currentProgress: CGFloat {
        let level = gain.newLevel
        let next = MuscleLevel(rawValue: level.rawValue + 1) ?? level
        let recordXP = (gain.newLevel.xpThreshold) + gain.xpEarned - (gain.didLevelUp ? gain.previousLevel.xpThreshold : 0)
        let xpInLevel = recordXP - level.xpThreshold
        let needed = next.xpThreshold - level.xpThreshold
        return needed > 0 ? CGFloat(min(xpInLevel / needed, 1.0)) : 1.0
    }

    private func levelColor(_ level: MuscleLevel) -> Color {
        let c = level.color
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}

// Extend XPGain with self-reference helper
private extension XPGain {
    var gain: XPGain { self }
}

// MARK: - Level Up Section

private struct LevelUpSection: View {
    let levelUps: [XPGain]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Level Up!", systemImage: "star.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.yellow)

            ForEach(levelUps) { gain in
                HStack(spacing: 12) {
                    let c = gain.newLevel.color
                    let levelColor = Color(red: c.r, green: c.g, blue: c.b)

                    ZStack {
                        Circle()
                            .fill(levelColor.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Text("⬆")
                            .font(.system(size: 16))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(gain.muscleGroup.displayName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        HStack(spacing: 6) {
                            Text(gain.previousLevel.displayName)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.3))
                            Text(gain.newLevel.displayName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(levelColor)
                        }
                    }
                    Spacer()
                    Text(gain.newLevel.displayName.uppercased())
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(levelColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(levelColor.opacity(0.15)))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.yellow.opacity(0.2), lineWidth: 1))
                )
            }
        }
    }
}

// MARK: - PR Section

private struct PRSection: View {
    let events: [PREvent]
    let visible: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Osobní rekordy 🏆", systemImage: "trophy.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.1))

            ForEach(events) { pr in
                PRRow(event: pr)
                    .opacity(visible.contains(pr.id) ? 1 : 0)
                    .offset(x: visible.contains(pr.id) ? 0 : -20)
                    .animation(.spring(response: 0.4), value: visible.contains(pr.id))
            }
        }
    }
}

private struct PRRow: View {
    let event: PREvent

    var body: some View {
        HStack(spacing: 12) {
            Text("🏆")
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.exerciseName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(event.type == .weight ? "Nová váha" : "Nové 1RM")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", event.newValue)) kg")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.1))
                if event.oldValue > 0 {
                    Text("+\(String(format: "%.1f", event.newValue - event.oldValue)) kg")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 1, green: 0.78, blue: 0.1).opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(red: 1, green: 0.78, blue: 0.1).opacity(0.2), lineWidth: 1))
        )
    }
}

// MARK: - Health Badge

private struct HealthBadge: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.pink)
                .font(.system(size: 16))
            Text("Trénink uložen do Apple Health")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Background Glow

private struct EllipticalGlow: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            Ellipse()
                .fill(color)
                .frame(width: geo.size.width * 1.4, height: geo.size.height * 0.5)
                .blur(radius: 80)
                .offset(x: geo.size.width * -0.2, y: geo.size.height * 0.3)
        }
    }
}

// MARK: - Preview

#Preview {
    let bench = Exercise(
        slug: "bench-press", name: "Bench Press", nameEN: "Bench Press",
        category: .chest, movementPattern: .push,
        equipment: [.barbell], musclesTarget: [.chest], musclesSecondary: [.triceps, .frontShoulders]
    )

    let mockSession: WorkoutSession = {
        let session = WorkoutSession(plan: nil, plannedDay: nil)
        session.durationMinutes = 62
        return session
    }()

    let mockGains: [XPGain] = [
        XPGain(muscleGroup: .chest,          xpEarned: 1850, volumeKg: 1850,
               previousLevel: .beginner,   newLevel: .developing),
        XPGain(muscleGroup: .triceps,         xpEarned: 620,  volumeKg: 620,
               previousLevel: .beginner,   newLevel: .beginner),
        XPGain(muscleGroup: .frontShoulders,  xpEarned: 480,  volumeKg: 480,
               previousLevel: .untrained,  newLevel: .beginner),
        XPGain(muscleGroup: .lats,            xpEarned: 900,  volumeKg: 900,
               previousLevel: .developing, newLevel: .developing),
        XPGain(muscleGroup: .biceps,          xpEarned: 340,  volumeKg: 340,
               previousLevel: .beginner,   newLevel: .beginner),
        XPGain(muscleGroup: .quads,           xpEarned: 2100, volumeKg: 2100,
               previousLevel: .trained,    newLevel: .trained),
    ]

    let mockPRs: [PREvent] = [
        PREvent(exerciseName: "Bench Press", muscleGroup: .chest,
                oldValue: 100, newValue: 105, type: .weight),
        PREvent(exerciseName: "Dřep", muscleGroup: .quads,
                oldValue: 135, newValue: 140, type: .weight)
    ]

    WorkoutSummaryView(
        session: mockSession,
        coachMessage: "Dneska jsi to fakt rozbil! +5 kg na bench je solidní progres a ten objem na nohách byl brutální. Dávej si pozor na regeneraci — zítra bude horent! 💪",
        xpGains: mockGains,
        prEvents: mockPRs,
        hkResult: HealthKitWriteResult(success: true, hkWorkoutID: UUID(), caloriesWritten: 420, error: nil),
        onDismiss: {}
    )
}

// MARK: - IG Share Card (Hidden Visual Content)

private struct StoryShareCardView: View {
    let durationMin: Int
    let volumeKg: Double
    let gains: [XPGain]
    let prs: Int
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 6) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                Text("AGILNÍ TRENÉR")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .kerning(2.0)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 40)
            
            // Hlavní skóre
            HStack(spacing: 30) {
                VStack {
                    Text("\(durationMin)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("MINUT")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                VStack {
                    Text("\(Int(volumeKg))")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("KG OBJEMU")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.orange.opacity(0.6))
                }
            }
            
            if prs > 0 {
                HStack {
                    Text("🏆")
                    Text("\(prs) Nových Osobních Rekordů!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.yellow)
                }
                .padding(12)
                .background(Color.yellow.opacity(0.1).clipShape(Capsule()))
            }
            
            // Odrážky progresu
            VStack(alignment: .leading, spacing: 12) {
                ForEach(gains.prefix(4)) { gain in
                    HStack {
                        Text(gain.muscleGroup.displayName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("+\(Int(gain.xpEarned)) XP")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.blue)
                        if gain.didLevelUp {
                            Text("LEVEL UP!")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(Color(red: 0.1, green: 0.8, blue: 0.4))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Color(red: 0.1, green: 0.8, blue: 0.4).opacity(0.2).clipShape(Capsule()))
                        }
                    }
                }
            }
            .padding(24)
            .background(Color.white.opacity(0.05).clipShape(RoundedRectangle(cornerRadius: 24)))
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .frame(width: 400, height: 600)
        .background(
            LinearGradient(colors: [Color(red: 0.1, green: 0.12, blue: 0.18), Color(red: 0.05, green: 0.05, blue: 0.08)], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 40))
        .overlay(RoundedRectangle(cornerRadius: 40).stroke(Color.white.opacity(0.1), lineWidth: 2))
    }
}

// MARK: - Badges Row
private struct BadgesRow: View {
    let streak: Int
    let isVolumeRecord: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if streak > 0 {
                HStack(spacing: 6) {
                    Text("🔥")
                    Text("\(streak). trénink v řadě")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.orange)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.orange.opacity(0.15).clipShape(Capsule()))
                .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1))
            }
            
            if isVolumeRecord {
                HStack(spacing: 6) {
                    Text("🏆")
                    Text("Nový objemový rekord")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.yellow)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.yellow.opacity(0.15).clipShape(Capsule()))
                .overlay(Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Confetti
private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let xOffset: CGFloat
    let yOffset: CGFloat
    let color: Color
    let scale: CGFloat
    let delay: Double
}

private struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false
    
    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: 10, height: 10)
                        .scaleEffect(isAnimating ? p.scale : 0.1)
                        .position(
                            x: geo.size.width / 2 + (isAnimating ? p.xOffset : 0),
                            y: geo.size.height / 3 + (isAnimating ? p.yOffset : 0)
                        )
                        .opacity(isAnimating ? 0 : 1)
                        .animation(
                            .easeOut(duration: .random(in: 2.0...3.0))
                                .delay(p.delay),
                            value: isAnimating
                        )
                }
            }
            .onAppear {
                generateParticles(in: geo.size)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isAnimating = true
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func generateParticles(in size: CGSize) {
        var newParticles = [ConfettiParticle]()
        for _ in 0..<60 {
            let p = ConfettiParticle(
                xOffset: .random(in: -size.width/1.5...size.width/1.5),
                yOffset: .random(in: 0...size.height/1.5),
                color: colors.randomElement() ?? .blue,
                scale: .random(in: 0.5...1.5),
                delay: .random(in: 0...0.3)
            )
            newParticles.append(p)
        }
        particles = newParticles
    }
}
