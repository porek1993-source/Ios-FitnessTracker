// DetailedBodyFigureView.swift
// Nová prémiová anatomická mapa založená na SVG modelech.

import SwiftUI

struct DetailedBodyFigureView: View {
    let muscleStates: [MuscleGroup: Double] // 0.0 až 1.0 (intenzita barvy)
    let isFront: Bool
    var highlightColor: Color = AppColors.primaryAccent
    var onTapMuscle: ((MuscleGroup) -> Void)? = nil
    
    // Základní barvy
    private let baseFill = Color(white: 0.25)
    
    var body: some View {
        GeometryReader { geo in
            let svgWidth: CGFloat = 400
            let svgHeight: CGFloat = 850
            
            // Proporcionální škálování podle dostupné velikosti
            let scaleX = geo.size.width / svgWidth
            let scaleY = geo.size.height / svgHeight
            let finalScale = min(scaleX, scaleY)
            
            let drawWidth = svgWidth * finalScale
            let drawHeight = svgHeight * finalScale
            
            // Vystředění obsahu v dostupné šířce (nahoře zarovnané)
            let offsetX = (geo.size.width - drawWidth) / 2
            let offsetY = (geo.size.height - drawHeight) / 2
            
            if isFront {
                ZStack(alignment: .top) {
                    // Iterujeme přes definované části těla z AnatomySVGPath
                    ForEach(0..<AnatomySVGPath.allFrontParts.count, id: \.self) { index in
                        let part = AnatomySVGPath.allFrontParts[index]
                        
                        SVGShape(path: part.path, viewBox: part.viewBox)
                            .fill(getColor(for: part.muscleGroups))
                            .overlay(
                                SVGShape(path: part.path, viewBox: part.viewBox)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                            )
                            .frame(width: part.size.width, height: part.size.height)
                            // Offset pro absolutní posun vůči středu v neškálovaném kontextu (X) a vršku (Y)
                            .offset(x: part.offset.x + (part.size.width / 2), y: part.offset.y)
                            // Přidání interakce přímo na SVG křivku (contentShape(svg) zajišťuje, že tap se trefí pouze na vybarvené pixely)
                            .contentShape(SVGShape(path: part.path, viewBox: part.viewBox))
                            .onTapGesture {
                                if let primaryGroup = part.muscleGroups.first {
                                    onTapMuscle?(primaryGroup)
                                }
                            }
                    }
                }
                .frame(width: svgWidth, height: svgHeight)
                // Škálování podle okna z levého horního rohu před posunem
                .scaleEffect(finalScale, anchor: .top)
                .offset(x: offsetX, y: offsetY)
                
            } else {
                // Záloha pro zadní stranu dokud nemáme SVG
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(baseFill)
                        .frame(width: 150, height: 400)
                        .overlay(
                            Text("Záda\n(Připravujeme)")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.3))
                                .font(.caption)
                        )
                }
                .frame(width: svgWidth, height: svgHeight)
                .scaleEffect(finalScale, anchor: .top)
                .offset(x: offsetX, y: offsetY)
            }
        }
    }
    
    /// Získá nejvyšší intenzitu barvy pro pole svalových skupin.
    private func getColor(for groups: [MuscleGroup]) -> Color {
        let maxIntensity = groups.map { muscleStates[$0] ?? 0.0 }.max() ?? 0.0
        if maxIntensity > 0 {
            return highlightColor.opacity(0.4 + (maxIntensity * 0.6))
        }
        return baseFill
    }
}

// MARK: - SVG Shape Component

struct SVGShape: Shape {
    let path: String
    let viewBox: CGRect
    
    func path(in rect: CGRect) -> Path {
        let svgPath = Path(fromSVG: path)
        
        // Škálování z viewBox souřadnic na cílový rect
        let scaleX = rect.width / viewBox.width
        let scaleY = rect.height / viewBox.height
        let scale = min(scaleX, scaleY)
        
        return svgPath
            .applying(CGAffineTransform(scaleX: scale, y: scale))
    }
}

// MARK: - Simple Path Parser (SVG subset)
// SwiftUI Path nemá nativní parse ze stringu v iOS < 17 (v Preview/SwiftData),
// zde je minimalistický parser pro základní Path data.

extension Path {
    init(fromSVG pathString: String) {
        // Implementace pomocí CoreGraphics CGPath
        self.init(UIBezierPath(svgPath: pathString).cgPath)
    }
}

extension UIBezierPath {
    convenience init(svgPath: String) {
        self.init()
        let commandChars = CharacterSet(charactersIn: "MLHVZCQSamlhvzcqs")
        
        // 1. Přidat mezery před příkazy a před mínusy, abychom usnadnili split
        var formattedPath = svgPath
            .replacingOccurrences(of: "-", with: " -")
            .replacingOccurrences(of: ",", with: " ")
        
        // Přidat mezery před znaky příkazů
        for char in "MLHVZCQSamlhvzcqs" {
            formattedPath = formattedPath.replacingOccurrences(of: String(char), with: " \(char) ")
        }
        
        // 2. Tokenizovat string (odstranit prázdné stringy)
        let tokens = formattedPath.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        var currentCmd = ""
        var cmdCoords: [Double] = []
        var commands: [(String, [Double])] = []
        
        for token in tokens {
            if token.count == 1, token.rangeOfCharacter(from: commandChars) != nil {
                // Nový příkaz
                if !currentCmd.isEmpty {
                    commands.append((currentCmd, cmdCoords))
                }
                currentCmd = token
                cmdCoords = []
            } else if let val = Double(token) {
                // Není to striktně nový příkaz, ale číslo k aktuálnímu
                cmdCoords.append(val)
            }
            // (Pokud chybí Command char ale jdou jen čísla, ignorujeme implicitní L/C logiku pro zjednodušení. 
            // Plný SVG parser by pokračoval v aktuálním příkazu).
        }
        if !currentCmd.isEmpty {
            commands.append((currentCmd, cmdCoords))
        }
        
        var currentPoint = CGPoint.zero
        
        for (cmdStr, coords) in commands {
            switch cmdStr {
            case "M":
                if coords.count >= 2 { 
                    currentPoint = CGPoint(x: coords[0], y: coords[1])
                    self.move(to: currentPoint) 
                }
            case "m":
                if coords.count >= 2 { 
                    currentPoint = CGPoint(x: currentPoint.x + coords[0], y: currentPoint.y + coords[1])
                    self.move(to: currentPoint) 
                }
            case "L":
                var i = 0
                while i + 1 < coords.count {
                    currentPoint = CGPoint(x: coords[i], y: coords[i+1])
                    self.addLine(to: currentPoint)
                    i += 2
                }
            case "l":
                var i = 0
                while i + 1 < coords.count {
                    currentPoint = CGPoint(x: currentPoint.x + coords[i], y: currentPoint.y + coords[i+1])
                    self.addLine(to: currentPoint)
                    i += 2
                }
            case "H":
                for x in coords {
                    currentPoint = CGPoint(x: x, y: currentPoint.y)
                    self.addLine(to: currentPoint)
                }
            case "h":
                for x in coords {
                    currentPoint = CGPoint(x: currentPoint.x + x, y: currentPoint.y)
                    self.addLine(to: currentPoint)
                }
            case "V":
                for y in coords {
                    currentPoint = CGPoint(x: currentPoint.x, y: y)
                    self.addLine(to: currentPoint)
                }
            case "v":
                for y in coords {
                    currentPoint = CGPoint(x: currentPoint.x, y: currentPoint.y + y)
                    self.addLine(to: currentPoint)
                }
            case "C":
                var i = 0
                while i + 5 < coords.count {
                    let cp1 = CGPoint(x: coords[i], y: coords[i+1])
                    let cp2 = CGPoint(x: coords[i+2], y: coords[i+3])
                    currentPoint = CGPoint(x: coords[i+4], y: coords[i+5])
                    self.addCurve(to: currentPoint, controlPoint1: cp1, controlPoint2: cp2)
                    i += 6
                }
            case "c":
                var i = 0
                while i + 5 < coords.count {
                    let cp1 = CGPoint(x: currentPoint.x + coords[i], y: currentPoint.y + coords[i+1])
                    let cp2 = CGPoint(x: currentPoint.x + coords[i+2], y: currentPoint.y + coords[i+3])
                    currentPoint = CGPoint(x: currentPoint.x + coords[i+4], y: currentPoint.y + coords[i+5])
                    self.addCurve(to: currentPoint, controlPoint1: cp1, controlPoint2: cp2)
                    i += 6
                }
            case "S":
                // Zjednodušený S příkaz (bez předchozí kontroly zrcadlení, pouze mapováno na C s předchozím CP = aktuální bod pro tento mock)
                // Plné SVG vyžaduje trackování předchozího CP2
                var i = 0
                while i + 3 < coords.count {
                    let cp2 = CGPoint(x: coords[i], y: coords[i+1])
                    let end = CGPoint(x: coords[i+2], y: coords[i+3])
                    self.addCurve(to: end, controlPoint1: currentPoint, controlPoint2: cp2)
                    currentPoint = end
                    i += 4
                }
            case "s":
                var i = 0
                while i + 3 < coords.count {
                    let cp2 = CGPoint(x: currentPoint.x + coords[i], y: currentPoint.y + coords[i+1])
                    let end = CGPoint(x: currentPoint.x + coords[i+2], y: currentPoint.y + coords[i+3])
                    self.addCurve(to: end, controlPoint1: currentPoint, controlPoint2: cp2)
                    currentPoint = end
                    i += 4
                }
            case "Z", "z":
                self.close()
            case "A":
                // SVG absolute arc: rx ry xRotation largeArcFlag sweepFlag x y
                var i = 0
                while i + 6 < coords.count {
                    let end = CGPoint(x: coords[i+5], y: coords[i+6])
                    // Přiblížení arku kubickou Bezierovou křivkou
                    let cp1 = CGPoint(x: (currentPoint.x + end.x) / 2, y: currentPoint.y)
                    let cp2 = CGPoint(x: (currentPoint.x + end.x) / 2, y: end.y)
                    self.addCurve(to: end, controlPoint1: cp1, controlPoint2: cp2)
                    currentPoint = end
                    i += 7
                }
            case "a":
                // SVG relative arc: rx ry xRotation largeArcFlag sweepFlag dx dy
                var i = 0
                while i + 6 < coords.count {
                    let end = CGPoint(x: currentPoint.x + coords[i+5], y: currentPoint.y + coords[i+6])
                    let cp1 = CGPoint(x: (currentPoint.x + end.x) / 2, y: currentPoint.y)
                    let cp2 = CGPoint(x: (currentPoint.x + end.x) / 2, y: end.y)
                    self.addCurve(to: end, controlPoint1: cp1, controlPoint2: cp2)
                    currentPoint = end
                    i += 7
                }
            case "Q":
                // SVG absolute quadratic bezier: cpx cpy x y
                var i = 0
                while i + 3 < coords.count {
                    let cp = CGPoint(x: coords[i], y: coords[i+1])
                    let end = CGPoint(x: coords[i+2], y: coords[i+3])
                    self.addQuadCurve(to: end, controlPoint: cp)
                    currentPoint = end
                    i += 4
                }
            case "q":
                // SVG relative quadratic bezier: dcpx dcpy dx dy
                var i = 0
                while i + 3 < coords.count {
                    let cp = CGPoint(x: currentPoint.x + coords[i], y: currentPoint.y + coords[i+1])
                    let end = CGPoint(x: currentPoint.x + coords[i+2], y: currentPoint.y + coords[i+3])
                    self.addQuadCurve(to: end, controlPoint: cp)
                    currentPoint = end
                    i += 4
                }
            case "T":
                // SVG absolute smooth quadratic bezier: x y (CP je zrcadlo předchozího)
                var i = 0
                while i + 1 < coords.count {
                    let end = CGPoint(x: coords[i], y: coords[i+1])
                    self.addLine(to: end) // zjednodušení: bez sledování předchozího CP
                    currentPoint = end
                    i += 2
                }
            case "t":
                var i = 0
                while i + 1 < coords.count {
                    let end = CGPoint(x: currentPoint.x + coords[i], y: currentPoint.y + coords[i+1])
                    self.addLine(to: end)
                    currentPoint = end
                    i += 2
                }
            default:
                break
            }
        }
    }
}
