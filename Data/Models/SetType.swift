// SetType.swift
// Agilní Fitness Trenér — Typy tréninkových sérií

import SwiftUI

enum SetType: String, Codable, CaseIterable {
    case warmup  = "W"
    case normal  = "N"
    case dropset = "D"
    case failure = "F"
    
    var displayName: String {
        switch self {
        case .warmup:  return "Zahřívací"
        case .normal:  return "Pracovní"
        case .dropset: return "Shazovací"
        case .failure: return "Do selhání"
        }
    }
    
    var color: Color {
        switch self {
        case .warmup:  return Color.yellow.opacity(0.8)
        case .normal:  return AppColors.primaryAccent // Nebo modrá
        case .dropset: return Color.orange
        case .failure: return Color.red
        }
    }
    
    // Pro rotaci klikáním v UI
    var next: SetType {
        switch self {
        case .warmup:  return .normal
        case .normal:  return .dropset
        case .dropset: return .failure
        case .failure: return .warmup
        }
    }
}
