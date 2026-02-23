// StubViews.swift
// Zástupné obrazovky — nahraď vlastní implementací

import SwiftUI
import SwiftData

// MARK: - Onboarding

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var goal: FitnessGoal = .hypertrophy
    @State private var level: FitnessLevel = .intermediate
    @State private var days = 4
    @State private var split: SplitType = .ppl

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 8) {
                            Text("Vítej 👋")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Pár otázek a Jakub sestaví plán přesně pro tebe.")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Jak se jmenuješ?", systemImage: "person.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            TextField("Jméno", text: $name)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)

                        OnboardingPicker(title: "Hlavní cíl", icon: "target", selection: $goal,
                                         options: FitnessGoal.allCases, label: \.displayName)

                        OnboardingPicker(title: "Zkušenosti", icon: "chart.bar.fill", selection: $level,
                                         options: FitnessLevel.allCases, label: \.displayName)

                        OnboardingPicker(title: "Typ splitu", icon: "calendar", selection: $split,
                                         options: SplitType.allCases, label: \.displayName)

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Dní v týdnu: \(days)", systemImage: "flame.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                            Slider(value: Binding(
                                get: { Double(days) },
                                set: { days = Int($0) }
                            ), in: 2...6, step: 1)
                            .tint(.blue)
                        }
                        .padding(.horizontal, 20)

                        Button {
                            createProfile()
                        } label: {
                            Text("Začít s Jakubem")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(colors: [.blue, .cyan],
                                                         startPoint: .leading, endPoint: .trailing)))
                        }
                        .padding(.horizontal, 20)
                        .disabled(name.isEmpty)
                        .opacity(name.isEmpty ? 0.5 : 1)
                        .padding(.bottom, 40)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func createProfile() {
        let profile = UserProfile(
            name: name,
            primaryGoal: goal,
            fitnessLevel: level,
            availableDaysPerWeek: days,
            preferredSplitType: split
        )
        modelContext.insert(profile)
    }
}

struct OnboardingPicker<T: Hashable & CaseIterable>: View where T: CaseIterable {
    let title: String
    let icon: String
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Button {
                        selection = option
                    } label: {
                        Text(label(option))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selection == option ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selection == option ? Color.blue : Color.white.opacity(0.08))
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    if let profile = profiles.first {
                        Text("Ahoj, \(profile.name)!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)

                        NavigationLink(destination: HeatmapView()) {
                            DashboardCard(
                                icon: "figure.stand",
                                title: "Mapa kondice",
                                subtitle: "Označ únavu před tréninkem",
                                color: .blue
                            )
                        }

                        DashboardCard(
                            icon: "dumbbell.fill",
                            title: "Dnešní trénink",
                            subtitle: "Tap pro zahájení",
                            color: .green
                        )
                    } else {
                        Text("Žádný profil")
                            .foregroundStyle(.white)
                    }
                }
                .padding(20)
            }
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
        }
    }
}

struct DashboardCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.15)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 14)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.3))
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.06)))
    }
}
