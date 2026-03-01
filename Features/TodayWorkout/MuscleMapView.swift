// MuscleMapView.swift
import SwiftUI

struct MuscleMapView: View {
    @ObservedObject var vm: HeatmapViewModel
    let onTap: (MuscleArea) -> Void
    @State private var showingFront = true

    var body: some View {
        VStack(spacing: 16) {
            Picker("Pohled", selection: $showingFront) {
                Text("Přední").tag(true)
                Text("Zadní").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 60)
            .animation(.easeInOut(duration: 0.2), value: showingFront)

            // ✅ Pevný aspect ratio — figurína vždy vycentrovaná a správně proporcionální
            DetailedBodyFigureView(
                muscleStates: vm.muscleGroupIntensity,
                isFront: showingFront,
                highlightColor: AppColors.primaryAccent,
                onTapMuscle: { tappedGroup in
                    let areas = showingFront ? MuscleArea.frontAreas : MuscleArea.backAreas
                    // Hledáme MuscleArea podle slug (přesná shoda nebo obsahová)
                    if let matched = areas.first(where: { $0.slug == tappedGroup.rawValue })
                        ?? areas.first(where: { tappedGroup.rawValue.contains($0.slug) || $0.slug.contains(tappedGroup.rawValue) }) {
                        HapticManager.shared.playSelection()
                        onTap(matched)
                    }
                }
            )
            .frame(maxWidth: 260)
            .aspectRatio(0.52, contentMode: .fit) // proporce těla: šířka:výška ≈ 1:1.9
            .frame(maxWidth: .infinity)            // vystředit horizontálně
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
            .animation(.easeInOut(duration: 0.25), value: showingFront)
            .id(showingFront) // force redraw při přepnutí
        }
    }
}
