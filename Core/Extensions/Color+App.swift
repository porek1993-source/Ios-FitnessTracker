// Color+App.swift
import SwiftUI

extension Color {
    static var appBackground: Color {
        Color(hue: 0.62, saturation: 0.18, brightness: 0.07)
    }

    static var appSecondaryBackground: Color {
        Color(hue: 0.62, saturation: 0.18, brightness: 0.09)
    }

    static var appTertiaryBackground: Color {
        Color(hue: 0.62, saturation: 0.22, brightness: 0.15)
    }

    static var appCardBackground: Color {
        Color.white.opacity(0.04)
    }

    static var appRowBackground: Color {
        Color.white.opacity(0.05)
    }

    static var appPrimaryAccent: Color {
        Color(red: 0.20, green: 0.52, blue: 1.0)
    }

    static var appSecondaryAccent: Color {
        Color(red: 0.08, green: 0.32, blue: 0.82)
    }

    static var appGreenText: Color {
        Color(red: 0.15, green: 0.82, blue: 0.45)
    }

    static var appGreenBadge: Color {
        Color(red: 0.13, green: 0.80, blue: 0.43)
    }

    static var appRedText: Color {
        Color(red: 0.95, green: 0.30, blue: 0.30)
    }

    static func rpeColor(for value: Int) -> Color {
        switch value {
        case 1...4: return .appGreenText
        case 5...6: return .yellow
        case 7...8: return .orange
        default:    return .appRedText
        }
    }
}
