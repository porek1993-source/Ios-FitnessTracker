// MuscleArea.swift
// Definice tapovatelných svalových struktur.

import Foundation

struct MuscleArea: Identifiable {
    let id: String
    let slug: String
    let displayName: String
    let isFrontSide: Bool
    let relX, relY, relW, relH: Double
    var cornerRadius: CGFloat = 8

    func relativeRect(in size: CGSize) -> CGRect {
        CGRect(
            x: relX * size.width  - (relW * size.width  / 2),
            y: relY * size.height - (relH * size.height / 2),
            width:  relW * size.width,
            height: relH * size.height
        )
    }

    static let frontAreas: [MuscleArea] = [
        // Hrudník
        .init(id: "chest",           slug: "chest",           displayName: "Hrudník",            isFrontSide: true,  relX: 0.50, relY: 0.22, relW: 0.36, relH: 0.10),
        // Přední ramena
        .init(id: "l_front_shoulder",slug: "front-shoulders", displayName: "L. přední rameno",   isFrontSide: true,  relX: 0.22, relY: 0.15, relW: 0.12, relH: 0.08, cornerRadius: 16),
        .init(id: "r_front_shoulder",slug: "front-shoulders", displayName: "P. přední rameno",   isFrontSide: true,  relX: 0.78, relY: 0.15, relW: 0.12, relH: 0.08, cornerRadius: 16),
        // Bicepsy
        .init(id: "left_bicep",      slug: "biceps",          displayName: "Levý biceps",         isFrontSide: true,  relX: 0.18, relY: 0.24, relW: 0.09, relH: 0.14, cornerRadius: 10),
        .init(id: "right_bicep",     slug: "biceps",          displayName: "Pravý biceps",        isFrontSide: true,  relX: 0.82, relY: 0.24, relW: 0.09, relH: 0.14, cornerRadius: 10),
        // Předloktí
        .init(id: "left_forearm",    slug: "forearms",        displayName: "Levé předloktí",      isFrontSide: true,  relX: 0.18, relY: 0.415, relW: 0.07, relH: 0.13, cornerRadius: 8),
        .init(id: "right_forearm",   slug: "forearms",        displayName: "Pravé předloktí",     isFrontSide: true,  relX: 0.82, relY: 0.415, relW: 0.07, relH: 0.13, cornerRadius: 8),
        // Šikmé svaly břišní
        .init(id: "left_oblique",    slug: "obliques",        displayName: "Levé šikmé svaly",   isFrontSide: true,  relX: 0.35, relY: 0.36, relW: 0.06, relH: 0.10, cornerRadius: 8),
        .init(id: "right_oblique",   slug: "obliques",        displayName: "Pravé šikmé svaly",  isFrontSide: true,  relX: 0.65, relY: 0.36, relW: 0.06, relH: 0.10, cornerRadius: 8),
        // Břicho
        .init(id: "abs",             slug: "abdominals",      displayName: "Břicho",              isFrontSide: true,  relX: 0.50, relY: 0.35, relW: 0.24, relH: 0.12),
        // Přední stehna
        .init(id: "left_quad",       slug: "quads",           displayName: "Levý kvadriceps",     isFrontSide: true,  relX: 0.36, relY: 0.57, relW: 0.12, relH: 0.20, cornerRadius: 12),
        .init(id: "right_quad",      slug: "quads",           displayName: "Pravý kvadriceps",    isFrontSide: true,  relX: 0.64, relY: 0.57, relW: 0.12, relH: 0.20, cornerRadius: 12),
        // Lýtka (přední)
        .init(id: "left_calf_f",     slug: "calves",          displayName: "Levé lýtko",          isFrontSide: true,  relX: 0.36, relY: 0.79, relW: 0.10, relH: 0.16, cornerRadius: 10),
        .init(id: "right_calf_f",    slug: "calves",          displayName: "Pravé lýtko",         isFrontSide: true,  relX: 0.64, relY: 0.79, relW: 0.10, relH: 0.16, cornerRadius: 10),
    ]

    static let backAreas: [MuscleArea] = [
        // Trapézy (vrchní)
        .init(id: "traps",            slug: "traps",           displayName: "Trapézy",             isFrontSide: false, relX: 0.50, relY: 0.14, relW: 0.30, relH: 0.06),
        // Zadní ramena
        .init(id: "l_rear_shoulder",  slug: "rear-shoulders",  displayName: "L. zadní rameno",    isFrontSide: false, relX: 0.22, relY: 0.15, relW: 0.12, relH: 0.08, cornerRadius: 16),
        .init(id: "r_rear_shoulder",  slug: "rear-shoulders",  displayName: "P. zadní rameno",    isFrontSide: false, relX: 0.78, relY: 0.15, relW: 0.12, relH: 0.08, cornerRadius: 16),
        // Tricepsy
        .init(id: "left_tricep",      slug: "triceps",         displayName: "Levý triceps",        isFrontSide: false, relX: 0.18, relY: 0.24, relW: 0.09, relH: 0.14, cornerRadius: 10),
        .init(id: "right_tricep",     slug: "triceps",         displayName: "Pravý triceps",       isFrontSide: false, relX: 0.82, relY: 0.24, relW: 0.09, relH: 0.14, cornerRadius: 10),
        // Latissimus dorsi (boční záda)
        .init(id: "left_lat",         slug: "lats",            displayName: "Lats (levé záda)",    isFrontSide: false, relX: 0.34, relY: 0.26, relW: 0.12, relH: 0.12, cornerRadius: 8),
        .init(id: "right_lat",        slug: "lats",            displayName: "Lats (pravé záda)",   isFrontSide: false, relX: 0.66, relY: 0.26, relW: 0.12, relH: 0.12, cornerRadius: 8),
        // Střední záda (rhomboid + mid-trap)
        .init(id: "traps_middle",     slug: "traps-middle",    displayName: "Střední záda",        isFrontSide: false, relX: 0.50, relY: 0.26, relW: 0.20, relH: 0.10),
        // Spodní záda
        .init(id: "lower_back",       slug: "lowerback",       displayName: "Spodní záda",         isFrontSide: false, relX: 0.50, relY: 0.36, relW: 0.22, relH: 0.08),
        // Hýždě
        .init(id: "glutes",           slug: "glutes",          displayName: "Hýždě",               isFrontSide: false, relX: 0.50, relY: 0.44, relW: 0.30, relH: 0.08),
        // Zadní stehna
        .init(id: "left_hamstring",   slug: "hamstrings",      displayName: "Levý hamstring",      isFrontSide: false, relX: 0.36, relY: 0.57, relW: 0.12, relH: 0.20, cornerRadius: 12),
        .init(id: "right_hamstring",  slug: "hamstrings",      displayName: "Pravý hamstring",     isFrontSide: false, relX: 0.64, relY: 0.57, relW: 0.12, relH: 0.20, cornerRadius: 12),
        // Lýtka (zadní)
        .init(id: "left_calf_b",      slug: "calves",          displayName: "Levé lýtko",          isFrontSide: false, relX: 0.36, relY: 0.79, relW: 0.10, relH: 0.16, cornerRadius: 10),
        .init(id: "right_calf_b",     slug: "calves",          displayName: "Pravé lýtko",         isFrontSide: false, relX: 0.64, relY: 0.79, relW: 0.10, relH: 0.16, cornerRadius: 10),
    ]

    static let all: [MuscleArea] = frontAreas + backAreas
}
