// HapticManager.swift
import Foundation
import UIKit

final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    /// Vhodné pro odškrtnutí série (uspokojivé, docela těžké kliknutí)
    func playHeavyClick() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Vhodné pro běžné akce (kliknutí na tlačítko, sval na heatmapě atd.)
    func playMediumClick() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Notifikace úspěchu (např. uložení celého tréninku)
    func playSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// Notifikace varování (např. pokus o přeskočení nedokončeného cviku)
    func playWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    /// Notifikace chyby (výpadek spojení, chyba uložení)
    func playError() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    /// Obecná selekce (lehké kliknutí po scrollování v pickerui)
    func playSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
