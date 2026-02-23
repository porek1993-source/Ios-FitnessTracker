// ExerciseDetailView.swift
// Detail cviku — vše striktně v češtině.

import SwiftUI

struct ExerciseDetailView: View {
    let slug: String

    @StateObject private var vm = ExerciseDetailViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    tagsSection
                    instructionsSection
                    youtubeButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 60)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task { await vm.load(slug: slug) }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.isLoadingExercise {
                // Skeleton
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 120, height: 14)
                    .shimmer()
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 32)
                    .shimmer()
            } else {
                if let category = vm.exercise?.category {
                    Text(category.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.3))
                        .kerning(1.5)
                }

                Text(vm.displayName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let error = vm.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.yellow.opacity(0.08))
                    )
                }
            }
        }
    }

    // MARK: - Tags (Svaly + Vybavení)

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.isLoadingExercise || vm.isEnriching {
                // Shimmer placeholdery pro tagy
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 80, height: 32)
                    }
                }
                .shimmer()
            } else {
                // Vybavení tag
                if let equip = vm.equipment {
                    TagChip(text: equip, icon: "dumbbell.fill", tint: .appPrimaryAccent)
                }

                // Svalové tagy
                if !vm.muscles.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(vm.muscles, id: \.self) { muscle in
                            TagChip(text: muscle, icon: "figure.strengthtraining.traditional", tint: .appGreenBadge)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
    }

    // MARK: - Instrukce

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSTRUKCE")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white.opacity(0.3))
                .kerning(1.5)

            if vm.isLoadingExercise || vm.isEnriching {
                // Skeleton pro instrukce
                VStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 16)
                            .frame(maxWidth: i == 3 ? 200 : .infinity)
                    }
                }
                .shimmer()
            } else if let text = vm.instructions {
                Text(text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(6)
                    .transition(.opacity)
            } else {
                Text("Pro tento cvik zatím nejsou k dispozici instrukce.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.35))
                    .italic()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appCardBackground)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1))
        )
    }

    // MARK: - YouTube Button

    @ViewBuilder
    private var youtubeButton: some View {
        if let url = vm.youtubeURL, !vm.isLoadingExercise {
            Button {
                HapticManager.shared.playMediumClick()
                openURL(url)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 20))
                    Text("Přehrát návod na YouTube")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.90, green: 0.12, blue: 0.12),
                                         Color(red: 0.75, green: 0.08, blue: 0.08)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .red.opacity(0.25), radius: 12, y: 6)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Pomocné komponenty
// MARK: ═══════════════════════════════════════════════════════════════════════

/// Štítek (tag chip) pro svaly a vybavení.
private struct TagChip: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay(Capsule().stroke(tint.opacity(0.20), lineWidth: 1))
        )
    }
}

/// Jednoduchý FlowLayout pro dynamické zalamování tagů.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
