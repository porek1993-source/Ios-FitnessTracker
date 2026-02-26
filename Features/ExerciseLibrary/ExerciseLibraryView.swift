// ExerciseLibraryView.swift
// Agilní Fitness Trenér — Knihovna cviků z MuscleWiki (Supabase)

import SwiftUI

struct ExerciseLibraryView: View {
    @StateObject private var vm = MuscleWikiViewModel()

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            if vm.isLoading {
                loadingView
            } else if let error = vm.errorMessage {
                errorView(error)
            } else {
                contentView
            }
        }
        .navigationTitle("Knihovna cviků")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $vm.searchText, prompt: "Hledat cvik…")
        .preferredColorScheme(.dark)
        .task { await vm.loadAll() }
    }

    // MARK: - Content

    private var contentView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Chip bar pro filtr svalových skupin
                muscleGroupChips
                    .padding(.bottom, AppSpacing.md)

                // Seznam cviků
                if vm.filteredExercises.isEmpty {
                    emptyState
                } else {
                    exerciseList
                }
            }
            .padding(.bottom, 80)
        }
    }

    // MARK: - Muscle Group Chips

    private var muscleGroupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                // "Vše" chip
                chipButton(label: "Vše", isSelected: vm.selectedGroup == nil) {
                    vm.selectGroup(nil)
                }

                ForEach(vm.muscleGroups, id: \.self) { group in
                    let label = MuscleWikiExercise.localizedName(for: group)
                    chipButton(label: label, isSelected: vm.selectedGroup == group) {
                        vm.selectGroup(group)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
        }
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.playSelection()
            action()
        }) {
            Text(label)
                .font(AppTypography.callout)
                .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.primaryAccent : AppColors.cardBg)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        LazyVStack(spacing: AppSpacing.sm) {
            ForEach(vm.groupedExercises, id: \.group) { section in
                // Sekce s názvem svalové skupiny
                sectionHeader(section.group)

                ForEach(section.exercises) { exercise in
                    NavigationLink(destination: MuscleWikiDetailView(exercise: exercise)) {
                        exerciseRow(exercise)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private func sectionHeader(_ group: String) -> some View {
        HStack {
            Text(MuscleWikiExercise.localizedName(for: group).uppercased())
                .overlineStyle()
            Spacer()
        }
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.xxs)
    }

    private func exerciseRow(_ exercise: MuscleWikiExercise) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Ikona
            Image(systemName: exercise.muscleGroupIcon)
                .font(.system(size: 22))
                .foregroundStyle(AppColors.primaryAccent)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .fill(AppColors.primaryAccent.opacity(0.12))
                )

            // Název + svalová skupina
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text(exercise.localizedMuscleGroup)
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            // Šipka
            Image(systemName: "play.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill(AppColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.primaryAccent)
            Text("Načítám knihovnu cviků…")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.error)

            Text(message)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xxl)

            Button {
                Task { await vm.retry() }
            } label: {
                Label("Zkusit znovu", systemImage: "arrow.clockwise")
                    .font(AppTypography.callout)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(AppColors.primaryAccent)
                    )
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.textTertiary)

            Text("Žádné cviky nenalezeny")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textSecondary)

            Text("Zkus jiný filtr nebo vyhledávání.")
                .font(AppTypography.footnote)
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(.top, 60)
    }
}

// MARK: - MuscleWikiExercise Static Helpers

extension MuscleWikiExercise {
    /// Statický helper pro lokalizaci — použitelný i bez instance.
    static func localizedName(for group: String) -> String {
        muscleGroupNames[group.lowercased()] ?? group.capitalized
    }
}
