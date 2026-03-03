// AgileTrainerWidget.swift
// Agilní Fitness Trenér — iOS Home Screen Widget (systemSmall, systemMedium)
//
// Načítá denní Readiness Score a název dnešního tréninku z UserDefaults (App Group).

import WidgetKit
import SwiftUI

// MARK: - App Group Constants
// Pozor: Změň `suitName` na skutečný bundle tvé App Group v Capabilities.
private let sharedDefaults = UserDefaults(suiteName: "group.com.agilefitness.shared")

// MARK: - Data Model
struct TrainerEntry: TimelineEntry {
    let date: Date
    let readinessScore: Int
    let todayWorkoutName: String
}

// MARK: - Timeline Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TrainerEntry {
        TrainerEntry(date: Date(), readinessScore: 85, todayWorkoutName: "Push • Hrudník & Ramena")
    }

    func getSnapshot(in context: Context, completion: @escaping (TrainerEntry) -> ()) {
        let entry = fetchEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Obnova každou hodinu + po každém otevření appky (reloadAllTimelines z hlavní appky)
        let entries = [fetchEntry()]
        let nextUpdate = Calendar.mondayStart.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    // Načte surová data sdílená hlavní aplikací
    private func fetchEntry() -> TrainerEntry {
        // Fallback hodnoty, pokud uživatel appku ještě neotevřel
        let score = sharedDefaults?.integer(forKey: "widget_readiness_score") ?? 0
        let workoutName = sharedDefaults?.string(forKey: "widget_today_workout") ?? "Generuji trénink..."
        
        return TrainerEntry(date: Date(), readinessScore: score, todayWorkoutName: workoutName)
    }
}

// MARK: - UI Configuration (Small, Medium)
struct AgileTrainerWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Pozadí widgetu (temný gradient)
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.12, blue: 0.20), Color(red: 0.04, green: 0.06, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            switch family {
            case .systemSmall:   smallWidgetContent
            case .systemMedium:  mediumWidgetContent
            default:             smallWidgetContent
            }
        }
    }

    // ── System Small ──────────────────────────────────────────────────────────
    private var smallWidgetContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Hlavička (Readiness Kroužek)
            HStack {
                ReadinessRing(score: Double(entry.readinessScore), size: 44)
                Spacer()
                Image(systemName: "bolt.heart.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 16))
            }
            Spacer()
            // Název dnešního tréninku
            Text("Na programu")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
            
            Text(entry.todayWorkoutName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(14)
    }

    // ── System Medium ─────────────────────────────────────────────────────────
    private var mediumWidgetContent: some View {
        HStack(spacing: 20) {
            // Levá část (Readiness)
            VStack {
                ReadinessRing(score: Double(entry.readinessScore), size: 66)
                Text("Připravenost")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 4)
            }
            
            Divider().background(.white.opacity(0.1))
            
            // Pravá část (Dnešní trénink & CTA)
            VStack(alignment: .leading, spacing: 6) {
                Text("DNEŠNÍ TRÉNINK")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.blue.opacity(0.8))
                    .kerning(1.0)
                
                Text(entry.todayWorkoutName)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                Spacer()
                
                // Falešné tlačítko (Widgets jsou read-only tap targety, klepnutí otevře appku)
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("Zahájit relaci")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }
}

// MARK: - Pomocná komponenta (Prstenec)
private struct ReadinessRing: View {
    let score: Double
    let size: CGFloat
    
    var color: Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .red
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: size * 0.12)
            Circle()
                .trim(from: 0, to: score / 100.0)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(score))")
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Main Widget Config
@main
struct AgileTrainerWidget: Widget {
    let kind: String = "AgileTrainerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                AgileTrainerWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                AgileTrainerWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Agilní Trenér")
        .description("Sleduj svou dnešní připravenost a aktuální trénink podle AI.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews
#Preview("Small", as: .systemSmall) {
    AgileTrainerWidget()
} timeline: {
    TrainerEntry(date: .now, readinessScore: 84, todayWorkoutName: "Pull (Záda & Biceps)")
}

#Preview("Medium", as: .systemMedium) {
    AgileTrainerWidget()
} timeline: {
    TrainerEntry(date: .now, readinessScore: 42, todayWorkoutName: "Aktivní odpočinek")
}
