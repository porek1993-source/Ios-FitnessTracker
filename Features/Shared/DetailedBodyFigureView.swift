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

// Helper pro parsování SVG stringu
extension UIBezierPath {
    convenience init(svgPath: String) {
        self.init()
        let commands = svgPath.split(whereSeparator: { "MLHVZmlhvz ".contains($0) })
        let types = svgPath.filter { "MLHVZmlhvz".contains($0) }
        
        var typeIndex = 0
        for cmd in commands {
            let coords = cmd.split(separator: " ").compactMap { Double($0) }
            guard typeIndex < types.count else { break }
            let type = types[types.index(types.startIndex, offsetBy: typeIndex)]
            
            switch type {
            case "M", "m":
                if coords.count >= 2 { self.move(to: CGPoint(x: coords[0], y: coords[1])) }
            case "L", "l":
                if coords.count >= 2 { self.addLine(to: CGPoint(x: coords[0], y: coords[1])) }
            case "Z", "z":
                self.close()
            default:
                break
            }
            typeIndex += 1
        }
    }
}
