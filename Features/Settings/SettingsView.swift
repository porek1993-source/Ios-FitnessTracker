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
    @State private var draftWeightKg: Double = 75.0
    @State private var draftWeightText: String = "75"
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: .now) ?? .now
    @EnvironmentObject private var healthKitService: HealthKitService

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // MARK: — Jméno + Váha
                settingsSection(title: "Profil", icon: "person.fill") {
                    VStack(alignment: .leading, spacing: 12) {
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

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tělesná váha").font(.caption).foregroundStyle(.white.opacity(0.5))
                            HStack(spacing: 8) {
                                TextField("75", text: $draftWeightText)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .onChange(of: draftWeightText) { _, v in
                                        let normalized = v.replacingOccurrences(of: ",", with: ".")
                                        if let kg = Double(normalized), kg > 0 {
                                            draftWeightKg = kg
                                        }
                                    }
                                Text("kg")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Text("Používá se pro přesný výpočet kalorií v Apple Health.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
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
                settingsSection(title: "Dostupné vybavení", icon: "scalemass.fill") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach(Equipment.allCases, id: \.rawValue) { equip in
                            equipmentToggle(equip)
                        }
                    }
                }

                // MARK: — Notifikace
                settingsSection(title: "Připomínky", icon: "bell.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Denní připomínka tréninku")
                            .font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))

                        DatePicker("Čas připomínky", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .environment(\.colorScheme, .dark)
                            .onChange(of: reminderTime) { newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                if let h = comps.hour, let m = comps.minute {
                                    NotificationService.shared.scheduleWorkoutReminder(hour: h, minute: m)
                                }
                            }

                        Text("Klepnutím na čas nastavíš přesnou minutu.")
                            .font(.caption).foregroundStyle(.white.opacity(0.4))
                    }
                }

                // MARK: — Apple Health
                // ✅ OPRAVENO: Používá AppleHealthSection z HealthKitErrorHandling.swift
                // — lepší error handling, typované stavy, elegantní UX
                settingsSection(title: "Apple Health", icon: "heart.fill") {
                    AppleHealthSection(healthKitService: healthKitService)
                }

                // MARK: — Export Dat
                settingsSection(title: "Export Dat", icon: "doc.text.fill") {
                    ExportButtonView()
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
        let isSelected = draftEquipment.contains(equip)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    draftEquipment.remove(equip)
                } else {
                    draftEquipment.insert(equip)
                }
            }
        } label: {
            VStack(spacing: 8) {
                Text(equip.emoji).font(.system(size: 24))
                Text(equip.localizedName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.08), lineWidth: 1.5)
            )
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
        draftWeightKg = profile.weightKg
        draftWeightText = profile.weightKg.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", profile.weightKg)
            : String(format: "%.1f", profile.weightKg)
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
        if draftWeightKg > 0 { profile.weightKg = draftWeightKg }
        profile.updatedAt = .now
        onSave()
    }
}
