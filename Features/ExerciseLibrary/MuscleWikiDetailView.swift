// MuscleWikiDetailView.swift
// Agilní Fitness Trenér — Detail cviku z MuscleWiki s video přehrávačem

import SwiftUI
import AVKit

struct MuscleWikiDetailView: View {
    let exercise: MuscleWikiExercise

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // ── 1. VIDEO PŘEHRÁVAČ ──────────────────────────────────
                    videoSection

                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        // ── 2. NÁZEV + BADGE ────────────────────────────────
                        headerSection

                        // ── 3. INSTRUKCE ────────────────────────────────────
                        instructionsSection
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause() }
    }

    // MARK: - Video Section

    @ViewBuilder
    private var videoSection: some View {
        if let player {
            VideoPlayer(player: player)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 0))
                .overlay(alignment: .bottomLeading) {
                    // Gradient overlay pro lepší čitelnost
                    LinearGradient(
                        colors: [.clear, AppColors.background.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                }
        } else {
            // Placeholder pokud URL není validní
            ZStack {
                Rectangle()
                    .fill(AppColors.tertiaryBg)
                    .frame(height: 260)

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
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Název cviku
            Text(exercise.name)
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.textPrimary)

            // Badge svalové skupiny
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: exercise.muscleGroupIcon)
                    .font(.system(size: 14))
                Text(exercise.localizedMuscleGroup)
                    .font(AppTypography.callout)
            }
            .foregroundStyle(AppColors.primaryAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppColors.primaryAccent.opacity(0.12))
            )
        }
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Nadpis sekce
            Text("POSTUP PROVEDENÍ")
                .overlineStyle()

            if exercise.instructions.isEmpty {
                Text("Instrukce nejsou k dispozici.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textTertiary)
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, instruction in
                        instructionRow(number: index + 1, text: instruction)
                    }
                }
            }
        }
        .cardStyle()
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            // Číslo kroků
            Text("\(number)")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.primaryAccent)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(AppColors.primaryAccent.opacity(0.12))
                )

            // Text instrukce
            Text(text)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        guard let url = exercise.videoURL else { return }
        let avPlayer = AVPlayer(url: url)
        avPlayer.isMuted = false
        player = avPlayer
    }
}
