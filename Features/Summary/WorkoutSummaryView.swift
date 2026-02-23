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

// MARK: - Main View

struct WorkoutSummaryView: View {

    let session: WorkoutSession
    let coachMessage: String
    let xpGains: [XPGain]
    let prEvents: [PREvent]
    let hkResult: WorkoutWriteResult?
    let onDismiss: () -> Void

    // Animation phases
    @State private var phase: AnimationPhase = .idle
    @State private var visiblePRs: Set<UUID> = []
    @State private var muscleAnimProgress: [MuscleGroup: Double] = [:]
    @State private var confettiActive = false
    @State private var jakubTyping = true
    @State private var displayedMessage = ""
    @State private var showStats = false
    @State private var showXPBars = false
    @State private var showCTA = false

    enum AnimationPhase { case idle, jakub, figure, xp, pr, cta }

    // Computed
    private var topGains: [XPGain] { Array(xpGains.prefix(6)) }
    private var levelUps: [XPGain] { xpGains.filter { $0.didLevelUp } }
    private var totalVolume: Double {
        session.exercises.reduce(0) { acc, ex in
            acc + ex.completedSets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
        }
    }
    private var totalSets: Int { session.exercises.reduce(0) { $0 + $1.completedSets.count } }

    var body: some View {
        ZStack {
            // Deep dark background
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()

            // Atmospheric glow
            if confettiActive {
                EllipticalGlow(color: .orange.opacity(0.12))
                    .ignoresSafeArea()
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── 1. JAKUB MESSAGE ──────────────────────────
                    JakubMessageCard(
                        message: displayedMessage,
                        isTyping: jakubTyping
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 56)
                    .opacity(phase.rawValue >= AnimationPhase.jakub.rawValue ? 1 : 0)
                    .offset(y: phase.rawValue >= AnimationPhase.jakub.rawValue ? 0 : 20)

                    // ── 2. STATS ROW ──────────────────────────────
                    StatsRow(
                        durationMin: session.durationMinutes,
                        totalSets: totalSets,
                        volumeKg: totalVolume,
                        caloriesKcal: hkResult?.caloriesWritten
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .opacity(showStats ? 1 : 0)
                    .offset(y: showStats ? 0 : 12)

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
                            .frame(width: 160, height: 260)

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

                    // ── 7. CTA ────────────────────────────────────
                    Button(action: onDismiss) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text("Hotovo, Jakube!")
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
                    .padding(.horizontal, 20)
                    .padding(.top, 36)
                    .padding(.bottom, 48)
                    .opacity(showCTA ? 1 : 0)
                    .scaleEffect(showCTA ? 1 : 0.9)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { startAnimation() }
    }

    // MARK: - Animation Sequence

    private func startAnimation() {
        // Phase 1: Jakub message typewriter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.5)) { phase = .jakub }
            typewriteMessage()
        }

        // Phase 2: Stats
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.5)) {
                showStats = true
                jakubTyping = false
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

extension WorkoutSummaryView.AnimationPhase: Comparable {
    static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue }
}

extension WorkoutSummaryView.AnimationPhase: RawRepresentable {
    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .idle
        case 1: self = .jakub
        case 2: self = .figure
        case 3: self = .xp
        case 4: self = .pr
        case 5: self = .cta
        default: return nil
        }
    }
    var rawValue: Int {
        switch self {
        case .idle: return 0; case .jakub: return 1; case .figure: return 2
        case .xp: return 3; case .pr: return 4; case .cta: return 5
        }
    }
}

// MARK: - Jakub Message Card

private struct JakubMessageCard: View {
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
                    Text("J")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Jakub")
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
    let caloriesKcal: Double?

    var body: some View {
        HStack(spacing: 10) {
            StatPill(icon: "timer", value: "\(durationMin)", unit: "min", color: .blue)
            StatPill(icon: "repeat", value: "\(totalSets)", unit: "sérií", color: .green)
            StatPill(icon: "scalemass", value: "\(Int(volumeKg))", unit: "kg vol.", color: .orange)
            if let kcal = caloriesKcal {
                StatPill(icon: "flame.fill", value: "\(Int(kcal))", unit: "kcal", color: .red)
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

// MARK: - Muscle Map (simplified SVG-style figure)

private struct GainsMuscleMapView: View {
    let gains: [XPGain]
    let animProgress: [MuscleGroup: Double]

    private func color(for muscle: MuscleGroup) -> Color {
        guard let gain = gains.first(where: { $0.muscleGroup == muscle }) else {
            return Color.white.opacity(0.08)
        }
        let progress = animProgress[muscle] ?? 0
        let level = gain.newLevel
        let c = level.color
        return Color(
            red:   c.r * progress,
            green: c.g * progress,
            blue:  c.b * progress
        ).opacity(0.3 + 0.7 * progress)
    }

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let cx = w / 2

            // ── HEAD ──
            let headR: CGFloat = w * 0.12
            let headCenter = CGPoint(x: cx, y: h * 0.07)
            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: headCenter.x - headR, y: headCenter.y - headR,
                    width: headR * 2, height: headR * 2.1
                )),
                with: .color(Color.white.opacity(0.2))
            )

            // ── NECK ──
            ctx.fill(
                Path(CGRect(x: cx - w*0.045, y: h*0.16, width: w*0.09, height: h*0.05)),
                with: .color(Color.white.opacity(0.15))
            )

            // ── CHEST (pecs) ──
            let chestColor = color(for: .pecs)
            let chestPath = Path { p in
                p.move(to: CGPoint(x: cx - w*0.28, y: h*0.21))
                p.addCurve(
                    to:        CGPoint(x: cx + w*0.28, y: h*0.21),
                    control1:  CGPoint(x: cx - w*0.10, y: h*0.18),
                    control2:  CGPoint(x: cx + w*0.10, y: h*0.18)
                )
                p.addLine(to: CGPoint(x: cx + w*0.26, y: h*0.34))
                p.addCurve(
                    to:        CGPoint(x: cx - w*0.26, y: h*0.34),
                    control1:  CGPoint(x: cx + w*0.06, y: h*0.36),
                    control2:  CGPoint(x: cx - w*0.06, y: h*0.36)
                )
                p.closeSubpath()
            }
            ctx.fill(chestPath, with: .color(chestColor))

            // ── SHOULDERS (delts) ──
            let deltColor = color(for: .delts)
            for side in [-1.0, 1.0] as [CGFloat] {
                let deltPath = Path(ellipseIn: CGRect(
                    x: cx + side*(w*0.22) - w*0.09,
                    y: h*0.19,
                    width: w*0.12, height: h*0.09
                ))
                ctx.fill(deltPath, with: .color(deltColor))
            }

            // ── LATS / BACK ──
            let latColor = color(for: .lats)
            let latPath = Path { p in
                p.move(to: CGPoint(x: cx - w*0.27, y: h*0.22))
                p.addCurve(
                    to:        CGPoint(x: cx - w*0.18, y: h*0.42),
                    control1:  CGPoint(x: cx - w*0.32, y: h*0.30),
                    control2:  CGPoint(x: cx - w*0.24, y: h*0.38)
                )
                p.addLine(to: CGPoint(x: cx, y: h*0.43))
                p.addLine(to: CGPoint(x: cx, y: h*0.22))
                p.closeSubpath()
            }
            ctx.fill(latPath, with: .color(latColor))
            let latPathR = Path { p in
                p.move(to: CGPoint(x: cx + w*0.27, y: h*0.22))
                p.addCurve(
                    to:        CGPoint(x: cx + w*0.18, y: h*0.42),
                    control1:  CGPoint(x: cx + w*0.32, y: h*0.30),
                    control2:  CGPoint(x: cx + w*0.24, y: h*0.38)
                )
                p.addLine(to: CGPoint(x: cx, y: h*0.43))
                p.addLine(to: CGPoint(x: cx, y: h*0.22))
                p.closeSubpath()
            }
            ctx.fill(latPathR, with: .color(latColor))

            // ── ARMS (biceps/triceps) ──
            let armMuscle: MuscleGroup = gains.contains(where: { $0.muscleGroup == .biceps }) ? .biceps : .triceps
            let armColor = color(for: armMuscle)
            for side in [-1.0, 1.0] as [CGFloat] {
                let armPath = Path(ellipseIn: CGRect(
                    x: cx + side*(w*0.27) - w*0.055,
                    y: h*0.28,
                    width: w*0.08, height: h*0.18
                ))
                ctx.fill(armPath, with: .color(armColor))

                // Forearms
                let forearmPath = Path(ellipseIn: CGRect(
                    x: cx + side*(w*0.28) - w*0.045,
                    y: h*0.46,
                    width: w*0.07, height: h*0.15
                ))
                ctx.fill(forearmPath, with: .color(color(for: .forearms)))
            }

            // ── ABS / CORE ──
            let absColor = color(for: .abs)
            for row in 0..<3 {
                for col in 0..<2 {
                    let rect = CGRect(
                        x: cx + CGFloat(col == 0 ? -1 : 0) * w*0.09 - w*0.04,
                        y: h*(0.36 + Double(row)*0.038),
                        width: w*0.075,
                        height: h*0.030
                    )
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: 3),
                        with: .color(absColor)
                    )
                }
            }

            // ── QUADS ──
            let quadColor = color(for: .quads)
            for side in [-1.0, 1.0] as [CGFloat] {
                let quadPath = Path(ellipseIn: CGRect(
                    x: cx + side*(w*0.05) - w*0.10,
                    y: h*0.55,
                    width: w*0.14, height: h*0.22
                ))
                ctx.fill(quadPath, with: .color(quadColor))
            }

            // ── HAMSTRINGS (behind quads, slightly offset) ──
            let hamColor = color(for: .hamstrings)
            for side in [-1.0, 1.0] as [CGFloat] {
                let hamPath = Path(ellipseIn: CGRect(
                    x: cx + side*(w*0.05) - w*0.085,
                    y: h*0.57,
                    width: w*0.11, height: h*0.18
                ))
                ctx.fill(hamPath, with: .color(hamColor.opacity(0.6)))
            }

            // ── CALVES ──
            let calfColor = color(for: .calves)
            for side in [-1.0, 1.0] as [CGFloat] {
                let calfPath = Path(ellipseIn: CGRect(
                    x: cx + side*(w*0.05) - w*0.08,
                    y: h*0.77,
                    width: w*0.11, height: h*0.16
                ))
                ctx.fill(calfPath, with: .color(calfColor))
            }

        }
        .animation(.spring(response: 0.6), value: animProgress.count)
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
        let xpInLevel = max(0, (gain.gain.newLevel == gain.previousLevel
            ? gain.newLevel.xpThreshold
            : level.xpThreshold) - level.xpThreshold
        )
        let needed = next.xpThreshold - level.xpThreshold
        return needed > 0 ? CGFloat(xpInLevel / needed) : 0
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
        equipment: [.barbell], musclesTarget: [.pecs], musclesSecondary: [.triceps, .delts]
    )

    let mockSession = WorkoutSession(plan: nil, plannedDay: nil)
    mockSession.durationMinutes = 62

    let mockGains: [XPGain] = [
        XPGain(muscleGroup: .pecs,     xpEarned: 1850, volumeKg: 1850,
               previousLevel: .beginner,   newLevel: .developing),
        XPGain(muscleGroup: .triceps,   xpEarned: 620,  volumeKg: 620,
               previousLevel: .beginner,   newLevel: .beginner),
        XPGain(muscleGroup: .delts,     xpEarned: 480,  volumeKg: 480,
               previousLevel: .untrained,  newLevel: .beginner),
        XPGain(muscleGroup: .lats,      xpEarned: 900,  volumeKg: 900,
               previousLevel: .developing, newLevel: .developing),
        XPGain(muscleGroup: .biceps,    xpEarned: 340,  volumeKg: 340,
               previousLevel: .beginner,   newLevel: .beginner),
        XPGain(muscleGroup: .quads,     xpEarned: 2100, volumeKg: 2100,
               previousLevel: .trained,    newLevel: .trained),
    ]

    let mockPRs: [PREvent] = [
        PREvent(exerciseName: "Bench Press", muscleGroup: .pecs,
                oldValue: 100, newValue: 105, type: .weight),
        PREvent(exerciseName: "Dřep", muscleGroup: .quads,
                oldValue: 135, newValue: 140, type: .weight)
    ]

    WorkoutSummaryView(
        session: mockSession,
        coachMessage: "Dneska jsi to fakt rozbil! +5 kg na bench je solidní progres a ten objem na nohách byl brutální. Dávej si pozor na regeneraci — zítra bude horent! 💪",
        xpGains: mockGains,
        prEvents: mockPRs,
        hkResult: WorkoutWriteResult(success: true, hkWorkoutID: UUID(), caloriesWritten: 420, error: nil),
        onDismiss: {}
    )
}
