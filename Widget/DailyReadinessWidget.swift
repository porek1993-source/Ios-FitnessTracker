// DailyReadinessWidget.swift
// WidgetKit rozšíření pro AgileFitnessTrainer.
// Zobrazuje skóre připravenosti a zjednodušenou svalovou heatmapu.

import WidgetKit
import SwiftUI
import SwiftData

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Timeline Entry
// MARK: ═══════════════════════════════════════════════════════════════════════

struct ReadinessEntry: TimelineEntry {
    let date: Date
    let readinessScore: Int          // 0–100
    let readinessLevel: String       // "green" / "orange" / "red"
    let todayLabel: String           // "Push Day", "Rest Day" ap.
    let muscleLoad: [String: Double] // Klíč = svalová skupina, Hodnota = relativní zátěž 0.0–1.0
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Timeline Provider
// MARK: ═══════════════════════════════════════════════════════════════════════

struct ReadinessTimelineProvider: TimelineProvider {

    // Fallback pro placeholder a snapshot
    private static let sample = ReadinessEntry(
        date: .now,
        readinessScore: 78,
        readinessLevel: "green",
        todayLabel: "Push Day",
        muscleLoad: ["chest": 0.9, "shoulders": 0.7, "triceps": 0.6, "legs": 0.2, "back": 0.1]
    )

    func placeholder(in context: Context) -> ReadinessEntry {
        Self.sample
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        completion(Self.sample)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        let modelContext = ModelContext(SharedModelContainer.container)
        
        // Přečteme data ze SwiftData (sdílená App Group databáze)
        let entry = buildEntry(from: modelContext)
        
        // Aktualizujeme každých 30 minut
        let nextUpdate = Calendar.mondayStart.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func buildEntry(from context: ModelContext) -> ReadinessEntry {
        // Pokusíme se načíst profil
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try? context.fetch(descriptor).first else {
            return Self.sample
        }

        // Najdeme aktivní plán a dnešní den
        guard let activePlan = profile.workoutPlans.first(where: \.isActive) else {
            return ReadinessEntry(
                date: .now, readinessScore: 50, readinessLevel: "orange",
                todayLabel: "Žádný plán", muscleLoad: [:]
            )
        }

        let today = Date.now
        let dayIndex = today.weekday // 1=Po ... 7=Ne
        let todayDay = activePlan.scheduledDays.first { $0.dayOfWeek == dayIndex }
        let label = todayDay?.label ?? "Odpočinkový den"

        // Readiness z posledního záznamu
        let todaySession = activePlan.sessions.first { $0.startedAt.isSameDay(as: today) }
        let score = Int(todaySession?.readinessScore ?? 70)
        let level: String = switch score {
        case 70...100: "green"
        case 40..<70:  "orange"
        default:       "red"
        }

        // Jednoduchá heatmapa — zátěž podle posledních 48h tréninků
        var muscleLoad: [String: Double] = [:]
        let cutoff = Calendar.mondayStart.date(byAdding: .hour, value: -48, to: today)!
        let recentSessions = activePlan.sessions.filter { $0.startedAt > cutoff }
        for session in recentSessions {
            for exercise in session.exercises {
                let group = exercise.exercise?.category.rawValue ?? "other"
                muscleLoad[group, default: 0] += 0.3
            }
        }
        // Normalizujeme
        if let maxLoad = muscleLoad.values.max(), maxLoad > 0 {
            for key in muscleLoad.keys {
                muscleLoad[key] = min(1.0, (muscleLoad[key] ?? 0) / maxLoad)
            }
        }

        return ReadinessEntry(
            date: today, readinessScore: score, readinessLevel: level,
            todayLabel: label, muscleLoad: muscleLoad
        )
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Widget View (.systemMedium)
// MARK: ═══════════════════════════════════════════════════════════════════════

struct DailyReadinessWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ReadinessEntry

    private var scoreColor: Color {
        switch entry.readinessLevel {
        case "green":  return Color.appGreenBadge
        case "orange": return .orange
        default:       return Color.appRedText
        }
    }

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        case .accessoryRectangular:
            rectangularView
        case .accessoryCircular:
            circularView
        case .accessoryInline:
            Text("Připravenost: \(entry.readinessScore)/100")
        default:
            mediumView
        }
    }
    
    // MARK: - Lock Screen (Accessory) Views
    
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bolt.heart.fill")
                    .foregroundStyle(scoreColor)
                Text("Připravenost \(entry.readinessScore)")
                    .font(.headline)
            }
            Text(entry.todayLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Circle()
                .trim(from: 0, to: CGFloat(entry.readinessScore) / 100)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack {
                Text("\(entry.readinessScore)")
                    .font(.system(.headline, design: .rounded))
            }
        }
    }

    // MARK: - System Views

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Levá strana — Readiness Score ring
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 6)
                        .frame(width: 72, height: 72)
                    Circle()
                        .trim(from: 0, to: CGFloat(entry.readinessScore) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(entry.readinessScore)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Ready")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .textCase(.uppercase)
                    }
                }

                Text(entry.todayLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            // Pravá strana — Mini heatmapa (svalový panáček)
            VStack(alignment: .leading, spacing: 6) {
                Text("SVALOVÁ ZÁTĚŽ")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.white.opacity(0.3))
                    .kerning(1.2)

                MiniHeatmap(muscleLoad: entry.muscleLoad)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color.appBackground)
    }
}

// MARK: - Mini Heatmap

private struct MiniHeatmap: View {
    let muscleLoad: [String: Double]

    private let muscleGroups: [(name: String, key: String)] = [
        ("Prsa",    "chest"),
        ("Záda",    "back"),
        ("Ramena",  "shoulders"),
        ("Biceps",  "biceps"),
        ("Triceps", "triceps"),
        ("Nohy",    "legs"),
        ("Core",    "core")
    ]

    var body: some View {
        VStack(spacing: 3) {
            ForEach(muscleGroups, id: \.key) { muscle in
                let load = muscleLoad[muscle.key] ?? 0
                HStack(spacing: 6) {
                    Text(muscle.name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 42, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.06))
                                .frame(height: 6)
                            Capsule()
                                .fill(barColor(for: load))
                                .frame(width: max(4, geo.size.width * load), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private func barColor(for load: Double) -> Color {
        switch load {
        case 0..<0.3:  return .green.opacity(0.7)
        case 0.3..<0.6: return .yellow.opacity(0.8)
        case 0.6..<0.8: return .orange
        default:        return Color.appRedText
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Widget Configuration
// MARK: ═══════════════════════════════════════════════════════════════════════

struct DailyReadinessWidget: Widget {
    let kind: String = "DailyReadinessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessTimelineProvider()) { entry in
            DailyReadinessWidgetView(entry: entry)
        }
        .configurationDisplayName("Denní Připravenost")
        .description("Tvé aktuální skóre připravenosti a svalová heatmapa.")
        .supportedFamilies([.systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget Bundle (vstupní bod pro Widget Extension target)

@main
struct AgileFitnessWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyReadinessWidget()
        RestTimerLiveActivity()
    }
}
