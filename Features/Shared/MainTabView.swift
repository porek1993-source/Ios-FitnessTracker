// MainTabView.swift
// Agilní Fitness Trenér — Hlavní navigace aplikace

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    init() {
        // Vlastní styling pro TabBar (tmavý s průhledností)
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.95)
        
        // Barva pro nevybrané položky
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.3)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.3)]
        
        // Barva pro vybrané položky
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. Dashboard
            TrainerDashboardView()
                .tabItem {
                    Label("Doma", systemImage: "house.fill")
                }
                .tag(0)

            // 2. Zotavení a Zdraví (Nový Tab)
            RecoveryInsightsView()
                .tabItem {
                    Label("Zotavení", systemImage: "heart.text.square")
                }
                .tag(1)

            // 3. Knihovna cviků (MuscleWiki)
            NavigationStack {
                ExerciseLibraryView()
            }
            .tabItem {
                Label("Cviky", systemImage: "dumbbell.fill")
            }
            .tag(2)

            // 4. Týdenní Plán
            NavigationStack {
                ZStack {
                    Color(red: 0.055, green: 0.055, blue: 0.08).ignoresSafeArea()
                    ScrollView {
                        RollingWeekView()
                            .padding(.top, 20)
                    }
                }
                .navigationTitle("Můj Plán")
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem {
                Label("Plán", systemImage: "calendar")
            }
            .tag(3)

            // 5. Progres
            AppProgressView()
                .tabItem {
                    Label("Progres", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(4)

            // 6. Nastavení
            SettingsView()
                .tabItem {
                    Label("Nastavení", systemImage: "gearshape.fill")
                }
                .tag(5)
        }
        .accentColor(.blue)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainTabView()
        .environmentObject(HealthKitService())
}
