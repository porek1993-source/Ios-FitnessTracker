// ExerciseSearchView.swift
// Fulltextové vyhledávání cviků z MuscleWiki pro ad-hoc trénink. Vše česky.

import SwiftUI

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ViewModel
// MARK: ═══════════════════════════════════════════════════════════════════════

@MainActor
final class ExerciseSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var allExercises: [MuscleWikiExercise] = []
    @Published var isLoading = false
    @Published var selectedExercises: [MuscleWikiExercise] = []

    var searchTask: Task<Void, Never>?

    // Místo počítání on-the-fly používáme uložené výsledky
    @Published var results: [MuscleWikiExercise] = []

    func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        let q = query.lowercased()
        results = allExercises.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.muscleGroup.localizedCaseInsensitiveContains(q)
        }
    }

    func loadIfNeeded() async {
        guard allExercises.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            allExercises = try await AppEnvironment.shared.exerciseRepository.fetchMuscleWikiAll()
        } catch {
            AppLogger.error("Chyba při načítání ExerciseSearchView: \(error.localizedDescription)")
            allExercises = []
        }
    }

    func toggleSelection(_ exercise: MuscleWikiExercise) {
        if let idx = selectedExercises.firstIndex(where: { $0.name == exercise.name }) {
            selectedExercises.remove(at: idx)
        } else {
            selectedExercises.append(exercise)
            HapticManager.shared.playMediumClick()
        }
    }

    func isSelected(_ exercise: MuscleWikiExercise) -> Bool {
        selectedExercises.contains(where: { $0.name == exercise.name })
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: View
// MARK: ═══════════════════════════════════════════════════════════════════════

struct ExerciseSearchView: View {
    let onStartWorkout: ([MuscleWikiExercise]) -> Void

    @StateObject private var vm = ExerciseSearchViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    content
                    if !vm.selectedExercises.isEmpty {
                        startButton
                    }
                }
            }
            .navigationTitle("Volný trénink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zavřít") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .preferredColorScheme(.dark)
            .task { await vm.loadIfNeeded() }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.35))
            TextField("Hledat cvik…", text: $vm.query)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .tint(.appPrimaryAccent)
            if !vm.query.isEmpty {
                Button { vm.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .onChange(of: vm.query) { _, newValue in
            vm.searchTask?.cancel()
            vm.searchTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                vm.performSearch()
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        Group {
            if vm.isLoading {
                VStack {
                    Spacer()
                    ProgressView().tint(.white.opacity(0.5))
                    Text("Načítám cviky…")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 8)
                    Spacer()
                }
            } else if vm.results.isEmpty && !vm.query.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 42))
                        .foregroundStyle(.white.opacity(0.12))
                    Text("Žádné výsledky")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("Zkus jiný název cviku")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.22))
                    Spacer()
                }
            } else if vm.query.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 42))
                        .foregroundStyle(.white.opacity(0.12))
                    Text("Vyhledej cviky a sestav si vlastní trénink")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 40)
            } else {
                // Počet výsledků Badge
                HStack {
                    Text("\(vm.results.count) výsledků")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.results) { exercise in
                            ExerciseSearchRow(
                                exercise: exercise,
                                isSelected: vm.isSelected(exercise)
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    vm.toggleSelection(exercise)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            HapticManager.shared.playHeavyClick()
            onStartWorkout(vm.selectedExercises)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16))
                Text("Spustit trénink (\(vm.selectedExercises.count) cviků)")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .white.opacity(0.15), radius: 12, y: 5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Search Row

private struct ExerciseSearchRow: View {
    let exercise: MuscleWikiExercise
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Ikona výběru
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected
                              ? Color.appPrimaryAccent.opacity(0.15)
                              : Color.white.opacity(0.05))
                        .frame(width: 44, height: 44)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.appPrimaryAccent : .white.opacity(0.3))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(exercise.localizedMuscleGroup)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))

                        if let equipment = exercise.equipment {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.25))
                            Text(equipment)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                    }
                }

                Spacer()

                Image(systemName: exercise.muscleGroupIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected
                          ? Color.appPrimaryAccent.opacity(0.06)
                          : Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected
                                ? Color.appPrimaryAccent.opacity(0.2)
                                : Color.white.opacity(0.05), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
