// GymProfilesView.swift
// Správa profilů posiloven — přidání / odebrání gym s GPS detekcí a vybavením.
// Dostupné ze Settings → "Moje Posilovny"

import SwiftUI
import SwiftData
import CoreLocation

struct GymProfilesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GymProfile.createdAt, order: .reverse) private var gyms: [GymProfile]
    @StateObject private var detector = GymDetectionService.shared

    @State private var showAddSheet = false
    @State private var deleteTarget: GymProfile?

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // ── Info karta
                    infoCard

                    // ── Aktuální gym detekce
                    if let gym = detector.currentGym {
                        detectedGymBanner(gym: gym)
                    }

                    // ── Seznam gymů
                    ForEach(gyms) { gym in
                        GymProfileCard(gym: gym) {
                            deleteTarget = gym
                        }
                    }

                    if gyms.isEmpty {
                        emptyPlaceholder
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Moje Posilovny")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppColors.primaryAccent)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddGymProfileView()
        }
        .confirmationDialog("Smazat fitko?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            if let gym = deleteTarget {
                Button("Smazat \(gym.name)", role: .destructive) {
                    modelContext.delete(gym)
                    deleteTarget = nil
                }
            }
            Button("Zrušit", role: .cancel) { deleteTarget = nil }
        }
        .onAppear {
            detector.start(gyms: gyms)
        }
        .onChange(of: gyms) { oldGyms, newGyms in
            detector.start(gyms: newGyms)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sub-Views

    private var infoCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppColors.primaryAccent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Automatická detekce fitka")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Když přijedeš na místo, AI trenér automaticky sestaví trénink jen s dostupným vybavením.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColors.primaryAccent.opacity(0.2), lineWidth: 1))
    }

    private func detectedGymBanner(gym: GymProfile) -> some View {
        HStack(spacing: 10) {
            Circle().fill(Color.green).frame(width: 10, height: 10)
                .overlay(Circle().fill(Color.green.opacity(0.3)).frame(width: 18, height: 18))
            Text("Jsi v \(gym.name)")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
        }
        .padding(12)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.green.opacity(0.25), lineWidth: 1))
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppColors.primaryAccent.opacity(0.4))
            Text("Žádná fitka")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
            Text("Přidej svoji posilovnu a AI bude vědět, co máš k dispozici.")
                .font(.callout)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }
}

// MARK: - Gym Profile Card

struct GymProfileCard: View {
    let gym: GymProfile
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 46, height: 46)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(gym.name)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    if gym.isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.primaryAccent))
                    }
                }
                Text(gym.equipmentContext)
                    .font(.caption)
                    .foregroundStyle(AppColors.textMuted)
                    .lineLimit(1)
                Text("Radius: \(Int(gym.radiusMeters))m")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.error.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - Add Gym Sheet

struct AddGymProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var radius: Double = 150
    @State private var isDefault: Bool = false
    @State private var selectedEquipment: Set<String> = []
    @StateObject private var locationHelper = AddGymLocationHelper()

    private let equipmentOptions: [(String, String)] = [
        ("Velká Osa (Barbell)", "barbell"),
        ("Jednoručky (Dumbbells)", "dumbbell"),
        ("Kladka (Cable)", "cable"),
        ("Strojové cviky (Machine)", "machine"),
        ("Kettlebell", "kettlebell"),
        ("Hrazda (Pull-up Bar)", "pullupBar"),
        ("Bradla (Dip Bar)", "dipBar"),
        ("Trx / Závěsné lano", "trx"),
        ("Bezosová páka (Smith)", "smith"),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Název
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Název fitka")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textMuted)
                            TextField("Např. Můj Gym Praha", text: $name)
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(12)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        // GPS
                        VStack(alignment: .leading, spacing: 8) {
                            Text("GPS Lokace")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textMuted)
                            Button {
                                locationHelper.detect()
                            } label: {
                                HStack {
                                    Image(systemName: locationHelper.location != nil ? "location.fill" : "location")
                                        .foregroundStyle(locationHelper.location != nil ? .green : AppColors.primaryAccent)
                                    Text(locationHelper.location != nil
                                         ? String(format: "%.5f, %.5f", locationHelper.location!.coordinate.latitude, locationHelper.location!.coordinate.longitude)
                                         : "Zjistit aktuální polohu")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        // Radius
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Radius detekce")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.textMuted)
                                Spacer()
                                Text("\(Int(radius)) m")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppColors.primaryAccent)
                            }
                            Slider(value: $radius, in: 50...500, step: 50)
                                .tint(AppColors.primaryAccent)
                        }

                        // Vybavení
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Dostupné vybavení")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textMuted)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(equipmentOptions, id: \.1) { label, key in
                                    let active = selectedEquipment.contains(key)
                                    Button {
                                        if active { selectedEquipment.remove(key) }
                                        else { selectedEquipment.insert(key) }
                                    } label: {
                                        Text(label)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(active ? .white : AppColors.textSecondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(active ? AppColors.primaryAccent.opacity(0.3) : Color.white.opacity(0.07),
                                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(active ? AppColors.primaryAccent.opacity(0.6) : Color.clear, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Toggle("Nastavit jako výchozí", isOn: $isDefault)
                            .tint(AppColors.primaryAccent)
                            .foregroundStyle(AppColors.textPrimary)

                        // Uložit
                        Button {
                            saveGym()
                        } label: {
                            Text("Uložit Fitko")
                                .font(.body.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(AppColors.primaryAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(name.isEmpty || locationHelper.location == nil)
                        .opacity(name.isEmpty || locationHelper.location == nil ? 0.5 : 1)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Nové Fitko")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavřít") { dismiss() }.foregroundStyle(AppColors.textSecondary)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func saveGym() {
        guard let loc = locationHelper.location else { return }
        let gym = GymProfile(
            name: name,
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            radiusMeters: radius,
            equipment: Array(selectedEquipment),
            isDefault: isDefault
        )
        modelContext.insert(gym)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Location Helper

@MainActor
final class AddGymLocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }

    func detect() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.location = locations.last }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLogger.warning("[AddGymLocationHelper] Lokace selhala: \(error.localizedDescription)")
    }
}
