// QuickWorkoutPickerView.swift
// Agilní Fitness Trenér — Smart Quick Workout Hub
//
// Moduly:
//   1. Partie (svalová skupina)         → cílený silový trénink z DB
//   2. Zdravotní problém                → terapeutický/mobilizační plán
//   3. Ženské zdraví & Cycle Syncing    → trénink podle fáze cyklu
//   4. Anti-Stres & Mentální Reset      → "Dneska toho mám dost"
//   5. Sport-Specific Prehab            → prevence pro konkrétní sport
//   6. Longevity 50+                    → rovnováha, úchop, funkční pohyb
//   7. Micro-Breaks                     → kancelářské přestávky + notifikace
//
// ⚠️ TÝDENNÍ PLÁN: NE — všechny session jsou standalone (dayOfWeek = 99)

import SwiftUI
import SwiftData
import UserNotifications

// MARK: ══════════════════════════════════════════════════════════════════════
// MARK: Top-Level Module Enum
// MARK: ══════════════════════════════════════════════════════════════════════

enum QuickModule: String, CaseIterable, Identifiable {
    case muscle     = "Partie"
    case health     = "Zdraví & Rehab"
    case femHealth  = "Ženské zdraví"
    case antiStress = "Anti-Stres"
    case prehab     = "Sport Prehab"
    case longevity  = "Longevity 50+"
    case microBreak = "Micro-Breaks"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .muscle:     return "figure.strengthtraining.traditional"
        case .health:     return "cross.case.fill"
        case .femHealth:  return "heart.circle.fill"
        case .antiStress: return "brain.head.profile"
        case .prehab:     return "sportscourt.fill"
        case .longevity:  return "person.and.background.striped.horizontal"
        case .microBreak: return "desktopcomputer"
        }
    }

    var accent: Color {
        switch self {
        case .muscle:     return Color(red: 0.22, green: 0.55, blue: 1.0)
        case .health:     return Color(red: 0.18, green: 0.82, blue: 0.48)
        case .femHealth:  return Color(red: 0.95, green: 0.44, blue: 0.68)
        case .antiStress: return Color(red: 0.58, green: 0.44, blue: 0.95)
        case .prehab:     return Color(red: 1.0,  green: 0.65, blue: 0.0)
        case .longevity:  return Color(red: 0.15, green: 0.82, blue: 0.88)
        case .microBreak: return Color(red: 0.95, green: 0.30, blue: 0.30)
        }
    }

    var tagline: String {
        switch self {
        case .muscle:     return "Cílený silový trénink podle partie"
        case .health:     return "Mobilizace, rehab a bolestivá místa"
        case .femHealth:  return "Trénink synchronizovaný s cyklem"
        case .antiStress: return "Kortizol dolů, nervová soustava v klidu"
        case .prehab:     return "Prevence přetížení pro tvůj sport"
        case .longevity:  return "Síla, rovnováha a soběstačnost do 90"
        case .microBreak: return "2 minuty pro tělo každé 2 hodiny"
        }
    }
}

// MARK: ══════════════════════════════════════════════════════════════════════
// MARK: Shared Data Types
// MARK: ══════════════════════════════════════════════════════════════════════

struct QuickExerciseTemplate: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let nameEN: String
    let slug: String
    let sets: Int
    let repsMin: Int
    let repsMax: Int
    let isBodyweight: Bool
    let coachTip: String
    var durationSeconds: Int? = nil
}

struct QuickWorkoutPlan: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let accentColor: Color
    let exercises: [QuickExerciseTemplate]
    let warmupItems: [String]
    let coachNote: String
    let estimatedMinutes: Int
    let intensity: WorkoutIntensity

    enum WorkoutIntensity: String {
        case low    = "Nízká"
        case medium = "Střední"
        case high   = "Vysoká"
        var color: Color {
            switch self { case .low: return .green; case .medium: return .orange; case .high: return .red }
        }
        var icon: String {
            switch self { case .low: return "tortoise.fill"; case .medium: return "bolt.fill"; case .high: return "flame.fill" }
        }
    }
}

// MARK: ══════════════════════════════════════════════════════════════════════
// MARK: MODULE 1 — Svalové partie
// MARK: ══════════════════════════════════════════════════════════════════════

struct MuscleTarget: Identifiable, Hashable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let muscleGroups: [MuscleGroup]
    let exerciseSlugs: [String]
}

extension MuscleTarget {
    static let all: [MuscleTarget] = [
        MuscleTarget(id: "chest",     icon: "💪", title: "Hrudník",       subtitle: "Bench, kliky, kladky",
                     muscleGroups: [.chest, .frontShoulders, .triceps],
                     exerciseSlugs: ["bench-press","dumbbell-bench-press","incline-bench-press","cable-fly","push-up","dips"]),
        MuscleTarget(id: "back",      icon: "🦴", title: "Záda",          subtitle: "Lats, střed, spodní záda",
                     muscleGroups: [.lats, .trapsMiddle, .rearShoulders, .lowerback],
                     exerciseSlugs: ["pull-up","lat-pulldown","seated-cable-row","bent-over-row","deadlift","face-pull"]),
        MuscleTarget(id: "legs",      icon: "🦵", title: "Nohy",          subtitle: "Quady, hamstringy, hýždě",
                     muscleGroups: [.quads, .hamstrings, .glutes, .calves],
                     exerciseSlugs: ["squat","leg-press","romanian-deadlift","leg-curl","glute-bridge","calf-raise"]),
        MuscleTarget(id: "shoulders", icon: "🏋️", title: "Ramena",        subtitle: "Přední, střední, zadní delta",
                     muscleGroups: [.frontShoulders, .rearShoulders, .traps],
                     exerciseSlugs: ["overhead-press","dumbbell-lateral-raise","face-pull","rear-delt-fly","arnold-press"]),
        MuscleTarget(id: "arms",      icon: "🤜", title: "Paže",          subtitle: "Biceps + triceps",
                     muscleGroups: [.biceps, .triceps, .forearms],
                     exerciseSlugs: ["barbell-curl","dumbbell-curl","tricep-pushdown","skull-crusher","hammer-curl"]),
        MuscleTarget(id: "core",      icon: "🔥", title: "Core & Břicho", subtitle: "Plank, rotace, přímý sval",
                     muscleGroups: [.abdominals, .obliques, .lowerback],
                     exerciseSlugs: ["plank","crunch","leg-raise","russian-twist","ab-wheel","dead-bug"]),
        MuscleTarget(id: "glutes",    icon: "🍑", title: "Hýždě",         subtitle: "Hip thrust, výpady, mosty",
                     muscleGroups: [.glutes, .hamstrings],
                     exerciseSlugs: ["hip-thrust","glute-bridge","romanian-deadlift","bulgarian-split-squat","cable-kickback"]),
        MuscleTarget(id: "fullbody",  icon: "⚡️", title: "Celé tělo",     subtitle: "Komplexní multi-joint cviky",
                     muscleGroups: MuscleGroup.allCases,
                     exerciseSlugs: ["deadlift","squat","bench-press","pull-up","overhead-press","kettlebell-swing"]),
    ]
}

// MARK: ══════════════════════════════════════════════════════════════════════
// MARK: MODULE 2 — Zdravotní problémy
// MARK: ══════════════════════════════════════════════════════════════════════

extension QuickWorkoutPlan {
    static let healthProblems: [QuickWorkoutPlan] = [
        QuickWorkoutPlan(
            label: "Krční páteř od PC", icon: "🖥️",
            accentColor: Color(red: 0.15, green: 0.82, blue: 0.88),
            exercises: [
                .init(name: "Chin Tuck — zasunutí brady", nameEN: "Chin Tuck", slug: "chin-tuck",
                      sets: 3, repsMin: 10, repsMax: 15, isBodyweight: true,
                      coachTip: "Zasun bradu dozadu. Drž 3s. Nepředklán hlavu."),
                .init(name: "Levator Scapulae protažení", nameEN: "Levator Scapulae Stretch", slug: "levator-scapulae-stretch",
                      sets: 3, repsMin: 1, repsMax: 1, isBodyweight: true,
                      coachTip: "Nakloň hlavu k rameni, rukou lehce přitlač. Drž 25s.", durationSeconds: 25),
                .init(name: "Thoracic Extension přes roli", nameEN: "Thoracic Extension Roll", slug: "thoracic-extension-roll",
                      sets: 2, repsMin: 8, repsMax: 10, isBodyweight: true,
                      coachTip: "Role pod lopatky. Překlaň se dozad. Uvolňuje hrudní páteř."),
                .init(name: "Deep Cervical Flexor aktivace", nameEN: "Deep Cervical Flexor", slug: "deep-cervical-flexor",
                      sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true,
                      coachTip: "Vleže — přitisknout zátylek k podložce bez zvednutí hlavy."),
            ],
            warmupItems: ["5× pomalé kroužení hlavy každým směrem", "10× krčení ramen k uším a dolů"],
            coachNote: "Preventivní cviky pro bolesti od sezení. Při akutní bolesti vynech tah a soustřeď se jen na protažení.",
            estimatedMinutes: 20, intensity: .low
        ),
        QuickWorkoutPlan(
            label: "Bolesti spodních zad", icon: "🪑",
            accentColor: Color(red: 1.0, green: 0.55, blue: 0.1),
            exercises: [
                .init(name: "Dead Bug", nameEN: "Dead Bug", slug: "dead-bug",
                      sets: 3, repsMin: 8, repsMax: 10, isBodyweight: true,
                      coachTip: "Záda přimáčkni k podložce. Spouštěj protilehlou ruku+nohu pomalu."),
                .init(name: "Bird Dog", nameEN: "Bird Dog", slug: "bird-dog",
                      sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true,
                      coachTip: "Neutrální páteř. Protilehlá ruka a noha — bez rotace boků."),
                .init(name: "Glute Bridge", nameEN: "Glute Bridge", slug: "glute-bridge",
                      sets: 3, repsMin: 12, repsMax: 15, isBodyweight: true,
                      coachTip: "Zatlač patami, zvedni boky. Kontrahuj hýždě nahoře 2s."),
                .init(name: "Cat-Cow mobilizace", nameEN: "Cat Cow", slug: "cat-cow",
                      sets: 2, repsMin: 10, repsMax: 12, isBodyweight: true,
                      coachTip: "Celá páteř se vlní. Dýchej rovnoměrně."),
            ],
            warmupItems: ["10× Pelvic tilt vleže", "5× Cat-Cow jako zahřátí"],
            coachNote: "Při akutní bolesti NECVIČ. Tyto cviky posilují core bez zatížení bederní páteře.",
            estimatedMinutes: 20, intensity: .low
        ),
        QuickWorkoutPlan(
            label: "Bolesti ramen", icon: "💼",
            accentColor: Color(red: 0.58, green: 0.44, blue: 0.95),
            exercises: [
                .init(name: "Band External Rotation", nameEN: "Band External Rotation", slug: "band-external-rotation",
                      sets: 3, repsMin: 15, repsMax: 20, isBodyweight: false,
                      coachTip: "Loket přitiskni k boku. Rotuj ven. Lehká guma."),
                .init(name: "Wall Slides", nameEN: "Wall Slides", slug: "wall-slides",
                      sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true,
                      coachTip: "Záda a ruce ke zdi. Klouzej pažemi nahoru — udržuj kontakt."),
                .init(name: "Face Pull — lehká váha", nameEN: "Face Pull", slug: "face-pull",
                      sets: 3, repsMin: 15, repsMax: 20, isBodyweight: false,
                      coachTip: "Ukazováčky k uším. Lokty výše než ramena."),
                .init(name: "Sleeper Stretch", nameEN: "Sleeper Stretch", slug: "sleeper-stretch",
                      sets: 3, repsMin: 1, repsMax: 1, isBodyweight: true,
                      coachTip: "Na boku, rameno pod tebou. Druhou rukou tlač předloktí dolů. Drž 25s.", durationSeconds: 25),
            ],
            warmupItems: ["5× kroužení pažemi (velký oblouk)", "2 min lehké veslování"],
            coachNote: "Pro bolest z přetížení nebo impingementu. Pokud bolest trvá 2+ týdny, navštiv fyzioterapeuta.",
            estimatedMinutes: 25, intensity: .low
        ),
        QuickWorkoutPlan(
            label: "Bolesti kolen", icon: "🦿",
            accentColor: Color(red: 1.0, green: 0.82, blue: 0.1),
            exercises: [
                .init(name: "Terminal Knee Extension", nameEN: "Terminal Knee Extension", slug: "terminal-knee-extension",
                      sets: 3, repsMin: 15, repsMax: 20, isBodyweight: false,
                      coachTip: "Guma za koleno. Propínej koleno do plného natažení — aktivuje VMO."),
                .init(name: "Step-Up nízká bedna", nameEN: "Step Up Low", slug: "step-up",
                      sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true,
                      coachTip: "Max 30cm výška. Zatlač patou, koleno nepřekračuje špičku."),
                .init(name: "Clamshell", nameEN: "Clamshell", slug: "clamshell",
                      sets: 3, repsMin: 15, repsMax: 20, isBodyweight: true,
                      coachTip: "Na boku. Otevírej koleno nahoru — stabilizace."),
                .init(name: "VMO Squat", nameEN: "VMO Squat", slug: "vmo-squat",
                      sets: 3, repsMin: 12, repsMax: 15, isBodyweight: true,
                      coachTip: "Špičky lehce ven. Dřep do 90°. Fokus na vnitřní quad."),
            ],
            warmupItems: ["5 min jízda na kole (nízký odpor)", "Foam roll quady + IT band"],
            coachNote: "Pro patelofemoral syndrom a slabost kolenního okolí. Bolest při cvičení = stop.",
            estimatedMinutes: 30, intensity: .low
        ),
    ]
}

// MARK: ══════════════════════════════════════════════════════════════════════
// MARK: MODULE 3 — Ženské zdraví & Cycle Syncing
// MARK: ══════════════════════════════════════════════════════════════════════

enum CyclePhase: String, CaseIterable, Identifiable {
    case menstrual   = "Menstruace"
    case follicular  = "Folikulární"
    case ovulation   = "Ovulace"
    case luteal      = "Luteální"
    case menopause   = "Menopauza"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .menstrual:  return "🌊"
        case .follicular: return "🌱"
        case .ovulation:  return "⚡️"
        case .luteal:     return "🍂"
        case .menopause:  return "🌸"
        }
    }
    var subtitle: String {
        switch self {
        case .menstrual:  return "Odpočinek · Den 1–5"
        case .follicular: return "Vzestupná energie · Den 6–13"
        case .ovulation:  return "Peak síla & výkon · Den 14"
        case .luteal:     return "Snížená energie · Den 15–28"
        case .menopause:  return "Síla + prevence osteoporózy"
        }
    }
    var accentColor: Color {
        switch self {
        case .menstrual:  return Color(red: 0.95, green: 0.30, blue: 0.30)
        case .follicular: return Color(red: 0.18, green: 0.82, blue: 0.48)
        case .ovulation:  return Color(red: 1.0,  green: 0.65, blue: 0.0)
        case .luteal:     return Color(red: 0.95, green: 0.55, blue: 0.2)
        case .menopause:  return Color(red: 0.95, green: 0.44, blue: 0.68)
        }
    }
    var description: String {
        switch self {
        case .menstrual:
            return "Hladiny estrogenu a progesteronu jsou nejnižší. Priorita: obnovení, ne výkon. Jemný pohyb a dýchání snižují bolest a únavu."
        case .follicular:
            return "Estrogen roste → více energie, lepší nálada, rychlejší regenerace. Ideální čas na silový trénink. Tělo je připravené na progres."
        case .ovulation:
            return "Vrchol estrogenu a testosteronu. Jsi nejsilnější v celém cyklu. Ideální na maxima a HIIT. Pozor na hypermobilitu kloubů."
        case .luteal:
            return "Progesteron roste, energie klesá. Sniž intenzitu. Více mobilita a střední objemová práce místo maxim."
        case .menopause:
            return "Estrogen trvale klesá → klesá hustota kostí a svalová hmota. Silový trénink je nejdůležitější věc co teď pro tělo můžeš udělat."
        }
    }

    var workoutPlan: QuickWorkoutPlan {
        switch self {
        case .menstrual:
            return QuickWorkoutPlan(
                label: "Menstruace — Regenerace & Yin", icon: "🌊", accentColor: accentColor,
                exercises: [
                    .init(name: "Yin Yoga — Butterfly Pose", nameEN: "Butterfly Pose", slug: "butterfly-pose",
                          sets: 1, repsMin: 1, repsMax: 1, isBodyweight: true,
                          coachTip: "Chodidla k sobě, záda uvolněná. Drž 3–5 minut. Hluboké dýchání.", durationSeconds: 180),
                    .init(name: "Supine Twist", nameEN: "Supine Twist", slug: "supine-twist",
                          sets: 2, repsMin: 1, repsMax: 1, isBodyweight: true,
                          coachTip: "Na zádech, koleno přes tělo. Každá strana 2 min.", durationSeconds: 120),
                    .init(name: "Box Breathing 4:4:4:4", nameEN: "Box Breathing", slug: "box-breathing",
                          sets: 5, repsMin: 1, repsMax: 1, isBodyweight: true,
                          coachTip: "Nádech 4s → výdrž 4s → výdech 4s → výdrž 4s. Aktivuje parasympatik.", durationSeconds: 16),
                    .init(name: "Legs Up The Wall", nameEN: "Legs Up The Wall", slug: "legs-up-wall",
                          sets: 1, repsMin: 1, repsMax: 1, isBodyweight: true,
                          coachTip: "Nohy ke zdi 90°. Drž 5–10 minut. Snižuje únavu nohou.", durationSeconds: 300),
                ],
                warmupItems: ["Jemné kroužení kotníky a zápěstími", "Hluboké dýchání do břicha — 10 nádechů"],
                coachNote: "Záměrně pomalý a pasivní. Žádná silová práce. Tvoje tělo dělá obrovskou práci samo — nech ho odpočívat.",
                estimatedMinutes: 20, intensity: .low
            )
        case .follicular:
            return QuickWorkoutPlan(
                label: "Folikulární fáze — Buduj sílu", icon: "🌱", accentColor: accentColor,
                exercises: [
                    .init(name: "Squat — těžší váha", nameEN: "Squat", slug: "squat",
                          sets: 4, repsMin: 6, repsMax: 10, isBodyweight: false,
                          coachTip: "Energie je vysoká. Snaž se o progres váhy. Plná ROM."),
                    .init(name: "Romanian Deadlift", nameEN: "Romanian Deadlift", slug: "romanian-deadlift",
                          sets: 3, repsMin: 8, repsMax: 10, isBodyweight: false,
                          coachTip: "Hamstringy pod napětím. Tlač boky dozadu."),
                    .init(name: "Dumbbell Bench Press", nameEN: "Dumbbell Bench Press", slug: "dumbbell-bench-press",
                          sets: 3, repsMin: 8, repsMax: 12, isBodyweight: false,
                          coachTip: "Folikulární fáze = ideální pro silový progres horní části."),
                    .init(name: "Lat Pulldown", nameEN: "Lat Pulldown", slug: "lat-pulldown",
                          sets: 3, repsMin: 8, repsMax: 10, isBodyweight: false,
                          coachTip: "Plná ROM. Přitáhni lokty k žebrům."),
                    .init(name: "Hip Thrust", nameEN: "Hip Thrust", slug: "hip-thrust",
                          sets: 3, repsMin: 10, repsMax: 12, isBodyweight: false,
                          coachTip: "Kontrakce hýždí na vrcholu. Drž 1s."),
                ],
                warmupItems: ["5 min jízda nebo poklus", "2× 10 bodyweight dřepů", "Hip circle pro aktivaci hýždí"],
                coachNote: "Folikulární fáze je zlaté okno pro silový progress. Estrogen zkracuje dobu regenerace — zvedni o 5% víc než minule.",
                estimatedMinutes: 50, intensity: .high
            )
        case .ovulation:
            return QuickWorkoutPlan(
                label: "Ovulace — Maximum & HIIT", icon: "⚡️", accentColor: accentColor,
                exercises: [
                    .init(name: "Barbell Squat — těžká váha", nameEN: "Back Squat", slug: "squat",
                          sets: 5, repsMin: 3, repsMax: 5, isBodyweight: false,
                          coachTip: "Dneska je tvůj den. Atakuj maxima — tělo je připravené."),
                    .init(name: "Deadlift", nameEN: "Deadlift", slug: "deadlift",
                          sets: 4, repsMin: 3, repsMax: 5, isBodyweight: false,
                          coachTip: "Neutrální páteř. Explozivní tah."),
                    .init(name: "Overhead Press", nameEN: "Overhead Press", slug: "overhead-press",
                          sets: 4, repsMin: 5, repsMax: 6, isBodyweight: false,
                          coachTip: "Pevný core. Tlač nahoru explozivně."),
                    .init(name: "HIIT Sprint Intervals 30/30", nameEN: "Sprint Intervals", slug: "sprint-intervals",
                          sets: 8, repsMin: 1, repsMax: 1, isBodyweight: true,
                          coachTip: "30s plná rychlost, 30s chůze. Peak kardio kondice.", durationSeconds: 60),
                ],
                warmupItems: ["10 min postupné zahřátí", "3× 5 lehkých dřepů se vzrůstající váhou"],
                coachNote: "⚠️ V ovulaci jsou vazy uvolněnější → vyšší riziko zranění. Zahřej se řádně a nezapomeň na doskokovou techniku.",
                estimatedMinutes: 55, intensity: .high
            )
        case .luteal:
            return QuickWorkoutPlan(
                label: "Luteální fáze — Mobilita & Objem", icon: "🍂", accentColor: accentColor,
                exercises: [
                    .init(name: "Goblet Squat — střední váha", nameEN: "Goblet Squat", slug: "goblet-squat",
                          sets: 3, repsMin: 12, repsMax: 15, isBodyweight: false,
                          coachTip: "Sniž váhu o 10–15%. Více opakování, méně CNS zátěže."),
                    .init(name: "Dumbbell Row", nameEN: "Dumbbell Row", slug: "dumbbell-row",
                          sets: 3, repsMin: 12, repsMax: 15, isBodyweight: false,
                          coachTip: "Unilaterální práce = svalová rovnováha."),
                    .init(name: "Hip Thrust bodyweight", nameEN: "Hip Thrust BW", slug: "hip-thrust",
                          sets: 3, repsMin: 15, repsMax: 20, isBodyweight: true,
                          coachTip: "Bez závaží. Fokus na kontrakci hýždí."),
                    .init(name: "Pigeon Pose", nameEN: "Pigeon Pose", slug: "pigeon-pose",
                          sets: 2, repsMin: 1, repsMax: 1, isBodyweight: true,
                          coachTip: "Drž 45–60s. Kyčle hromadí napětí v luteální fázi.", durationSeconds: 50),
                ],
                warmupItems: ["Mobilizace boků + thoracic rotation", "Lehký poklus 5 min"],
                coachNote: "Luteální fáze není čas na PR. Sniž intenzitu, zvyš objem. Tělo reaguje lépe na střední zatížení.",
                estimatedMinutes: 40, intensity: .medium
            )
        case .menopause:
            return QuickWorkoutPlan(
                label: "Menopauza — Síla & Kosti", icon: "🌸", accentColor: accentColor,
                exercises: [
                    .init(name: "Goblet Squat", nameEN: "Goblet Squat", slug: "goblet-squat",
                          sets: 4, repsMin: 8, repsMax: 10, isBodyweight: false,
                          coachTip: "Mechanické zatížení kostí = stimulace tvorby kostní tkáně."),
                    .init(name: "Deadlift — střední váha", nameEN: "Deadlift", slug: "deadlift",
                          sets: 3, repsMin: 8, repsMax: 10, isBodyweight: false,
                          coachTip: "Posteriorní řetězec. Klíčové pro prevenci osteoporózy boků."),
                    .init(name: "Overhead Press vsedě", nameEN: "Seated Overhead Press", slug: "overhead-press",
                          sets: 3, repsMin: 10, repsMax: 12, isBodyweight: false,
                          coachTip: "Ramena — velmi ohrožená oblast v menopauze."),
                    .init(name: "Single-Leg Balance", nameEN: "Single Leg Balance", slug: "single-leg-balance",
                          sets: 3, repsMin: 1, repsMax: 1, isBodyweight: true,
                          coachTip: "Drž 30s. Progresi: zavřené oči. Prevence pádů.", durationSeconds: 30),
                    .init(name: "Farmer's Carry", nameEN: "Farmer Carry", slug: "farmers-carry",
                          sets: 3, repsMin: 1, repsMax: 1, isBodyweight: false,
                          coachTip: "30m s těžkými kettlebelly. Úchopová síla + hustota kostí."),
                ],
                warmupItems: ["5 min chůze", "Kloubní mobilizace boků a ramen", "10× dřep bez závaží"],
                coachNote: "Silový trénink je #1 lék na menopauzu. Konzultuj s lékařem před startem.",
                estimatedMinutes: 50, intensity: .medium
            )
        }
    }
}

// MARK: ══════════════════════════════════════════════════════════════════════
// MARK: MODULE 4 — Anti-Stres
// MARK: ══════════════════════════════════════════════════════════════════════

extension QuickWorkoutPlan {
    static let antiStress = QuickWorkoutPlan(
        label: "Anti-Stres Reset — 15 minut", icon: "🧠",
        accentColor: Color(red: 0.58, green: 0.44, blue: 0.95),
        exercises: [
            .init(name: "Fyziologický vzdech", nameEN: "Physiological Sigh", slug: "physiological-sigh",
                  sets: 5, repsMin: 1, repsMax: 1, isBodyweight: true,
                  coachTip: "Dvojitý nádech nosem → dlouhý výdech ústy. Nejrychlejší způsob snížení kortizolu.", durationSeconds: 10),
            .init(name: "Box Breathing 4:4:4:4", nameEN: "Box Breathing", slug: "box-breathing",
                  sets: 5, repsMin: 1, repsMax: 1, isBodyweight: true,
                  coachTip: "Nádech 4s → výdrž 4s → výdech 4s → výdrž 4s. Aktivuje parasympatický NS.", durationSeconds: 16),
            .init(name: "Bránicové dýchání vleže", nameEN: "Diaphragmatic Breathing", slug: "diaphragmatic-breathing",
                  sets: 3, repsMin: 10, repsMax: 10, isBodyweight: true,
                  coachTip: "Ruka na břicho. Nádech = břícho se zvedne. Uvolňuje napětí bránice."),
            .init(name: "Slow Walking Lunge", nameEN: "Slow Walking Lunge", slug: "walking-lunge",
                  sets: 3, repsMin: 8, repsMax: 10, isBodyweight: true,
                  coachTip: "Pomalé výpady jako meditace. Fokus POUZE na pohyb."),
            .init(name: "Pigeon Pose — svaly stresu", nameEN: "Pigeon Pose", slug: "pigeon-pose",
                  sets: 2, repsMin: 1, repsMax: 1, isBodyweight: true,
                  coachTip: "Drž 60s každou stranu. Psoas = sval stresu — uvolnění je okamžité.", durationSeconds: 60),
            .init(name: "Legs Up The Wall + dýchání", nameEN: "Legs Up The Wall", slug: "legs-up-wall",
                  sets: 1, repsMin: 1, repsMax: 1, isBodyweight: true,
                  coachTip: "Nohy ke zdi 90°. Pět minut. Aktivuje vagus nerv.", durationSeconds: 300),
        ],
        warmupItems: ["5× fyziologický vzdech", "Jemné kroužení rameny"],
        coachNote: "Tento trénink není o výkonu. Je o regulaci nervové soustavy. Záměrně pomalé tempo, žádný tlak.",
        estimatedMinutes: 15, intensity: .low
    )
}

// MARK: ══════════════════════════════════════════════════════════════════════
// MARK: MODULE 5 — Sport-Specific Prehab
// MARK: ══════════════════════════════════════════════════════════════════════

struct SportPrehab: Identifiable {
    let id: String
    let icon: String
    let sport: String
    let riskArea: String
    let accentColor: Color
    let plan: QuickWorkoutPlan
}

extension SportPrehab {
    static let all: [SportPrehab] = [
        SportPrehab(id: "running", icon: "🏃", sport: "Běhání", riskArea: "Koleno + kotník + hýždě",
                    accentColor: Color(red: 0.18, green: 0.82, blue: 0.48),
                    plan: QuickWorkoutPlan(
                        label: "Prehab pro běžce", icon: "🏃",
                        accentColor: Color(red: 0.18, green: 0.82, blue: 0.48),
                        exercises: [
                            .init(name: "Single-Leg Glute Bridge", nameEN: "Single Leg Glute Bridge", slug: "single-leg-glute-bridge",
                                  sets: 3, repsMin: 12, repsMax: 15, isBodyweight: true,
                                  coachTip: "Aktivace hýždí = prevence ITB syndromu a běžeckého kolene."),
                            .init(name: "Clamshell s gumou", nameEN: "Clamshell Band", slug: "clamshell-band",
                                  sets: 3, repsMin: 15, repsMax: 20, isBodyweight: false,
                                  coachTip: "Abduktory stabilizují koleno při dopadu."),
                            .init(name: "Tibialis Raises", nameEN: "Tibialis Raise", slug: "tibialis-raise",
                                  sets: 3, repsMin: 15, repsMax: 20, isBodyweight: true,
                                  coachTip: "Zdvihej špičky opřen o zeď. Prevence shin splints."),
                            .init(name: "Copenhagen Plank", nameEN: "Copenhagen Plank", slug: "copenhagen-plank",
                                  sets: 3, repsMin: 1, repsMax: 1, isBodyweight: true,
                                  coachTip: "Addukce kyčle. Drž 30s.", durationSeconds: 30),
                            .init(name: "Eccentric Calf Raise", nameEN: "Eccentric Calf Raise", slug: "eccentric-calf-raise",
                                  sets: 3, repsMin: 12, repsMax: 15, isBodyweight: true,
                                  coachTip: "3 sekundy dolů. Posiluje šlachu Achilles."),
                        ],
                        warmupItems: ["5 min pomalé rozklusání", "Leg swings přední/zadní", "10× glute activation"],
                        coachNote: "Dělej 2× týdně. Slabé hýždě a kotníky jsou příčinou 80% běžeckých zranění.",
                        estimatedMinutes: 30, intensity: .medium
                    )),
        SportPrehab(id: "cycling", icon: "🚴", sport: "Cyklistika", riskArea: "Záda + kyčle + krk",
                    accentColor: Color(red: 0.22, green: 0.55, blue: 1.0),
                    plan: QuickWorkoutPlan(
                        label: "Prehab pro cyklisty", icon: "🚴",
                        accentColor: Color(red: 0.22, green: 0.55, blue: 1.0),
                        exercises: [
                            .init(name: "Hip Flexor Stretch — hluboký výpad", nameEN: "Hip Flexor Stretch", slug: "hip-flexor-stretch",
                                  sets: 3, repsMin: 1, repsMax: 1, isBodyweight: true,
                                  coachTip: "Cyklistika extrémně zkracuje psoas. Drž 45s.", durationSeconds: 45),
                            .init(name: "Thoracic Rotation", nameEN: "Thoracic Rotation", slug: "thoracic-rotation",
                                  sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true,
                                  coachTip: "Čtyřnožka, ruka za hlavou. Kompenzuje flexi na kole."),
                            .init(name: "Band Pull-Apart", nameEN: "Band Pull Apart", slug: "band-pull-apart",
                                  sets: 4, repsMin: 15, repsMax: 20, isBodyweight: false,
                                  coachTip: "Protahuje skrčená ramena. Klíčové po každé jízdě."),
                            .init(name: "Prone Cobra", nameEN: "Prone Cobra", slug: "prone-cobra",
                                  sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true,
                                  coachTip: "Vleže na břiše, zvedni hrudník. Lopatky dolů."),
                        ],
                        warmupItems: ["10× kroužení rameny vzad", "Cat-cow 10× pro páteř", "Thoracic foam roll"],
                        coachNote: "Cyklistická pozice devastuje záda a kyčle. Tyto cviky jsou protiváha k hodinám na sedle.",
                        estimatedMinutes: 25, intensity: .low
                    )),
        SportPrehab(id: "tennis", icon: "🎾", sport: "Tenis / Golf", riskArea: "Loket + rotátory + páteř",
                    accentColor: Color(red: 1.0, green: 0.65, blue: 0.0),
                    plan: QuickWorkoutPlan(
                        label: "Prehab pro tenisty & golfisty", icon: "🎾",
                        accentColor: Color(red: 1.0, green: 0.65, blue: 0.0),
                        exercises: [
                            .init(name: "Forearm Flexor Stretch", nameEN: "Forearm Flexor Stretch", slug: "forearm-stretch",
                                  sets: 3, repsMin: 1, repsMax: 1, isBodyweight: true,
                                  coachTip: "Ruku natáhni, druhá ruka zahne prsty dozadu. Drž 30s. Tenisový loket.", durationSeconds: 30),
                            .init(name: "Wrist Curls + Reverse", nameEN: "Wrist Curl", slug: "wrist-curl",
                                  sets: 3, repsMin: 15, repsMax: 20, isBodyweight: false,
                                  coachTip: "Lehká váha. Flexi + extenze zápěstí."),
                            .init(name: "Thoracic Rotation — golfová", nameEN: "Thoracic Rotation", slug: "thoracic-rotation",
                                  sets: 3, repsMin: 12, repsMax: 15, isBodyweight: true,
                                  coachTip: "Extrémní rotační zátěž. Thoracic mobility = prevence zranění."),
                            .init(name: "Band External Rotation", nameEN: "Band External Rotation", slug: "band-external-rotation",
                                  sets: 3, repsMin: 15, repsMax: 20, isBodyweight: false,
                                  coachTip: "Rotátorová manžeta stabilizuje při každém úderu."),
                            .init(name: "Pallof Press", nameEN: "Pallof Press", slug: "pallof-press",
                                  sets: 3, repsMin: 10, repsMax: 12, isBodyweight: false,
                                  coachTip: "Odolávej rotaci. Sportovní stabilita trupu."),
                        ],
                        warmupItems: ["Kruhové pohyby paží", "Kroužení zápěstími 20×"],
                        coachNote: "Prehab 2× týdně redukuje riziko tenisového lokte o 60–70%.",
                        estimatedMinutes: 25, intensity: .medium
                    )),
        SportPrehab(id: "swimming", icon: "🏊", sport: "Plavání", riskArea: "Rotátory + ramena + záda",
                    accentColor: Color(red: 0.15, green: 0.82, blue: 0.88),
                    plan: QuickWorkoutPlan(
                        label: "Prehab pro plavce", icon: "🏊",
                        accentColor: Color(red: 0.15, green: 0.82, blue: 0.88),
                        exercises: [
                            .init(name: "Sleeper Stretch", nameEN: "Sleeper Stretch", slug: "sleeper-stretch",
                                  sets: 3, repsMin: 1, repsMax: 1, isBodyweight: true,
                                  coachTip: "Na boku, tlač předloktí dolů. Drž 30s.", durationSeconds: 30),
                            .init(name: "YTW Raises", nameEN: "YTW Raise", slug: "ytw-raise",
                                  sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true,
                                  coachTip: "Vleže na břiše. Y, T, W formace pažemi."),
                            .init(name: "Shoulder Rotation Band", nameEN: "Shoulder Rotation Band", slug: "shoulder-rotation",
                                  sets: 3, repsMin: 15, repsMax: 20, isBodyweight: false,
                                  coachTip: "Rotátorová manžeta musí vydržet tisíce opakování."),
                            .init(name: "Scapular Push-Up", nameEN: "Scapular Push Up", slug: "scapular-push-up",
                                  sets: 3, repsMin: 12, repsMax: 15, isBodyweight: true,
                                  coachTip: "Pohyb lopatek bez ohýbání loktů. Stabilizátory."),
                        ],
                        warmupItems: ["Kroužení pažemi vpřed/vzad", "Thoracic extension foam roll"],
                        coachNote: "Plavecká ramena = přetížení interních rotátorů. Buduj zevní rotátory stejně pečlivě jako tempo.",
                        estimatedMinutes: 25, intensity: .medium
                    )),
    ]
}

// MARK: ══════════════════════════════════════════════════════════════════════
// MARK: MODULE 6 — Longevity 50+
// MARK: ══════════════════════════════════════════════════════════════════════

extension QuickWorkoutPlan {
    static let longevityFocus: [QuickWorkoutPlan] = [
        QuickWorkoutPlan(
            label: "Rovnováha & Prevence pádů", icon: "🧍",
            accentColor: Color(red: 0.15, green: 0.82, blue: 0.88),
            exercises: [
                .init(name: "Stoj na jedné noze", nameEN: "Single Leg Stand", slug: "single-leg-balance",
                      sets: 3, repsMin: 1, repsMax: 1, isBodyweight: true,
                      coachTip: "Drž 30s každou nohu. Progresi: zavřené oči. Prediktivní marker.", durationSeconds: 30),
                .init(name: "Tandem Walk — chůze po provaze", nameEN: "Tandem Walk", slug: "tandem-walk",
                      sets: 3, repsMin: 10, repsMax: 15, isBodyweight: true,
                      coachTip: "Pata k špičce, přímá linie. Aktivuje vestibulární systém."),
                .init(name: "Sit-to-Stand bez rukou", nameEN: "Sit To Stand", slug: "sit-to-stand",
                      sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true,
                      coachTip: "Ze židle vstaň bez opory rukou. Funkční test síly i koordinace."),
                .init(name: "Step Down — kontrolovaný sestup", nameEN: "Step Down", slug: "step-down",
                      sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true,
                      coachTip: "Kontrolovaný sestup ze schodku. Prevence pádu ze schodů."),
            ],
            warmupItems: ["Marching na místě 2 min", "Kroužení kotníky a boky"],
            coachNote: "Pád je #1 příčina invalidity u seniorů. Cvičit 3× týdně přináší měřitelné výsledky za 8 týdnů.",
            estimatedMinutes: 25, intensity: .low
        ),
        QuickWorkoutPlan(
            label: "Úchopová síla — Longevity Marker", icon: "✊",
            accentColor: Color(red: 1.0, green: 0.65, blue: 0.0),
            exercises: [
                .init(name: "Farmer's Carry", nameEN: "Farmers Carry", slug: "farmers-carry",
                      sets: 4, repsMin: 1, repsMax: 1, isBodyweight: false,
                      coachTip: "30m chůze s těžkými jednoručkami. Úchopová síla = longevity marker."),
                .init(name: "Dead Hang", nameEN: "Dead Hang", slug: "dead-hang",
                      sets: 3, repsMin: 1, repsMax: 1, isBodyweight: true,
                      coachTip: "Drž co nejdéle. Dekomprese páteře + síla úchopu najednou.", durationSeconds: 30),
                .init(name: "Wrist Roller nebo Hand Gripper", nameEN: "Grip Training", slug: "grip-training",
                      sets: 3, repsMin: 20, repsMax: 30, isBodyweight: false,
                      coachTip: "Kompletní trénink úchopu. Flexe a extenze předloktí."),
                .init(name: "Plate Pinch", nameEN: "Plate Pinch", slug: "plate-pinch",
                      sets: 3, repsMin: 1, repsMax: 1, isBodyweight: false,
                      coachTip: "Drž dva kotouče palcem a prsty 30–45s.", durationSeconds: 35),
            ],
            warmupItems: ["Kroužení zápěstími 20×", "Třeni rukou pro zahřátí"],
            coachNote: "Studie ukazují přímou korelaci úchopové síly s kardiovaskulárním zdravím a délkou života.",
            estimatedMinutes: 20, intensity: .medium
        ),
        QuickWorkoutPlan(
            label: "Vstávání ze země (funkční)", icon: "🌍",
            accentColor: Color(red: 0.18, green: 0.82, blue: 0.48),
            exercises: [
                .init(name: "Turkish Get-Up — lehká váha", nameEN: "Turkish Get Up", slug: "turkish-get-up",
                      sets: 3, repsMin: 3, repsMax: 5, isBodyweight: false,
                      coachTip: "Ze země přes klek na stoj a zpět. Bezpečně a pomalu."),
                .init(name: "Ground to Stand bez rukou", nameEN: "Ground To Stand", slug: "ground-to-stand",
                      sets: 3, repsMin: 5, repsMax: 8, isBodyweight: true,
                      coachTip: "Sedni zkříženýma nohama a vstaň bez opory. Test longevity."),
                .init(name: "Half-Kneeling to Standing", nameEN: "Half Kneeling Stand", slug: "half-kneeling-stand",
                      sets: 3, repsMin: 8, repsMax: 10, isBodyweight: true,
                      coachTip: "Z kleku na jedno koleno → vstát. Aktivuje hýždě a hip flexory."),
            ],
            warmupItems: ["5 min pomalá chůze", "10× bodyweight squat"],
            coachNote: "Lidé kteří nedokáží vstát ze země bez rukou mají 5× vyšší mortalitu v dalších 7 letech.",
            estimatedMinutes: 30, intensity: .medium
        ),
    ]
}

// MARK: ══════════════════════════════════════════════════════════════════════
// MARK: MODULE 7 — Micro-Breaks
// MARK: ══════════════════════════════════════════════════════════════════════

struct MicroBreakExercise: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let duration: String
    let instruction: String
    let benefit: String
}

extension MicroBreakExercise {
    static let deskBreaks: [MicroBreakExercise] = [
        MicroBreakExercise(title: "Hrudní protažení",       icon: "🦢", duration: "45 sek",
                           instruction: "Ruce za hlavu, lokty dozadu. Protáhni hrudník nahoru. Drž 3s, 5×.",
                           benefit: "Kompenzuje hrbení u monitoru."),
        MicroBreakExercise(title: "Pravidlo 20-20-20",      icon: "👁️", duration: "20 sek",
                           instruction: "Každých 20 minut se podívej na bod 6 metrů daleko po dobu 20 sekund.",
                           benefit: "Uvolňuje ciliární sval. Snižuje únavu zraku."),
        MicroBreakExercise(title: "Chin Tuck vsedě",        icon: "🖥️", duration: "30 sek",
                           instruction: "Seď rovně. Zasun bradu dozadu. Drž 3s, uvolni. 10×.",
                           benefit: "Přímá prevence krční páteře."),
        MicroBreakExercise(title: "Hip Flexor Stretch",     icon: "🧘", duration: "60 sek",
                           instruction: "Vykroč vpřed, zadní koleno k zemi. 30s každá strana.",
                           benefit: "Zkrácený psoas = bolesti zad."),
        MicroBreakExercise(title: "Calf Raises vstoje",     icon: "💃", duration: "60 sek",
                           instruction: "U stolu. 20× výpony na špičky. 3 série.",
                           benefit: "Lýtka = druhé srdce. Žilní návrat."),
        MicroBreakExercise(title: "Wrist Circles & Stretch",icon: "🤲", duration: "45 sek",
                           instruction: "Kroužení zápěstí 10× každým směrem. Pak natáhni ruku.",
                           benefit: "Prevence karpálního tunelu."),
        MicroBreakExercise(title: "Shoulder Rolls",         icon: "🌊", duration: "30 sek",
                           instruction: "10× kroužení ramen vzad. Pak paže do T, lopatky k sobě.",
                           benefit: "Uvolňuje protrakci ramen od PC."),
        MicroBreakExercise(title: "Nose Trace Breathing",   icon: "🌬️", duration: "90 sek",
                           instruction: "Zavři oči. Kresli nosem čtverec ve vzduchu. Automaticky zpomaluje dech.",
                           benefit: "Aktivuje PNS, snižuje kortizol."),
    ]
}

// MARK: ══════════════════════════════════════════════════════════════════════
// MARK: MAIN VIEW
// MARK: ══════════════════════════════════════════════════════════════════════

struct QuickWorkoutPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var selectedModule: QuickModule = .muscle
    @State private var workoutDuration: Int = 45
    @State private var isGenerating = false

    @State private var selectedMuscle: MuscleTarget? = nil
    @State private var selectedHealthPlan: QuickWorkoutPlan? = nil
    @State private var selectedCyclePhase: CyclePhase? = nil
    @State private var selectedSport: SportPrehab? = nil
    @State private var selectedLongevity: QuickWorkoutPlan? = nil
    @State private var microBreaksEnabled = false
    @State private var microBreakInterval: Int = 2
    @State private var showMicroBreakSuccess = false

    var readyToGenerate: Bool {
        switch selectedModule {
        case .muscle:     return selectedMuscle != nil
        case .health:     return selectedHealthPlan != nil
        case .femHealth:  return selectedCyclePhase != nil
        case .antiStress: return true
        case .prehab:     return selectedSport != nil
        case .longevity:  return selectedLongevity != nil
        case .microBreak: return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppColors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    moduleTabBar
                    durationBar
                    contentScrollView
                }
                if readyToGenerate || selectedModule == .antiStress {
                    generateButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Rychlý trénink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavřít") { dismiss() }.foregroundStyle(.white.opacity(0.6))
                }
            }
            .onChange(of: selectedModule) { _, _ in clearSelections() }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: ─── Module Tab Bar ──────────────────────────────────────────────

    private var moduleTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(QuickModule.allCases) { module in
                    let isSelected = selectedModule == module
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) { selectedModule = module }
                        HapticManager.shared.playSelection()
                    }) {
                        VStack(spacing: 5) {
                            Image(systemName: module.icon).font(.system(size: 15, weight: .semibold))
                            Text(module.rawValue).font(.system(size: 9, weight: .bold)).lineLimit(1)
                        }
                        .foregroundStyle(isSelected ? module.accent : .white.opacity(0.4))
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(isSelected ? module.accent.opacity(0.14) : Color.white.opacity(0.04))
                                .overlay(RoundedRectangle(cornerRadius: 11)
                                    .stroke(isSelected ? module.accent.opacity(0.45) : .clear, lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(AppColors.secondaryBg)
    }

    // MARK: ─── Duration Bar ───────────────────────────────────────────────

    @ViewBuilder
    private var durationBar: some View {
        if selectedModule != .microBreak && selectedModule != .antiStress {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "clock").font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
                    Text("Délka:").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                }
                .padding(.leading, 14)
                Spacer()
                HStack(spacing: 5) {
                    ForEach([20, 30, 45, 60], id: \.self) { min in
                        Button("\(min) min") {
                            withAnimation(.spring(response: 0.25)) { workoutDuration = min }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(workoutDuration == min ? .white : .white.opacity(0.38))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(workoutDuration == min
                                                    ? selectedModule.accent.opacity(0.2)
                                                    : Color.white.opacity(0.05))
                            .overlay(Capsule().stroke(workoutDuration == min
                                                       ? selectedModule.accent.opacity(0.38)
                                                       : .clear, lineWidth: 1)))
                    }
                }
                .padding(.trailing, 14)
            }
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.02))
        }
    }

    // MARK: ─── Content ───────────────────────────────────────────────────

    private var contentScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                moduleHeaderBanner
                switch selectedModule {
                case .muscle:     muscleContent
                case .health:     healthContent
                case .femHealth:  femHealthContent
                case .antiStress: antiStressContent
                case .prehab:     prehabContent
                case .longevity:  longevityContent
                case .microBreak: microBreakContent
                }
            }
            .padding(.horizontal, 16).padding(.top, 12)
            .padding(.bottom, (readyToGenerate || selectedModule == .antiStress) ? 140 : 40)
        }
    }

    private var moduleHeaderBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: selectedModule.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(selectedModule.accent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(selectedModule.accent.opacity(0.14))
                    .overlay(Circle().stroke(selectedModule.accent.opacity(0.22), lineWidth: 1)))
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedModule.rawValue)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(selectedModule.tagline)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(selectedModule.accent.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(selectedModule.accent.opacity(0.15), lineWidth: 1)))
    }

    // MARK: ─── MODULE 1: Partie ──────────────────────────────────────────

    private var muscleContent: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(MuscleTarget.all) { target in
                MuscleTargetCell(
                    target: target,
                    isSelected: selectedMuscle?.id == target.id,
                    onTap: {
                        withAnimation(.spring(response: 0.28)) {
                            selectedMuscle = (selectedMuscle?.id == target.id) ? nil : target
                        }
                        HapticManager.shared.playMediumClick()
                    }
                )
            }
        }
    }

    // MARK: ─── MODULE 2: Zdraví ──────────────────────────────────────────

    private var healthContent: some View {
        ForEach(QuickWorkoutPlan.healthProblems) { plan in
            expandablePlanCard(plan: plan, isSelected: selectedHealthPlan?.id == plan.id) {
                withAnimation(.spring(response: 0.3)) {
                    selectedHealthPlan = selectedHealthPlan?.id == plan.id ? nil : plan
                }
                HapticManager.shared.playMediumClick()
            }
        }
    }

    // MARK: ─── MODULE 3: Ženské zdraví ──────────────────────────────────

    private var femHealthContent: some View {
        VStack(spacing: 10) {
            Text("Vyber fázi cyklu")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.35))
                .kerning(1.2).textCase(.uppercase).frame(maxWidth: .infinity, alignment: .leading)

            ForEach(CyclePhase.allCases) { phase in
                let isSelected = selectedCyclePhase == phase
                VStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.spring(response: 0.35)) {
                            selectedCyclePhase = isSelected ? nil : phase
                        }
                        HapticManager.shared.playMediumClick()
                    }) {
                        HStack(spacing: 12) {
                            Text(phase.icon).font(.system(size: 22)).frame(width: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(phase.rawValue).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                Text(phase.subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? phase.accentColor : .white.opacity(0.2))
                        }
                        .padding(13)
                    }
                    .buttonStyle(.plain)

                    if isSelected {
                        VStack(alignment: .leading, spacing: 10) {
                            Divider().background(Color.white.opacity(0.07))
                            Text(phase.description)
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(phase.accentColor.opacity(0.07)))
                            HStack(spacing: 8) {
                                intensityBadge(phase.workoutPlan.intensity)
                                Label("\(phase.workoutPlan.estimatedMinutes) min", systemImage: "clock")
                                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                            }
                            ForEach(phase.workoutPlan.exercises) { ex in
                                exerciseRow(ex: ex, accent: phase.accentColor)
                            }
                        }
                        .padding(.horizontal, 13).padding(.bottom, 13)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? phase.accentColor.opacity(0.08) : Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? phase.accentColor.opacity(0.4) : Color.white.opacity(0.07),
                                lineWidth: isSelected ? 1.5 : 1)))
                .animation(.spring(response: 0.28), value: isSelected)
            }
        }
    }

    // MARK: ─── MODULE 4: Anti-Stres ─────────────────────────────────────

    private var antiStressContent: some View {
        let plan = QuickWorkoutPlan.antiStress
        let accent = Color(red: 0.58, green: 0.44, blue: 0.95)
        return VStack(spacing: 14) {
            VStack(spacing: 14) {
                Text("🧠").font(.system(size: 48))
                Text("Dneska toho mám dost")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white).multilineTextAlignment(.center)
                Text("15 minut. Žádný výkon.\nPouze regulace nervové soustavy.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
            }
            .padding(18).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.15, blue: 0.35), Color(red: 0.12, green: 0.1, blue: 0.22)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.3), lineWidth: 1)))

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "brain").foregroundStyle(accent).font(.system(size: 13))
                Text("**Proč to funguje:** Pohyb aktivuje vagus nerv. Pomalé výdechy snižují srdeční frekvenci. Protažení psoas uvolňuje \"sval stresu\". 15 minut = měřitelný pokles kortizolu.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
            }
            .padding(11).background(RoundedRectangle(cornerRadius: 11).fill(accent.opacity(0.07)))

            VStack(alignment: .leading, spacing: 6) {
                Text("Co tě čeká")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.35))
                    .kerning(1.2).textCase(.uppercase)
                ForEach(plan.exercises) { ex in exerciseRow(ex: ex, accent: accent) }
            }
        }
    }

    // MARK: ─── MODULE 5: Prehab ──────────────────────────────────────────

    private var prehabContent: some View {
        ForEach(SportPrehab.all) { sport in
            let isSelected = selectedSport?.id == sport.id
            VStack(spacing: 0) {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) { selectedSport = isSelected ? nil : sport }
                    HapticManager.shared.playMediumClick()
                }) {
                    HStack(spacing: 12) {
                        Text(sport.icon).font(.system(size: 26)).frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sport.sport).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9)).foregroundStyle(sport.accentColor.opacity(0.8))
                                Text("Riziko: \(sport.riskArea)").font(.system(size: 11)).foregroundStyle(sport.accentColor.opacity(0.8))
                            }
                        }
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                            .font(.system(size: isSelected ? 18 : 13))
                            .foregroundStyle(isSelected ? sport.accentColor : .white.opacity(0.28))
                    }
                    .padding(13)
                }
                .buttonStyle(.plain)

                if isSelected {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider().background(Color.white.opacity(0.07))
                        Text(sport.plan.coachNote).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                            .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(sport.accentColor.opacity(0.07)))
                        ForEach(sport.plan.exercises) { ex in exerciseRow(ex: ex, accent: sport.accentColor) }
                    }
                    .padding(.horizontal, 13).padding(.bottom, 13)
                }
            }
            .background(RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? sport.accentColor.opacity(0.08) : Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? sport.accentColor.opacity(0.38) : Color.white.opacity(0.07),
                            lineWidth: isSelected ? 1.5 : 1)))
        }
    }

    // MARK: ─── MODULE 6: Longevity ───────────────────────────────────────

    private var longevityContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("🌿").font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Investice do dalších 30 let").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    Text("Vyber oblast na které chceš pracovat").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.15, green: 0.82, blue: 0.88).opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.15, green: 0.82, blue: 0.88).opacity(0.18), lineWidth: 1)))

            ForEach(QuickWorkoutPlan.longevityFocus) { plan in
                let isSelected = selectedLongevity?.id == plan.id
                VStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) { selectedLongevity = isSelected ? nil : plan }
                        HapticManager.shared.playMediumClick()
                    }) {
                        HStack(spacing: 12) {
                            Text(plan.icon).font(.system(size: 24)).frame(width: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.label).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                Label("\(plan.estimatedMinutes) min · \(plan.exercises.count) cviků", systemImage: "clock")
                                    .font(.system(size: 10)).foregroundStyle(plan.accentColor.opacity(0.75))
                            }
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                                .font(.system(size: isSelected ? 17 : 12))
                                .foregroundStyle(isSelected ? plan.accentColor : .white.opacity(0.28))
                        }
                        .padding(13)
                    }
                    .buttonStyle(.plain)

                    if isSelected {
                        VStack(alignment: .leading, spacing: 8) {
                            Divider().background(Color.white.opacity(0.07))
                            Text(plan.coachNote).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                                .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(plan.accentColor.opacity(0.07)))
                            ForEach(plan.exercises) { ex in exerciseRow(ex: ex, accent: plan.accentColor) }
                        }
                        .padding(.horizontal, 13).padding(.bottom, 13)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? plan.accentColor.opacity(0.08) : Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? plan.accentColor.opacity(0.38) : Color.white.opacity(0.07),
                                lineWidth: isSelected ? 1.5 : 1)))
            }
        }
    }

    // MARK: ─── MODULE 7: Micro-Breaks ────────────────────────────────────

    private var microBreakContent: some View {
        let accent = Color(red: 0.95, green: 0.30, blue: 0.30)
        return VStack(spacing: 14) {
            // Toggle
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill").font(.system(size: 20)).foregroundStyle(accent).frame(width: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Připomínky každé \(microBreakInterval)h").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        Text("Notifikace s cvikem na protažení").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Toggle("", isOn: $microBreaksEnabled).tint(accent)
                        .onChange(of: microBreaksEnabled) { _, on in if on { scheduleMicroBreaks() } else { cancelMicroBreaks() } }
                }
                .padding(13)

                if microBreaksEnabled {
                    Divider().background(Color.white.opacity(0.07))
                    HStack {
                        Text("Interval:").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)).padding(.leading, 13)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach([1, 2, 3], id: \.self) { h in
                                Button("\(h)h") { microBreakInterval = h; scheduleMicroBreaks() }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(microBreakInterval == h ? .white : .white.opacity(0.4))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Capsule().fill(microBreakInterval == h ? accent.opacity(0.22) : Color.white.opacity(0.05)))
                            }
                        }
                        .padding(.trailing, 13)
                    }
                    .padding(.vertical, 8)
                }

                if showMicroBreakSuccess {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Připomínky nastaveny!").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 13).padding(.bottom, 10)
                    .transition(.opacity)
                }
            }
            .background(RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(microBreaksEnabled ? accent.opacity(0.3) : Color.white.opacity(0.07), lineWidth: 1)))

            Text("Kancelářský zásobník")
                .font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.35))
                .kerning(1.2).textCase(.uppercase).frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(MicroBreakExercise.deskBreaks) { ex in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(ex.icon).font(.system(size: 18))
                            Spacer()
                            Text(ex.duration).font(.system(size: 9, weight: .bold))
                                .foregroundStyle(accent.opacity(0.8))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Capsule().fill(accent.opacity(0.1)))
                        }
                        Text(ex.title).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        Text(ex.benefit).font(.system(size: 10)).foregroundStyle(.white.opacity(0.48)).lineLimit(2)
                    }
                    .padding(11).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 11)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.07), lineWidth: 1)))
                }
            }

            // 20-20-20 highlight
            HStack(alignment: .top, spacing: 10) {
                Text("👁️").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pravidlo 20-20-20").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    Text("Každých **20 minut** se podívej na bod vzdálený **20 stop (6m)** po dobu **20 sekund**. Uvolňuje ciliární sval a snižuje únavu zraku od modrého světla.")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(13)
            .background(RoundedRectangle(cornerRadius: 13)
                .fill(accent.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(accent.opacity(0.18), lineWidth: 1)))
        }
    }

    // MARK: ─── Generate Button ───────────────────────────────────────────

    private var generateButton: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, AppColors.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 24).allowsHitTesting(false)

            if let label = ctaLabel {
                HStack(spacing: 8) {
                    Image(systemName: selectedModule.icon).font(.system(size: 12)).foregroundStyle(selectedModule.accent)
                    Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(selectedModule.accent)
                }
                .padding(.horizontal, 16).padding(.vertical, 7)
                .background(selectedModule.accent.opacity(0.07))
            }

            Button(action: generateSelectedWorkout) {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else {
                        Image(systemName: "bolt.fill").font(.system(size: 14))
                    }
                    Text(isGenerating ? "Připravuji..." : "Spustit trénink")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(LinearGradient(colors: [selectedModule.accent, selectedModule.accent.opacity(0.72)],
                                           startPoint: .leading, endPoint: .trailing))
            }
            .disabled(isGenerating).padding(.horizontal, 16).padding(.vertical, 10)
            .background(AppColors.background)
        }
        .animation(.spring(response: 0.3), value: ctaLabel)
    }

    private var ctaLabel: String? {
        switch selectedModule {
        case .muscle:     return selectedMuscle.map { "Partie: \($0.title)" }
        case .health:     return selectedHealthPlan.map { $0.label }
        case .femHealth:  return selectedCyclePhase.map { "Fáze: \($0.rawValue)" }
        case .antiStress: return "15 min · Anti-Stres Reset"
        case .prehab:     return selectedSport.map { $0.sport }
        case .longevity:  return selectedLongevity.map { $0.label }
        case .microBreak: return nil
        }
    }

    // MARK: ─── Shared Sub-Views ──────────────────────────────────────────

    @ViewBuilder
    private func expandablePlanCard(plan: QuickWorkoutPlan, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Text(plan.icon).font(.system(size: 26)).frame(width: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.label).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        HStack(spacing: 8) {
                            Label("\(plan.estimatedMinutes) min", systemImage: "clock")
                            HStack(spacing: 3) {
                                Image(systemName: plan.intensity.icon).font(.system(size: 9))
                                Text(plan.intensity.rawValue)
                            }
                            .foregroundStyle(plan.intensity.color)
                        }
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
                }
                .padding(13)
            }
            .buttonStyle(.plain)

            if isSelected {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().background(Color.white.opacity(0.07))
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill").foregroundStyle(plan.accentColor).font(.system(size: 12))
                        Text(plan.coachNote).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10).background(RoundedRectangle(cornerRadius: 10).fill(plan.accentColor.opacity(0.07)))
                    ForEach(plan.exercises) { ex in exerciseRow(ex: ex, accent: plan.accentColor) }
                }
                .padding(.horizontal, 13).padding(.bottom, 13)
            }
        }
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(isSelected ? plan.accentColor.opacity(0.08) : Color.white.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? plan.accentColor.opacity(0.38) : Color.white.opacity(0.07),
                        lineWidth: isSelected ? 1.5 : 1)))
    }

    @ViewBuilder
    private func exerciseRow(ex: QuickExerciseTemplate, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 2.5, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(ex.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    Group {
                        if let dur = ex.durationSeconds {
                            Text("\(dur)s")
                        } else {
                            Text("\(ex.sets)× \(ex.repsMin)–\(ex.repsMax)")
                        }
                    }
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(accent.opacity(0.8))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(accent.opacity(0.1)))
                }
                Text(ex.coachTip).font(.system(size: 10)).foregroundStyle(.white.opacity(0.45)).lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private func intensityBadge(_ intensity: QuickWorkoutPlan.WorkoutIntensity) -> some View {
        HStack(spacing: 4) {
            Image(systemName: intensity.icon).font(.system(size: 9))
            Text(intensity.rawValue).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(intensity.color)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(intensity.color.opacity(0.1)))
    }

    // MARK: ─── Logic ─────────────────────────────────────────────────────

    private func clearSelections() {
        selectedMuscle = nil; selectedHealthPlan = nil
        selectedCyclePhase = nil; selectedSport = nil; selectedLongevity = nil
    }

    private func generateSelectedWorkout() {
        isGenerating = true
        HapticManager.shared.playMediumClick()
        Task { @MainActor in
            let plan: QuickWorkoutPlan?
            switch selectedModule {
            case .muscle:
                if let m = selectedMuscle { let s = generateMuscleWorkout(target: m); finishGeneration(session: s); return }
                plan = nil
            case .health:     plan = selectedHealthPlan
            case .femHealth:  plan = selectedCyclePhase?.workoutPlan
            case .antiStress: plan = QuickWorkoutPlan.antiStress
            case .prehab:     plan = selectedSport?.plan
            case .longevity:  plan = selectedLongevity
            case .microBreak: plan = nil
            }
            if let p = plan { finishGeneration(session: generatePlanWorkout(plan: p)) }
            else { isGenerating = false }
        }
    }

    private func finishGeneration(session: WorkoutSession) {
        do {
            try modelContext.save()
        } catch {
            AppLogger.error("QuickWorkoutPickerView: Nepodařilo se uložit vygenerovaný trénink: \(error)")
            // Pokračujeme i přes chybu — session je v paměti a trénink lze odcvičit
        }
        NotificationCenter.default.post(name: NSNotification.Name("StartCustomWorkout"), object: session)
        isGenerating = false
        dismiss()
    }

    private func generateMuscleWorkout(target: MuscleTarget) -> WorkoutSession {
        var matched: [Exercise] = []
        for slug in target.exerciseSlugs {
            if let ex = allExercises.first(where: { $0.slug == slug || $0.slug.contains(slug) }),
               !matched.contains(where: { $0.id == ex.id }) { matched.append(ex) }
        }
        if matched.count < 4 {
            let byMuscle = allExercises.filter { ex in
                target.muscleGroups.contains(where: { ex.musclesTarget.contains($0) })
                && !matched.contains(where: { $0.id == ex.id })
            }
            matched.append(contentsOf: byMuscle.prefix(6 - matched.count))
        }
        let maxEx = workoutDuration <= 20 ? 3 : workoutDuration <= 30 ? 4 : workoutDuration <= 45 ? 5 : 6
        return createSession(label: "\(target.icon) \(target.title) — Rychlý trénink",
                             exercises: Array(matched.prefix(maxEx)),
                             sets: workoutDuration <= 20 ? 2 : 3)
    }

    private func generatePlanWorkout(plan: QuickWorkoutPlan) -> WorkoutSession {
        var exercises: [Exercise] = []
        for t in plan.exercises {
            let match = allExercises.first(where: {
                $0.slug == t.slug || $0.nameEN.lowercased() == t.nameEN.lowercased()
                || $0.name.localizedCaseInsensitiveContains(t.name.components(separatedBy: " — ").first ?? t.name)
            })
            if let ex = match {
                exercises.append(ex)
            } else {
                let ep = Exercise(slug: t.slug, name: t.name, nameEN: t.nameEN, category: .core, movementPattern: .isolation,
                                   equipment: t.isBodyweight ? [.bodyweight] : [.resistanceBand],
                                   musclesTarget: [], musclesSecondary: [], isUnilateral: false, instructions: t.coachTip)
                modelContext.insert(ep); exercises.append(ep)
            }
        }
        return createSession(label: "\(plan.icon) \(plan.label)", exercises: exercises, sets: 3)
    }

    private func createSession(label: String, exercises: [Exercise], sets: Int) -> WorkoutSession {
        let day = PlannedWorkoutDay(dayOfWeek: 99, label: label)
        modelContext.insert(day)
        let session = WorkoutSession(plan: nil, plannedDay: day)
        modelContext.insert(session)
        for (i, ex) in exercises.enumerated() {
            let p = PlannedExercise(order: i, exercise: ex, targetSets: sets, targetRepsMin: 10, targetRepsMax: 15)
            p.plannedDay = day
            _ = SessionExercise(order: i, exercise: ex, session: session)
        }
        return session
    }

    private func scheduleMicroBreaks() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: MicroBreakExercise.deskBreaks.map { "mb_\($0.id)" })
            for (i, ex) in MicroBreakExercise.deskBreaks.shuffled().prefix(8).enumerated() {
                let content = UNMutableNotificationContent()
                content.title = "⏱️ \(ex.duration) pro tvoje tělo"
                content.body = "\(ex.icon) \(ex.title) — \(String(ex.instruction.prefix(70)))"
                content.sound = .default
                var c = DateComponents(); c.hour = 8 + (i * microBreakInterval); c.minute = 0
                let req = UNNotificationRequest(identifier: "mb_\(ex.id)", content: content,
                                                 trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: true))
                center.add(req)
            }
            Task { @MainActor in
                withAnimation { showMicroBreakSuccess = true }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation { showMicroBreakSuccess = false }
            }
        }
    }

    private func cancelMicroBreaks() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: MicroBreakExercise.deskBreaks.map { "mb_\($0.id)" })
    }
}

// MARK: - Subviews

struct MuscleTargetCell: View {
    let target: MuscleTarget
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(target.icon).font(.system(size: 24))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.blue)
                    }
                }
                Text(target.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(target.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(isSelected ? Color.blue.opacity(0.13) : Color.white.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(isSelected ? Color.blue.opacity(0.45) : Color.white.opacity(0.08),
                                    lineWidth: isSelected ? 1.5 : 1)
                    )
            )
            .shadow(color: isSelected ? Color.blue.opacity(0.18) : .clear, radius: 6)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28), value: isSelected)
    }
}
