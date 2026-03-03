// AudioCoachManager.swift
// Agilní Fitness Trenér — Hlasový trenér s přirozeným projevem a Duckingem hudby
//
// Capabilities: AVAudioSession (duckOthers) zajišťuje ztlumení okolní hudby (např. ze Spotify)
// během mluvení trenéra.

import AVFoundation
import Combine

@MainActor
public final class AudioCoachManager: NSObject, ObservableObject {
    public static let shared = AudioCoachManager()

    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()
    private var audioSession: AVAudioSession { .sharedInstance() }

    // Preferovaná česká Siri (pokud je stažená), nebo základní český hlas "Zuzana"
    private lazy var czechVoice: AVSpeechSynthesisVoice? = {
        AVSpeechSynthesisVoice(language: "cs-CZ") ?? AVSpeechSynthesisVoice(language: "cs")
    }()

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Konfigurace a Oprávnění

    /// Zapne Audio Coach a nastaví AVAudioSession pro Ducking (ztlumení okolní hudby)
    public func enable() {
        guard !isEnabled else { return }
        do {
            // .duckOthers: ztlumí Spotify/Apple Music, když appka přehrává zvuk (mluvení)
            // .mixWithOthers: nesekne přehrávání ostatních aplikací úplně
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .mixWithOthers, .allowBluetooth]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            isEnabled = true
        } catch {
            AppLogger.error("[AudioCoachManager] Selhalo nastavení AVAudioSession: \(error)")
        }
    }

    /// Vypne Audio Coach a vrátí audio session do původního stavu
    public func disable() {
        guard isEnabled else { return }
        stopSpeaking()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            AppLogger.error("[AudioCoachManager] Selhala deaktivace session: \(error)")
        }
        isEnabled = false
    }

    public func toggle() {
        isEnabled ? disable() : enable()
    }

    // MARK: - Předpřipravené hlášky (Česky)

    /// Upozorní uživatele na konec pauzy a nadcházející cvik s cílovou váhou.
    public func announceNextExercise(exerciseName: String, targetWeight: Double?) {
        guard isEnabled else { return }
        
        var msg = "Pauza skončila, další cvik je \(exerciseName)."
        if let target = targetWeight, target > 0 {
            // Konec s nulami (např 100.0 -> 100) pro lidštinu
            let weightStr = target.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", target) : String(format: "%.1f", target)
            msg += " Tvůj cíl je \(weightStr) kilogramů."
        } else {
            msg += " Jdeme zamakat!"
        }
        
        speak(message: msg, isAction: true)
    }

    /// Povzbuzení / pochvala po sérii
    public func announcePraise() {
        let phrases = [
            "Skvělá série, výborná práce.",
            "Takhle se buduje síla.",
            "Výborně! Nenech svaly odpočinout.",
            "Hezká čistá práce.",
            "Perfektní tempo, drž to tak dál."
        ]
        speak(message: phrases.randomElement() ?? "Skvělá série!", isAction: false)
    }

    /// Obecná dynamická hláška
    public func announce(message: String) {
        speak(message: message, isAction: false)
    }

    // MARK: - Syntéza řeči (Přirozený ne-robotický hlas)

    private func speak(message: String, isAction: Bool) {
        guard isEnabled else { return }

        // Pokud už nějaká důležitá hláška hraje a my posíláme akci, přerušíme stávající
        if isAction, synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = czechVoice
        
        // Zamezení "robotického" tónu:
        // 1. Zvýšíme lehce `pitchMultiplier`, aby hlas nezněl monotónně a znuděně (0.5 do 2.0).
        // 2. Přidáme malou odmlku po větě (`postUtteranceDelay`).
        // 3. Upravíme rychlost `rate`, střední hodnota je kolem 0.5. Kolem 0.50-0.52 to zní svižně a lidsky u tréninku.
        
        utterance.pitchMultiplier = 1.05
        utterance.rate = 0.51
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.1

        DispatchQueue.main.async { [weak self] in
            self?.synthesizer.speak(utterance)
        }
    }

    public func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension AudioCoachManager: AVSpeechSynthesizerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
