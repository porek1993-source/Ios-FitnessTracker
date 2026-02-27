// MuscleWikiDetailView.swift
// Agilní Fitness Trenér — Detail cviku z MuscleWiki s prémiového UI

import SwiftUI
import AVKit
import AVFoundation

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Detail View
// MARK: ═══════════════════════════════════════════════════════════════════════

struct MuscleWikiDetailView: View {
    let exercise: MuscleWikiExercise

    @StateObject private var videoManager = LoopingVideoManager()
    @State private var showVideo = true

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ── 1. VIDEO PŘEHRÁVAČ ──────────────────────────────
                    videoSection

                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        // ── 2. NÁZEV + SVALOVÁ SKUPINA ──────────────────
                        headerSection

                        // ── 3. CHIPY (difficulty, type, grip) ───────────
                        if !exercise.chips.isEmpty {
                            chipsSection
                        }

                        // ── 4. INSTRUKCE ────────────────────────────────
                        instructionsSection
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear { videoManager.setup(url: exercise.videoURL) }
        .onDisappear { videoManager.pause() }
    }

    // MARK: - Video Section

    @ViewBuilder
    private var videoSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let player = videoManager.player {
                LoopingVideoPlayer(player: player)
                    .frame(height: 280)
                    .clipped()
            } else {
                // Placeholder pokud URL není validní
                ZStack {
                    Rectangle()
                        .fill(AppColors.tertiaryBg)
                        .frame(height: 280)

                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "play.slash.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(AppColors.textTertiary)

                        Text("Video není dostupné")
                            .font(AppTypography.footnote)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }

            // Gradient overlay pro plynulý přechod do pozadí
            LinearGradient(
                colors: [.clear, AppColors.background],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 100)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Název cviku
            Text(exercise.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Badges: svalová skupina + vybavení
            // FlexibleRow zajistí přetečení na nový řádek u dlouhých kombinací
            FlexibleRow(spacing: AppSpacing.xs) {
                // Badge svalové skupiny
                HStack(spacing: 6) {
                    Image(systemName: exercise.muscleGroupIcon)
                        .font(.system(size: 14, weight: .semibold))
                    Text(exercise.localizedMuscleGroup)
                        .font(AppTypography.callout)
                }
                .foregroundStyle(AppColors.primaryAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(AppColors.primaryAccent.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(AppColors.primaryAccent.opacity(0.2), lineWidth: 1)
                        )
                )

                // Badge vybavení — zobrazuje se jen pokud je k dispozici
                if let equipment = exercise.equipment {
                    HStack(spacing: 5) {
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(equipment)
                            .font(AppTypography.callout)
                    }
                    .foregroundStyle(Color.indigo)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.indigo.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    // MARK: - FlexibleRow helper (wrap badges na nový řádek)

    struct FlexibleRow: Layout {
        var spacing: CGFloat = 8

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let maxWidth = proposal.width ?? .infinity
            var currentX: CGFloat = 0
            var currentRowHeight: CGFloat = 0
            var totalHeight: CGFloat = 0
            var rowHeights: [CGFloat] = []

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth && currentX > 0 {
                    rowHeights.append(currentRowHeight)
                    totalHeight += currentRowHeight + spacing
                    currentX = 0
                    currentRowHeight = 0
                }
                currentX += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
            rowHeights.append(currentRowHeight)
            totalHeight += currentRowHeight

            return CGSize(width: maxWidth, height: totalHeight)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            var currentX = bounds.minX
            var currentY = bounds.minY
            var currentRowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                    currentY += currentRowHeight + spacing
                    currentX = bounds.minX
                    currentRowHeight = 0
                }
                subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
                currentX += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
    }

    // MARK: - Chips Section

    private var chipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(exercise.chips, id: \.self) { chip in
                    chipView(chip)
                }
            }
        }
    }

    private func chipView(_ chip: MuscleWikiExercise.ExerciseChip) -> some View {
        HStack(spacing: 6) {
            Image(systemName: chip.icon)
                .font(.system(size: 12, weight: .semibold))
            Text(chip.label)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(chip.color)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(chip.color.opacity(0.10))
                .overlay(
                    Capsule()
                        .stroke(chip.color.opacity(0.20), lineWidth: 1)
                )
        )
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Nadpis sekce
            Text("POSTUP PROVEDENÍ")
                .overlineStyle()

            if exercise.instructions.isEmpty {
                emptyInstructionsView
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, instruction in
                        instructionRow(number: index + 1, text: instruction, isLast: index == exercise.instructions.count - 1)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var emptyInstructionsView: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "text.badge.xmark")
                .font(.system(size: 20))
                .foregroundStyle(AppColors.textTertiary)
            Text("Instrukce nejsou k dispozici.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textTertiary)
                .italic()
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private func instructionRow(number: Int, text: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Číslo kroku v kroužku
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primaryAccent, AppColors.secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Text("\(number)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                // Text instrukce
                Text(text)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                // Oddělovací čára (kromě posledního kroku)
                if !isLast {
                    Rectangle()
                        .fill(AppColors.border)
                        .frame(height: 1)
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, AppSpacing.sm)
                }
            }
        }
        .padding(.vertical, AppSpacing.xxs)
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Looping Video Manager
// MARK: ═══════════════════════════════════════════════════════════════════════

/// ViewModel pro bezešvé smyčkování videa s ztlumením.
@MainActor
final class LoopingVideoManager: ObservableObject {
    @Published var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerItem: AVPlayerItem?

    func setup(url: URL?) {
        guard let url else { return }

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(items: [item])
        queuePlayer.isMuted = true

        // AVPlayerLooper zajistí bezešvé smyčkování
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        player = queuePlayer
        queuePlayer.play()
    }

    func pause() {
        player?.pause()
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Looping Video UIViewRepresentable
// MARK: ═══════════════════════════════════════════════════════════════════════

/// UIViewRepresentable wrapper pro AVQueuePlayer — lepší výkon než SwiftUI VideoPlayer.
struct LoopingVideoPlayer: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView(player: player)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private class PlayerUIView: UIView {
        private let playerLayer = AVPlayerLayer()

        init(player: AVQueuePlayer) {
            super.init(frame: .zero)
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(playerLayer)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}
