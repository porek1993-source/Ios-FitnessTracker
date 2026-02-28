// DetailedBodyFigureView.swift
// Nová prémiová anatomická mapa založená na SVG modelech.

import SwiftUI

struct DetailedBodyFigureView: View {
    let muscleStates: [MuscleGroup: Double] // 0.0 až 1.0 (intenzita barvy)
    let isFront: Bool
    var highlightColor: Color = AppColors.primaryAccent
    var onTapMuscle: ((MuscleGroup) -> Void)? = nil
    
    // Základní barvy
    private let baseFill = Color(white: 0.15)
    
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
                                    .stroke(Color.black.opacity(0.8), lineWidth: 1.5)
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
            .path(in: rect)
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
        let commandChars = "MLHVZCQSamlhvzcqs"
        
        var commands: [String] = []
        var currentCmd = ""
        
        for char in svgPath {
            if commandChars.contains(char) {
                if !currentCmd.isEmpty { commands.append(currentCmd) }
                currentCmd = String(char)
            } else {
                currentCmd.append(char)
            }
        }
        if !currentCmd.isEmpty { commands.append(currentCmd) }
        
        var currentPoint = CGPoint.zero
        
        for cmdStr in commands {
            guard let firstChar = cmdStr.first else { continue }
            let type = String(firstChar)
            
            // Extract numbers keeping minus signs
            let numStr = cmdStr.dropFirst()
                .replacingOccurrences(of: "-", with: " -")
                .replacingOccurrences(of: ",", with: " ")
            let coords = numStr.split(separator: " ").compactMap { Double($0) }
            
            switch type {
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
                if coords.count >= 2 { 
                    currentPoint = CGPoint(x: coords[0], y: coords[1])
                    self.addLine(to: currentPoint) 
                }
            case "l":
                if coords.count >= 2 { 
                    currentPoint = CGPoint(x: currentPoint.x + coords[0], y: currentPoint.y + coords[1])
                    self.addLine(to: currentPoint) 
                }
            case "H":
                if coords.count >= 1 {
                    currentPoint = CGPoint(x: coords[0], y: currentPoint.y)
                    self.addLine(to: currentPoint)
                }
            case "h":
                if coords.count >= 1 {
                    currentPoint = CGPoint(x: currentPoint.x + coords[0], y: currentPoint.y)
                    self.addLine(to: currentPoint)
                }
            case "V":
                if coords.count >= 1 {
                    currentPoint = CGPoint(x: currentPoint.x, y: coords[0])
                    self.addLine(to: currentPoint)
                }
            case "v":
                if coords.count >= 1 {
                    currentPoint = CGPoint(x: currentPoint.x, y: currentPoint.y + coords[0])
                    self.addLine(to: currentPoint)
                }
            case "C":
                if coords.count >= 6 {
                    let cp1 = CGPoint(x: coords[0], y: coords[1])
                    let cp2 = CGPoint(x: coords[2], y: coords[3])
                    currentPoint = CGPoint(x: coords[4], y: coords[5])
                    self.addCurve(to: currentPoint, controlPoint1: cp1, controlPoint2: cp2)
                }
            case "c":
                if coords.count >= 6 {
                    let cp1 = CGPoint(x: currentPoint.x + coords[0], y: currentPoint.y + coords[1])
                    let cp2 = CGPoint(x: currentPoint.x + coords[2], y: currentPoint.y + coords[3])
                    currentPoint = CGPoint(x: currentPoint.x + coords[4], y: currentPoint.y + coords[5])
                    self.addCurve(to: currentPoint, controlPoint1: cp1, controlPoint2: cp2)
                }
            case "Z", "z":
                self.close()
            default:
                break
            }
        }
    }
}
