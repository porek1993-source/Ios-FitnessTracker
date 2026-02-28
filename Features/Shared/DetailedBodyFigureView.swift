// DetailedBodyFigureView.swift
// Nová prémiová anatomická mapa založená na SVG modelech.

import SwiftUI

struct DetailedBodyFigureView: View {
    let muscleStates: [MuscleGroup: Double] // 0.0 až 1.0 (intenzita barvy)
    let isFront: Bool
    var highlightColor: Color = AppColors.primaryAccent
    
    // Základní barvy
    private let baseFill = Color(white: 0.15)
    
    var body: some View {
        if isFront {
            ZStack(alignment: .top) {
                // Iterujeme přes definované části těla z AnatomySVGPath
                ForEach(0..<AnatomySVGPath.allFrontParts.count, id: \.self) { index in
                    let part = AnatomySVGPath.allFrontParts[index]
                    
                    SVGShape(path: part.path, viewBox: part.viewBox)
                        .fill(getColor(for: part.muscleGroups))
                        .frame(width: part.size.width, height: part.size.height)
                        // ZStack(alignment: .top) centruje prvky na X ose horizontálně a zarovná na Y=0.
                        // CSS 'left: 50%; margin-left: X' znamená posunutí levého okraje o X od středu.
                        // Ve SwiftUI offset(x:) posouvá *střed* prvku od *středu* ZStacku.
                        // Střed prvku tedy musí být 'margin-left + width / 2'.
                        .offset(x: part.offset.x + (part.size.width / 2), y: part.offset.y)
                }
            }
            .frame(width: 400, height: 850)
            // Škálování podle okna nebo pevné; originál počítá se scaleEffect
            .scaleEffect(0.4) 
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
            .frame(width: 400, height: 850)
            .scaleEffect(0.4)
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
