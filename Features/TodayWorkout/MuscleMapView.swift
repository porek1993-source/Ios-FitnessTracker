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
                // ✅ NOVÁ PRÉMIOVÁ ANATOMICKÁ SILUETA (SVG)
                DetailedBodyFigureView(
                    muscleStates: vm.muscleGroupIntensity,
                    isFront: showingFront
                )
                .frame(height: 420)

                // Tap vrstva (původní tap oblasti, aby zůstala funkčnost)
                GeometryReader { geo in
                    let areas = showingFront ? MuscleArea.frontAreas : MuscleArea.backAreas
                    ZStack {
                        ForEach(areas) { area in
                            Rectangle()
                                .fill(Color.white.opacity(0.001))
                                .frame(width: area.relativeRect(in: geo.size).width * 1.5,
                                       height: area.relativeRect(in: geo.size).height * 1.2)
                                .position(x: area.relativeRect(in: geo.size).midX,
                                          y: area.relativeRect(in: geo.size).midY)
                                .onTapGesture {
                                    HapticManager.shared.playSelection()
                                    onTap(area)
                                }
                        }
                    }
                }
            }
        }
    }
}
