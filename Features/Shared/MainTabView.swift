// MainTabView.swift
// Agilní Fitness Trenér — Hlavní navigace aplikace

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    init() {
        // ✅ Liquid Glass (iOS 26) Styling pro TabBar
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground() // Translucent base
        
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        
        // Barva pro nevybrané položky
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.4)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.4)]
        
        // Barva pro vybrané položky
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemCyan // "Liquid" vibrantní barva
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemCyan]
        
        appearance.backgroundEffect = blurEffect
        
        UITabBar.appearance().standardAppearance = appearance
        // Při rolování k okraji plné glass UI
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
                Label("Cviky", systemImage: "scalemass.fill")
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
