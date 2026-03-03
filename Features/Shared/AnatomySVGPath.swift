// AnatomySVGPath.swift
// Definice anatomických SVG cest ze sady human-anatomy-main.

import Foundation

struct AnatomySVGPart {
    let path: String
    let viewBox: CGRect
    let offset: CGPoint
    let size: CGSize
    let muscleGroups: [MuscleGroup]
}

/// Sdružení SVG cest pro jednotlivé části těla.
/// Originální rozložení a offsety pocházejí z adult.css.
enum AnatomySVGPath {
    
    // MARK: - Hlava a krk (Head & Neck)
    static let head = AnatomySVGPart(
        path: "M12.6756 53L11.663 110.643L0 109.49L3 142L18.663 148L30.6756 198L62.6756 250H120.676L156.676 198L164.676 143L178.676 132L180.676 103L169.676 104L168.676 49.0808C168.676 49.0808 125.105 -0.230752 88.6756 0.999954C52.7339 2.21418 12.6756 53 12.6756 53Z",
        viewBox: CGRect(x: 0, y: 0, width: 181, height: 250),
        offset: CGPoint(x: -27, y: -6),
        size: CGSize(width: 80.3, height: 100),
        muscleGroups: []
    )
    
    static let neck = AnatomySVGPart(
        path: "M10.2703 0L52.2973 53.9L76 126L28.7568 111.3L0 27.3L10.2703 0Z M142 0L149 16L126 98L82 126L96 56L142 0Z",
        viewBox: CGRect(x: 0, y: 0, width: 149, height: 126),
        offset: CGPoint(x: -21, y: 70),
        size: CGSize(width: 70, height: 80),
        muscleGroups: [.traps]
    )
    
    // MARK: - Trup (Torso)
    static let chest = AnatomySVGPart(
        path: "M53 0L114 13L132 121L71 165L23 148V97L0 70L35 55L53 0Z M221 0L252 50.2069H289L277 76V128L227 162L160.407 116L166.407 10.2069L221 0Z",
        viewBox: CGRect(x: 0, y: 0, width: 289, height: 165),
        offset: CGPoint(x: -57, y: 140),
        size: CGSize(width: 150, height: 80),
        muscleGroups: [.chest]
    )
    
    static let abdomen = AnatomySVGPart(
        path: "M129 11L128 54L77 85V41L129 11Z M128 73V127L76 136V105L128 73Z M127 139L126 217L81 194V153L127 139Z M126 237V317L141 417L83 339V221L126 237Z M167 232V312L152 412L210 334V216L167 232Z M159 11L221 31V75L161 50L159 11Z M164 67L216 96L220 137L164 123V67Z M212 153L217 197L165 210V142L212 153Z M57 27L21 63L1 7L57 27Z M55 38L58 84L24 70L55 38Z M61 96L67.5 154L30 126L23 78L61 96Z M67 161V215L30 191L32 134L67 161Z M59 227L69 281V386L43 388L0 320L18 252L21 208L59 227Z M235 20L271 56L291 0L235 20Z M236 31L233 77L267 63L236 31Z M233.5 89L227 147L264.5 119L271.5 71L233.5 89Z M228 153V207L265 183L263 126L228 153Z M234 217L224 271V376L250 378L293 310L275 242L272 198L234 217Z",
        viewBox: CGRect(x: 0, y: 0, width: 293, height: 420),
        offset: CGPoint(x: -70, y: 210),
        size: CGSize(width: 180, height: 230),
        muscleGroups: [.abdominals, .obliques]
    )
    
    // MARK: - Ramena a paže (Shoulders & Arms)
    static let rightShoulder = AnatomySVGPart(
        path: "M135 0L154 52H105L73 36L135 0Z M35 51H53.916L0 151.214V107L35 51Z M58.916 55.2145H99.916L74.916 142.214L35.916 165.214L4.91602 217.214V155.214L58.916 55.2145Z",
        viewBox: CGRect(x: 0, y: 0, width: 154, height: 218),
        offset: CGPoint(x: -90, y: 100),
        size: CGSize(width: 75, height: 110),
        muscleGroups: [.frontShoulders, .rearShoulders]
    )
    
    static let leftShoulder = AnatomySVGPart(
        path: "M87 65L185 141L193 210L163 173L113 155L53 101L87 65Z M111 48L179 106L191 141L93 57L111 48Z M11 0L95 50L63 64L0 50L11 0Z",
        viewBox: CGRect(x: 0, y: 0, width: 193, height: 210),
        offset: CGPoint(x: 48, y: 95),
        size: CGSize(width: 100, height: 110),
        muscleGroups: [.frontShoulders, .rearShoulders]
    )
    
    static let rightArm = AnatomySVGPart(
        path: "M193 0L223 42L183 167L104 200V181L160 48L193 0Z M144 14L98 191L110 69L144 14Z M181 175L172 203L106 242V212L181 175Z M90 210L100 256L18 432L0 422L36 302L90 210Z M163 234L149 295L48 445L25 439L114 253L163 234Z",
        viewBox: CGRect(x: 0, y: 0, width: 223, height: 445),
        offset: CGPoint(x: -162, y: 210),
        size: CGSize(width: 100, height: 190),
        muscleGroups: [.biceps, .triceps, .forearms]
    )
    
    static let leftArm = AnatomySVGPart(
        path: "M30 0L0 42L40 167L119 200V181L63 48L30 0Z M78 35L126 173L113 63L78 35Z M41 178L50 206L116 245V215L41 178Z M122 206V261L190 422L206 414L176 298L122 206Z M54 225L68 286L154 438L180 426L104 250L54 225Z",
        viewBox: CGRect(x: 0, y: 0, width: 206, height: 438),
        offset: CGPoint(x: 100, y: 202),
        size: CGSize(width: 100, height: 190),
        muscleGroups: [.biceps, .triceps, .forearms]
    )
    
    // MARK: - Ruce (Hands)
    static let rightHand = AnatomySVGPart(
        path: "M70 0L85 27L123 32C123 32 124.421 62.7655 126 83C128.63 116.709 111 170 111 170H100L107 131L96 126L83 167L70 165L81 119L72 113L55 158L41 157L58 106L49 101L27 151L17 149L41 66L37 53L6 73L0 66L27 27L70 0Z",
        viewBox: CGRect(x: 0, y: 0, width: 127, height: 170),
        offset: CGPoint(x: -197, y: 387),
        size: CGSize(width: 60, height: 90),
        muscleGroups: [.forearms]
    )
    
    static let leftHand = AnatomySVGPart(
        path: "M56.2675 0L41.2675 27L2.26746 36C2.26746 36 1.84616 62.7655 0.267456 83C-2.36253 116.709 15.2675 170 15.2675 170H26.2675L19.2675 131L30.2675 126L43.2675 167L56.2675 165L45.2675 119L54.2675 113L71.2675 158L85.2675 157L68.2675 106L77.2675 101L99.2675 151L109.267 149L85.2675 66L89.2675 53L120.267 73L126.267 66L99.2675 27L56.2675 0Z",
        viewBox: CGRect(x: 0, y: 0, width: 127, height: 170),
        offset: CGPoint(x: 172, y: 336),
        size: CGSize(width: 60, height: 170),
        muscleGroups: [.forearms]
    )
    
    // MARK: - Nohy (Legs)
    static let rightLeg = AnatomySVGPart(
        path: "M23.0673 0L33 97.5L0 299.5V162L23.0673 0Z M38 3.5L151 176V252L117 164L41 85.5L38 3.5Z M40 100.5L95 190L121 290.5L107 384L52 290.5L30 176.5L40 100.5Z M117.5 212.5L150 276.5L131 396.5L114.5 384.5L131 271.5L117.5 212.5Z M29.0001 191.5V291.5L91.0001 366L69.0001 396L16.5315 291.5L29.0001 191.5Z M61 17.5L139 68L115 98L61 17.5Z M144 71L162 96.0333L159 163L119 104.033L144 71Z M16.0001 346L40.8465 446L27.0001 436L16 496L16.0001 346Z M50 408H84L95 424L74 490H56V448L43 432L50 408Z M115 413V471L85 567L75 509L115 413Z M29.7076 449L62.7076 521L57.7076 667L75.7076 751H57.7076L13 587L29.7076 449Z M110 506L129 562L121 626L102.5 662L89 756L87 662V592L110 506Z",
        viewBox: CGRect(x: 0, y: 0, width: 162, height: 756),
        offset: CGPoint(x: -110, y: 420),
        size: CGSize(width: 162, height: 350),
        muscleGroups: [.quads, .hamstrings, .calves]
    )
    
    static let leftLeg = AnatomySVGPart(
        path: "M132.933 0L123 97.5L146 302L156 172L132.933 0Z M114 24L11 208L4 304.5L38 216.5L114 112V24Z M114 127L55 210.5L29 311L43 404.5L98 311L120 197L114 127Z M32.5 256L-1.52588e-05 320L19 440L35.5 428L19 315L32.5 256Z M124 218L115 318L70.9999 384L86.9999 410L136.469 318L124 218Z M92 27L26 86.5L52 109.5L92 27Z M22 91L10 111.033L13 178L53 119.033L22 91Z M129.846 360L105 460L118.846 450L129.847 510L129.846 360Z M89 424H55L44 440L65 506H83V464L96 448L89 424Z M23 437V495L57 591L63 533L23 437Z M113 468L80 540L85 686L67 764L85 768L129.708 606L113 468Z M24 519L11 575L19 639L37.5 675L51 769L53 675V605L24 519Z",
        viewBox: CGRect(x: 0, y: 0, width: 156, height: 769),
        offset: CGPoint(x: -10, y: 415),
        size: CGSize(width: 156, height: 350),
        muscleGroups: [.quads, .hamstrings, .calves]
    )
    
    // MARK: - Chodidla (Feet)
    static let rightFoot = AnatomySVGPart(
        path: "M68 0L86 30L80 90H68L64 78L59 90L5 88L0 69L22 22L68 0Z",
        viewBox: CGRect(x: 0, y: 0, width: 86, height: 90),
        offset: CGPoint(x: -70, y: 773),
        size: CGSize(width: 60, height: 50),
        muscleGroups: [.calves]
    )
    
    static let leftFoot = AnatomySVGPart(
        path: "M18 0L0 30L6 90H18L22 78L27 90L81 88L86 69L64 22L18 0Z",
        viewBox: CGRect(x: 0, y: 0, width: 86, height: 90),
        offset: CGPoint(x: 40, y: 771),
        size: CGSize(width: 60, height: 50),
        muscleGroups: [.calves]
    )
    
    // Užitečné seznamy
    static let allFrontParts = [
        head, neck, chest, abdomen,
        rightShoulder, leftShoulder,
        rightArm, leftArm,
        rightHand, leftHand,
        rightLeg, leftLeg,
        rightFoot, leftFoot
    ]
}
