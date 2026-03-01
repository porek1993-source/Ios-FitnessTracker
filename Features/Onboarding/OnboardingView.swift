// OnboardingView.swift
// Agilní Fitness Trenér — First Time User Experience

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var healthKit: HealthKitService

    @State private var currentStep = 0
    
    // Získávaná data
    @State private var weightKg: Double = 75.0
    @State private var heightCm: Double = 175.0
    @State private var selectedGoal: FitnessGoal = .hypertrophy
    @State private var selectedFitnessLevel: FitnessLevel = .beginner
    @State private var primarySport: String = ""
    @State private var daysPerWeek: Double = 4.0
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            TabView(selection: $currentStep) {
                // Krok 1: Uvítání
                welcomeStep.tag(0)
                
                // Krok 2: Biometrie
                biometricsStep.tag(1)
                
                // Krok 3: Cíl
                goalStep.tag(2)
                
                // Krok 4: Úroveň zdatnosti
                fitnessLevelStep.tag(3)
                
                // Krok 5: Sport & Frekvence
                lifestyleStep.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
            
            // Společný Footer
            VStack {
                Spacer()
                
                // Indikátor kroků
                HStack(spacing: 8) {
                    ForEach(0..<5) { i in
                        Circle()
                            .fill(i == currentStep ? AppColors.primaryAccent : AppColors.borderActive)
                            .frame(width: i == currentStep ? 10 : 8, height: i == currentStep ? 10 : 8)
                            .animation(.spring(), value: currentStep)
                    }
                }
                .padding(.bottom, 24)
                
                VStack(spacing: 16) {
                    Button(action: nextStep) {
                        Text(currentStep == 4 ? "Jdeme na to!" : "Pokračovat")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColors.primaryAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: AppColors.primaryAccent.opacity(0.3), radius: 10, y: 4)
                    }
                    
                    if currentStep == 0 {
                        Link(destination: URL(string: "https://agilefitness.example.com/privacy")!) {
                            Text("Zásady ochrany osobních údajů")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.textTertiary)
                                .underline()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    // MARK: - Kroky
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(AppColors.primaryAccent.opacity(0.15)).frame(width: 140, height: 140)
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColors.primaryAccent)
            }
            Text("Ahoj,\njsem iKorba.")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Tvůj osobní AI trenér. Pojďme tě společně dostat do životní formy. Zabere to jen minutku.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
    
    private var biometricsStep: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("Tvoje tělo")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            
            VStack(spacing: 24) {
                // Váha
                VStack(spacing: 12) {
                    HStack {
                        Text("Váha")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text("\(Int(weightKg)) kg")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppColors.primaryAccent)
                    }
                    Slider(value: $weightKg, in: 40...150, step: 1)
                        .tint(AppColors.primaryAccent)
                }
                
                // Výška
                VStack(spacing: 12) {
                    HStack {
                        Text("Výška")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text("\(Int(heightCm)) cm")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppColors.primaryAccent)
                    }
                    Slider(value: $heightCm, in: 140...220, step: 1)
                        .tint(AppColors.primaryAccent)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
    
    private var goalStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Tvé cíle")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation { selectedGoal = goal }
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: goal.icon)
                                    .font(.system(size: 24))
                                    .foregroundStyle(selectedGoal == goal ? .white : AppColors.textTertiary)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(goal.displayName)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(selectedGoal == goal ? .white : AppColors.textSecondary)
                                    Text(goal.description)
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppColors.textTertiary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                if selectedGoal == goal {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppColors.primaryAccent)
                                }
                            }
                            .padding(16)
                            .background(selectedGoal == goal ? AppColors.primaryAccent.opacity(0.15) : AppColors.secondaryBg)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selectedGoal == goal ? AppColors.primaryAccent : AppColors.border, lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            Spacer()
        }
    }
    
    private var fitnessLevelStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Tvoje zkušenosti")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: 12) {
                ForEach(FitnessLevel.allCases, id: \.self) { level in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation { selectedFitnessLevel = level }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: level.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(selectedFitnessLevel == level ? .white : AppColors.textTertiary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(level.displayName)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(selectedFitnessLevel == level ? .white : AppColors.textSecondary)
                                Text(level.description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColors.textTertiary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            if selectedFitnessLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppColors.primaryAccent)
                            }
                        }
                        .padding(16)
                        .background(selectedFitnessLevel == level ? AppColors.primaryAccent.opacity(0.15) : AppColors.secondaryBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selectedFitnessLevel == level ? AppColors.primaryAccent : AppColors.border, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private var lifestyleStep: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("Životní styl")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            
            VStack(spacing: 32) {
                // Frekvence
                VStack(spacing: 12) {
                    HStack {
                        Text("Tréninků týdně")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text("\(Int(daysPerWeek))×")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppColors.primaryAccent)
                    }
                    Slider(value: $daysPerWeek, in: 2...6, step: 1)
                        .tint(AppColors.primaryAccent)
                }
                
                // Sport
                VStack(alignment: .leading, spacing: 12) {
                    Text("Primární sport (volitelné)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                    
                    TextField("Např. fotbal, tenis, sedavé zaměstnání...", text: $primarySport)
                        .padding(16)
                        .background(AppColors.secondaryBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 1))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Akce
    
    private func nextStep() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if currentStep < 4 {
            withAnimation { currentStep += 1 }
        } else {
            finishOnboarding()
        }
    }
    
    private func finishOnboarding() {
        // Vytvoření nového profilu a uložení do SwiftData
        let newProfile = UserProfile(
            name: "Sportovec",
            heightCm: heightCm,
            weightKg: weightKg,
            primaryGoal: selectedGoal,
            fitnessLevel: selectedFitnessLevel,
            availableDaysPerWeek: Int(daysPerWeek)
        )
        newProfile.primarySport = primarySport.isEmpty ? nil : primarySport
        
        modelContext.insert(newProfile)
        
        // ✅ FIX: Generujeme tréninkový plán ihned po vytvoření profilu.
        // Bez tohoto volání by dashboard byl prázdný (žádný aktivní plán).
        WorkoutPlanGenerator.generate(for: newProfile, in: modelContext)
        
        do {
            try modelContext.save()
            
            // 🔥 Předběžná auth HealthKitu pro okamžitý start dashboardu
            Task {
                try? await healthKit.requestAuthorization()
                await HealthBackgroundManager.shared.performForegroundSync(healthKit: healthKit)
            }
            
            withAnimation(.spring(response: 0.6)) {
                hasSeenOnboarding = true
            }
        } catch {
            AppLogger.error("Chyba při ukládání profilu: \(error)")
        }
    }
}
