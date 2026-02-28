import SwiftUI

/// Prémiová svalová mapa využívající SVG modely (DetailedBodyFigureView)
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

            ZStack {
                // ✅ NOVÁ PRÉMIOVÁ ANATOMICKÁ SILUETA (SVG) s přímým tapováním
                DetailedBodyFigureView(
                    muscleStates: vm.muscleGroupIntensity,
                    isFront: showingFront,
                    onTapMuscle: { tappedGroup in
                        // Cílem je najít odpovídající MuscleArea pro tento MuscleGroup
                        let areas = showingFront ? MuscleArea.frontAreas : MuscleArea.backAreas
                        // Mapujeme supabase klíč MuscleGroup zpět na MuscleArea.slug
                        if let matchedArea = areas.first(where: { $0.slug == tappedGroup.rawValue }) {
                            HapticManager.shared.playSelection()
                            onTap(matchedArea)
                        } else {
                            // Některé Svaly jako 'abs'/'abdominals' mohou mít trochu jiné slugy v UI a v DB
                            // Zkusíme fuzzy match
                            if let fallback = areas.first(where: { tappedGroup.rawValue.contains($0.slug) || $0.slug.contains(tappedGroup.rawValue) || $0.id == tappedGroup.rawValue }) {
                                HapticManager.shared.playSelection()
                                onTap(fallback)
                            }
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: 420)
            }
        }
    }
}
