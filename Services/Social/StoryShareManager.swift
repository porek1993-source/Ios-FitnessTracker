// StoryShareManager.swift
// Agilní Fitness Trenér — Generování a Sdílení UIKit / SwiftUI View na IG
//
// Vyžaduje v Info.plist povolené `LSApplicationQueriesSchemes` pro `instagram-stories`

import SwiftUI
import UIKit

@MainActor
public final class StoryShareManager {
    public static let shared = StoryShareManager()

    private init() {}

    /// Renderer pro SwiftUI Views (vyžaduje iOS 16+)
    /// Překreslí konkrétní View do `UIImage` a může to být libovolně velká flexibilní karta.
    @MainActor
    public func captureViewAsImage<V: View>(view: V) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        // Doporučené škálování pro fotky na sociální sítě
        renderer.scale = UIScreen.main.scale
        // Zachování neprůhlednosti pozadí (pokud card nemá explicitní clear bg)
        renderer.isOpaque = false
        
        return renderer.uiImage
    }

    /// Zavolá custom scheme Instagram Stories s předaným obrázkem jako samolepkou/pozadím.
    ///
    /// - Parameters:
    ///   - image: UIImage zachycená z ImageRenderer nebo odkudkoliv jinud.
    ///   - topColor: Horní barva IG background gradientu (hex)
    ///   - bottomColor: Dolní barva IG background gradientu (hex)
    public func shareToInstagramStories(
        image: UIImage,
        topColor: String = "#1A1A1A",
        bottomColor: String = "#05070A"
    ) {
        // Kontrola URL scheme
        guard let url = URL(string: "instagram-stories://share"), UIApplication.shared.canOpenURL(url) else {
            print("❌ Instagram není nainstalovaný nebo chybí 'instagram-stories' parametr v Info.plist (LSApplicationQueriesSchemes)")
            return
        }

        // Zkusíme vytvořit data obrázku
        guard let imageData = image.pngData() else {
            print("❌ Z obrázku nešlo vytěžit PNG")
            return
        }

        // IG Stories Pasteboard Items Dictionary
        // Viz dokumentace Facebook for Developers -> Sharing to Instagram Stories
        let pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.stickerImage": imageData,    // Karta jako pohlcovatelná vizitka/nálepka
            "com.instagram.sharedSticker.backgroundTopColor": topColor,
            "com.instagram.sharedSticker.backgroundBottomColor": bottomColor
        ]

        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5) // Expirace clipboardu za 5 minut
        ]

        UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)

        // Odskok do IG
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            // Backup: Standardní iOS Share Sheet pokud IG chybí
            shareGeneric(image: image)
        }
    }

    private func shareGeneric(image: UIImage) {
        let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            // iPad support
            if let popover = vc.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(vc, animated: true)
        }
    }
}
