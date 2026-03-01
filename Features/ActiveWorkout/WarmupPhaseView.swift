import SwiftUI

struct WarmupPhaseView: View {
    let exercises: [SessionExerciseState]
    let aiExercises: [String]?
    let onFinishWarmup: () -> Void
    let onCancel: () -> Void
    
    @State private var generatedWarmups: [String] = []

    init(exercises: [SessionExerciseState], aiExercises: [String]? = nil, onFinishWarmup: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.exercises = exercises
        self.aiExercises = aiExercises
        self.onFinishWarmup = onFinishWarmup
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Hump
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding()
                            .background(Circle().fill(Color.white.opacity(0.05)))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 50)
                
                VStack(spacing: 24) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                        .shadow(color: .orange.opacity(0.5), radius: 10, y: 5)
                    
                    Text("Přípravná Fáze")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Zahřej správné svaly než začneš zvedat.")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        ForEach(generatedWarmups, id: \.self) { warmup in
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.orange)
                                    )
                                
                                Text(warmup)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            )
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onFinishWarmup()
                    }) {
                        Text("Odškrtnout rozcvičku a začít tvrdě")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            generateWarmups()
        }
    }
    
    private func generateWarmups() {
        if let ai = aiExercises, !ai.isEmpty {
            generatedWarmups = ai
            return
        }

        let firstEx = exercises.first?.exercise
        let muscles = firstEx?.musclesTarget ?? []
        let hasLegs = muscles.contains(.quads) || muscles.contains(.hamstrings) || muscles.contains(.glutes)
        let hasChest = muscles.contains(.chest) || muscles.contains(.frontShoulders)
        let hasBack = muscles.contains(.lats) || muscles.contains(.trapsMiddle)
        
        var list: [String] = []
        if hasLegs {
            list = [
                "15x Kroužení kyčlemi do každé strany",
                "10x Hluboký dřep bez zátěže (pauza dole 2s)",
                "20x Výstupy na bednu / Dynamické výpady"
            ]
        } else if hasChest {
            list = [
                "20x Kroužení rameny vpřed i vzad",
                "15x Dynamické otevírání hrudníku (rozpažování bez váhy)",
                "10x Pomalé kliky s důrazem na protažení"
            ]
        } else if hasBack {
            list = [
                "20x Kroužení rameny vpřed i vzad",
                "15x Předklony s rovnou osou / Kočičí hřbety",
                "10x Přítahy odporové gumy / prázdné osy"
            ]
        } else {
            list = [
                "2 minutový lehký poklus nebo veslování",
                "20x Dynamický strečink celého těla",
                "15x Kroužení všemi nosnými klouby"
            ]
        }
        generatedWarmups = list
    }
}
