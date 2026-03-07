// QuickWorkoutModels.swift
// Definice modelů a dat pro Rychlý trénink

import SwiftUI
import Foundation

// MARK: - Enums

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

// MARK: - Core Templates

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

// MARK: - Module Specific Types

struct MuscleTarget: Identifiable, Hashable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let muscleGroups: [MuscleGroup]
    let exerciseSlugs: [String]
}

struct SportPrehab: Identifiable {
    let id: String
    let icon: String
    let sport: String
    let riskArea: String
    let accentColor: Color
    let plan: QuickWorkoutPlan
}

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
                label: "Menstruační Reset", icon: "🌊", accentColor: accentColor,
                exercises: [
                    .init(name: "Bránicové dýchání", nameEN: "Diaphragmatic Breathing", slug: "diaphragmatic-breathing", sets: 3, repsMin: 10, repsMax: 10, isBodyweight: true, coachTip: "Uvolni břicho."),
                    .init(name: "Cat-Cow", nameEN: "Cat Cow", slug: "cat-cow", sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true, coachTip: "Pomalý pohyb."),
                    .init(name: "Child's Pose", nameEN: "Childs Pose", slug: "childs-pose", sets: 1, repsMin: 1, repsMax: 1, isBodyweight: true, coachTip: "Drž 60s.", durationSeconds: 60)
                ],
                warmupItems: ["2 min hluboký dech"], coachNote: "Dnes jen zlehka.", estimatedMinutes: 15, intensity: .low
            )
        case .follicular:
            return QuickWorkoutPlan(
                label: "Folikulární Síla", icon: "🌱", accentColor: accentColor,
                exercises: [
                    .init(name: "Dřepy", nameEN: "Squat", slug: "squat", sets: 3, repsMin: 8, repsMax: 12, isBodyweight: false, coachTip: "Hloubka."),
                    .init(name: "Kliky", nameEN: "Push Up", slug: "push-up", sets: 3, repsMin: 10, repsMax: 15, isBodyweight: true, coachTip: "Pevný střed."),
                    .init(name: "Přitahy v předklonu", nameEN: "Bent Over Row", slug: "bent-over-row", sets: 3, repsMin: 10, repsMax: 12, isBodyweight: false, coachTip: "Lopatky k sobě.")
                ],
                warmupItems: ["5 min chůze"], coachNote: "Energie roste, přidej váhu.", estimatedMinutes: 25, intensity: .medium
            )
        case .ovulation:
            return QuickWorkoutPlan(
                label: "Ovulační Peak", icon: "⚡️", accentColor: accentColor,
                exercises: [
                    .init(name: "Mrtvý tah", nameEN: "Deadlift", slug: "deadlift", sets: 3, repsMin: 5, repsMax: 8, isBodyweight: false, coachTip: "Maximální síla."),
                    .init(name: "Angličáky", nameEN: "Burpees", slug: "burpees", sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true, coachTip: "Výbušnost."),
                    .init(name: "Plank", nameEN: "Plank", slug: "plank", sets: 3, repsMin: 1, repsMax: 1, isBodyweight: true, coachTip: "Drž 45s.", durationSeconds: 45)
                ],
                warmupItems: ["Dynamický strečink"], coachNote: "Dnes jsi nejsilnější.", estimatedMinutes: 30, intensity: .high
            )
        case .luteal:
            return QuickWorkoutPlan(
                label: "Luteální Stabilita", icon: "🍂", accentColor: accentColor,
                exercises: [
                    .init(name: "Výpady", nameEN: "Lunge", slug: "lunge", sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true, coachTip: "Rovnováha."),
                    .init(name: "Stahování kladky", nameEN: "Lat Pulldown", slug: "lat-pulldown", sets: 3, repsMin: 12, repsMax: 15, isBodyweight: false, coachTip: "Kontrolovaně."),
                    .init(name: "Bird-Dog", nameEN: "Bird Dog", slug: "bird-dog", sets: 3, repsMin: 10, repsMax: 12, isBodyweight: true, coachTip: "Stabilní boky.")
                ],
                warmupItems: ["Foam rolling"], coachNote: "Slyš své tělo.", estimatedMinutes: 25, intensity: .medium
            )
        case .menopause:
            return QuickWorkoutPlan(
                label: "Longevity & Síla", icon: "🌸", accentColor: accentColor,
                exercises: [
                    .init(name: "Zatížené dřepy", nameEN: "Goblet Squat", slug: "goblet-squat", sets: 3, repsMin: 10, repsMax: 12, isBodyweight: false, coachTip: "Hustota kostí."),
                    .init(name: "Tlaky nad hlavu", nameEN: "Overhead Press", slug: "overhead-press", sets: 3, repsMin: 10, repsMax: 12, isBodyweight: false, coachTip: "Silná ramena."),
                    .init(name: "Farmer's Carry", nameEN: "Farmers Carry", slug: "farmers-carry", sets: 3, repsMin: 1, repsMax: 1, isBodyweight: false, coachTip: "Úchop.")
                ],
                warmupItems: ["Mobilita kloubů"], coachNote: "Fokus na kosti.", estimatedMinutes: 30, intensity: .medium
            )
        }
    }
}

struct MicroBreakExercise: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let durationSeconds: Int
    let instruction: String
    let benefit: String
    
    var duration: String {
        return "\(durationSeconds) sek"
    }
}

// MARK: - Static Data Extensions

extension MuscleTarget {
    static let all: [MuscleTarget] = [
        MuscleTarget(id: "chest",     icon: "💪", title: "Hrudník",       subtitle: "Bench, kliky, kladky",
                     muscleGroups: [.chest, .frontShoulders, .triceps],
                     exerciseSlugs: ["bench-press","dumbbell-bench-press","incline-bench-press","cable-fly","push-up","dips"]),
        MuscleTarget(id: "back",      icon: "🪽", title: "Záda",          subtitle: "Lats, střed, spodní záda",
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

extension MicroBreakExercise {
    static let deskBreaks: [MicroBreakExercise] = [
        MicroBreakExercise(title: "Hrudní protažení",       icon: "🦢", durationSeconds: 45,
                           instruction: "Ruce za hlavu, lokty dozadu. Protáhni hrudník nahoru. Drž 3s, 5×.",
                           benefit: "Kompenzuje hrbení u monitoru."),
        MicroBreakExercise(title: "Pravidlo 20-20-20",      icon: "👁️", durationSeconds: 20,
                           instruction: "Každých 20 minut se podívej na bod 6 metrů daleko po dobu 20 sekund.",
                           benefit: "Uvolňuje ciliární sval. Snižuje únavu zraku."),
        MicroBreakExercise(title: "Chin Tuck vsedě",        icon: "🖥️", durationSeconds: 30,
                           instruction: "Seď rovně. Zasun bradu dozadu. Drž 3s, uvolni. 10×.",
                           benefit: "Přímá prevence krční páteře."),
        MicroBreakExercise(title: "Hip Flexor Stretch",     icon: "🧘", durationSeconds: 60,
                           instruction: "Vykroč vpřed, zadní koleno k zemi. 30s každá strana.",
                           benefit: "Zkrácený psoas = bolesti zad."),
        MicroBreakExercise(title: "Calf Raises vstoje",     icon: "💃", durationSeconds: 60,
                           instruction: "U stolu. 20× výpony na špičky. 3 série.",
                           benefit: "Lýtka = druhé srdce. Žilní návrat."),
        MicroBreakExercise(title: "Wrist Circles & Stretch",icon: "🤲", durationSeconds: 45,
                           instruction: "Kroužení zápěstí 10× každým směrem. Pak natáhni ruku.",
                           benefit: "Prevence karpálního tunelu."),
        MicroBreakExercise(title: "Shoulder Rolls",         icon: "🌊", durationSeconds: 30,
                           instruction: "10× kroužení ramen vzad. Pak paže do T, lopatky k sobě.",
                           benefit: "Uvolňuje protrakci ramen od PC."),
        MicroBreakExercise(title: "Nose Trace Breathing",   icon: "🌬️", durationSeconds: 90,
                           instruction: "Zavři oči. Kresli nosem čtverec ve vzduchu. Automaticky zpomaluje dech.",
                           benefit: "Aktivuje PNS, snižuje kortizol."),
    ]
}
