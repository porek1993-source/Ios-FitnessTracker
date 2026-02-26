// SettingsView.swift
// Agilní Fitness Trenér — Nastavení profilu a preferencí

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @EnvironmentObject private var healthKitService: HealthKitService

    @State private var showDeleteConfirm = false
    @State private var showSaved = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                if let profile {
                    ProfileSettingsForm(profile: profile, onSave: {
                        do {
                            try modelContext.save()
                        } catch {
                            AppLogger.error("SettingsView: Chyba při ukládání profilu: \(error)")
                        }
                        withAnimation { showSaved = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showSaved = false }
                        }
                    })
                } else {
                    Text("Profil nenalezen.").foregroundStyle(.white.opacity(0.5))
                }
            }
            .navigationTitle("Nastavení")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .overlay(alignment: .top) {
                if showSaved {
                    savedBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
        }
    }

    private var savedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text("Uloženo!").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color.green.opacity(0.2))
        .clipShape(Capsule())
    }
}

// MARK: - ProfileSettingsForm

struct ProfileSettingsForm: View {
    @Bindable var profile: UserProfile
    let onSave: () -> Void

    @State private var draftName: String = ""
    @State private var draftGoal: FitnessGoal = .hypertrophy
    @State private var draftLevel: FitnessLevel = .intermediate
    @State private var draftDays: Int = 4
    @State private var draftSplit: SplitType = .upperLower
    @State private var draftDuration: Int = 60
    @State private var draftSport: String = ""
    @State private var draftEquipment: Set<Equipment> = [.barbell, .dumbbell, .cable, .machine]
    @EnvironmentObject private var healthKitService: HealthKitService
    @State private var healthKitRequesting = false
    @State private var healthKitMessage: String? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // MARK: — Jméno
                settingsSection(title: "Profil", icon: "person.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Jméno").font(.caption).foregroundStyle(.white.opacity(0.5))
                        TextField("Tvoje jméno", text: $draftName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // MARK: — Cíl
                settingsSection(title: "Fitness cíl", icon: "target") {
                    VStack(spacing: 8) {
                        ForEach(FitnessGoal.allCases, id: \.rawValue) { goal in
                            goalRow(goal)
                        }
                    }
                }

                // MARK: — Úroveň
                settingsSection(title: "Zkušenosti", icon: "chart.bar.fill") {
                    HStack(spacing: 8) {
                        ForEach(FitnessLevel.allCases, id: \.rawValue) { level in
                            levelButton(level)
                        }
                    }
                }

                // MARK: — Plánování
                settingsSection(title: "Tréninkový plán", icon: "calendar") {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Dnů v týdnu").font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text("\(draftDays)×").font(.system(size: 16, weight: .bold)).foregroundStyle(.blue)
                            }
                            Slider(value: Binding(get: { Double(draftDays) }, set: { draftDays = Int($0) }),
                                   in: 2...6, step: 1)
                            .tint(.blue)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Délka tréninku").font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text("\(draftDuration) min").font(.system(size: 16, weight: .bold)).foregroundStyle(.blue)
                            }
                            Slider(value: Binding(get: { Double(draftDuration) }, set: { draftDuration = Int($0) }),
                                   in: 30...120, step: 15)
                            .tint(.blue)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tréninkový split").font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                            HStack(spacing: 8) {
                                ForEach(SplitType.allCases, id: \.rawValue) { split in
                                    splitButton(split)
                                }
                            }
                        }
                    }
                }

                // MARK: — Primární sport
                settingsSection(title: "Primární sport", icon: "sportscourt.fill") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pokud máš primární sport, aplikace přizpůsobí silový trénink jako doplněk.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        TextField("Např. fotbal, tenis, plavání…", text: $draftSport)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // MARK: — Vybavení
                settingsSection(title: "Dostupné vybavení", icon: "dumbbell.fill") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach(Equipment.allCases, id: \.rawValue) { equip in
                            equipmentToggle(equip)
                        }
                    }
                }

                // MARK: — Notifikace
                settingsSection(title: "Připomínky", icon: "bell.fill") {
                    VStack(spacing: 12) {
                        Text("Denní připomínka tréninku")
                            .font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))

                        HStack(spacing: 8) {
                            ForEach([6, 7, 8, 9, 12, 17, 18, 19], id: \.self) { hour in
                                Button {
                                    NotificationService.shared.scheduleWorkoutReminder(hour: hour, minute: 0)
                                } label: {
                                    Text("\(hour):00")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .padding(.horizontal, 8).padding(.vertical, 6)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .padding(.horizontal, 4)

                        Text("Klepnutím nastavíš připomínku na vybraný čas.")
                            .font(.caption).foregroundStyle(.white.opacity(0.4))
                    }
                }

                // MARK: — Apple Health
                settingsSection(title: "Apple Health", icon: "heart.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: healthKitService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(healthKitService.isAuthorized ? .green : .orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(healthKitService.isAuthorized ? "Přístup povolen" : "Přístup není povolen")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(healthKitService.isAuthorized
                                     ? "Spánek, HRV a tep se načítají automaticky."
                                     : "Bez přístupu nelze zobrazit zdravotní data.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Button {
                            healthKitRequesting = true
                            healthKitMessage = nil
                            Task {
                                do {
                                    try await healthKitService.requestAuthorization()
                                    healthKitMessage = "✅ Přístup k Apple Health byl udělen."
                                } catch {
                                    healthKitMessage = "⚠️ Oprávnění se nezdařilo: \(error.localizedDescription)\n\nOtevři Nastavení → Soukromí → Zdraví → Agile Trainer."
                                }
                                healthKitRequesting = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if healthKitRequesting {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "heart.text.square.fill")
                                }
                                Text(healthKitService.isAuthorized ? "Znovu požádat o přístup" : "Povolit přístup k Apple Health")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(healthKitRequesting)

                        if let msg = healthKitMessage {
                            Text(msg)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            if let url = URL(string: "App-Prefs:HEALTH") {
                                UIApplication.shared.open(url)
                            } else if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "gear")
                                Text("Otevřít Nastavení → Zdraví")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // MARK: — Uložit
                Button(action: saveProfile) {
                    Text("Uložit nastavení")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .padding(.top, 16)
        }
        .onAppear { loadFromProfile() }
        .onChange(of: profile.updatedAt) { loadFromProfile() }
    }

    // MARK: — Row builders

    private func goalRow(_ goal: FitnessGoal) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { draftGoal = goal }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: goal.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(draftGoal == goal ? .white : .white.opacity(0.4))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(draftGoal == goal ? .white : .white.opacity(0.6))
                    Text(goal.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                if draftGoal == goal {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                }
            }
            .padding(12)
            .background(draftGoal == goal ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(draftGoal == goal ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
    }

    private func levelButton(_ level: FitnessLevel) -> some View {
        Button {
            withAnimation { draftLevel = level }
        } label: {
            Text(level.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(draftLevel == level ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(draftLevel == level ? Color.blue : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func splitButton(_ split: SplitType) -> some View {
        Button {
            withAnimation { draftSplit = split }
        } label: {
            Text(split.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(draftSplit == split ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(draftSplit == split ? Color.blue : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func equipmentToggle(_ equip: Equipment) -> some View {
        Button {
            if draftEquipment.contains(equip) {
                draftEquipment.remove(equip)
            } else {
                draftEquipment.insert(equip)
            }
        } label: {
            HStack(spacing: 8) {
                Text(equip.emoji).font(.system(size: 16))
                Text(equip.rawValue)
                    .font(.system(size: 13))
                    .foregroundStyle(draftEquipment.contains(equip) ? .white : .white.opacity(0.5))
                Spacer()
                if draftEquipment.contains(equip) {
                    Image(systemName: "checkmark").font(.caption).foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(draftEquipment.contains(equip) ? Color.blue.opacity(0.15) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: — Settings section wrapper

    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            content()
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
    }

    // MARK: — Load / Save

    private func loadFromProfile() {
        draftName = profile.name
        draftGoal = profile.primaryGoal
        draftLevel = profile.fitnessLevel
        draftDays = profile.availableDaysPerWeek
        draftSplit = profile.preferredSplitType
        draftDuration = profile.sessionDurationMinutes
        draftSport = profile.primarySport ?? ""
        draftEquipment = Set(profile.availableEquipment)
    }

    private func saveProfile() {
        profile.name = draftName.trimmingCharacters(in: .whitespaces).isEmpty ? profile.name : draftName
        profile.primaryGoal = draftGoal
        profile.fitnessLevel = draftLevel
        profile.availableDaysPerWeek = draftDays
        profile.preferredSplitType = draftSplit
        profile.sessionDurationMinutes = draftDuration
        profile.primarySport = draftSport.trimmingCharacters(in: .whitespaces).isEmpty ? nil : draftSport
        profile.availableEquipment = Array(draftEquipment)
        profile.updatedAt = .now
        onSave()
    }
}
