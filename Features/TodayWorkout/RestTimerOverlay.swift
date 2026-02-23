// RestTimerOverlay.swift
import SwiftUI

struct RestTimerOverlay: View {
    @ObservedObject var vm: WorkoutViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea().onTapGesture { vm.skipRest() }
            VStack(spacing: 24) {
                Text("PAUZA")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .kerning(2)
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 8).frame(width: 160, height: 160)
                    Circle()
                        .trim(from: 0, to: vm.restProgress)
                        .stroke(
                            AngularGradient(colors: [.blue, .cyan], center: .center),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: vm.restProgress)
                    VStack(spacing: 4) {
                        Text(vm.restTimeFormatted)
                            .font(.system(size: 52, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText(countsDown: true))
                        Text("zbývá").font(.system(size: 13)).foregroundStyle(.white.opacity(0.4))
                    }
                }
                HStack(spacing: 16) {
                    TimerAdjustButton(label: "−15s") { vm.adjustRest(by: -15) }
                    Button { vm.skipRest() } label: {
                        Text("Přeskočit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 140, height: 48)
                            .background(Capsule().fill(Color.white))
                    }
                    TimerAdjustButton(label: "+15s") { vm.adjustRest(by: 15) }
                }
                Text("Klepni kamkoliv pro přeskočení")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
    }
}

struct TimerAdjustButton: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 48)
                .background(Capsule().fill(Color.white.opacity(0.12)))
        }
    }
}
