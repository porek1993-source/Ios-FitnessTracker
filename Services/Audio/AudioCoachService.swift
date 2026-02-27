// AudioCoachService.swift
// Agilní Fitness Trenér — Audio kouč iKorba
//
// Capabilities / Info.plist:
//   Žádné speciální permissions — AVAudioSession je dostupná bez oprávnění.
//   Pro přehrávání na pozadí přidej do Xcode target Capabilities:
//     Background Modes → "Audio, AirPlay, and Picture in Picture"

import AVFoundation
import Combine

// MARK: - Coach Event (co iKorba říká a kdy)

enum CoachSpeech: Equatable {
    // Tempo hlášky
    case tempoPhase(TempoPhase)          // "dolů", "výdrž", "nahoru"
    case tempoBeat(Int)                  // "dva", "tři", ... (číslovky při >1s fázi)
    case repComplete(Int, Int)           // "šest ze deseti"

    // Pauza hlášky
    case restStarted(Int)               // "Pauza, X vteřin."
    case restWarning(Int)               // "Zbývá X vteřin, připrav se."
    case restEnd                        // "Jdeme na to!"

    // Série hlášky
    case setStarting(Int, Int)          // "Série dvě ze čtyř."
    case sessionStart                   // "Posilíme! Tempo tři-jedna-dva-nula."
    case greatSet                       // pochvala (náhodná)
    case prWarning(String)              // "Dneska má jít X kg."

    var utteranceText: String {
        switch self {
        case .tempoPhase(let phase):     return phase.voiceCue
        case .tempoBeat(let n):          return czechNumeral(n)
        case .repComplete(let r, let t): return "Opakování \(czechNumeral(r)) z \(t)."
        case .restStarted(let s):        return "Pauza, \(s) vteřin."
        case .restWarning(let s):        return "Zbývá \(s) vteřin. Připrav se na další sérii."
        case .restEnd:                   return "Jdeme na to!"
        case .setStarting(let s, let t): return "Série \(czechNumeral(s)) ze \(t)."
        case .sessionStart:              return "Posilíme!"
        case .greatSet:                  return CoachSpeech.randomPraise()
        case .prWarning(let name):       return "Na \(name) je dnešní cíl nová váha. Soustřeď se."
        }
    }

    // Rychlost řeči: tempo cues musí být rychlé, jinak posunou timing
    var rate: Float {
        switch self {
        case .tempoPhase, .tempoBeat:   return 0.60   // výrazně pomalé = nespláchnout
        case .repComplete:              return 0.52
        case .restStarted, .restEnd,
             .setStarting, .greatSet,
             .prWarning, .restWarning,
             .sessionStart:             return 0.50
        }
    }

    var volume: Float { 1.0 }

    private func czechNumeral(_ n: Int) -> String {
        let map = [1:"jedna",2:"dva",3:"tři",4:"čtyři",5:"pět",
                   6:"šest",7:"sedm",8:"osm",9:"devět",10:"deset",
                   11:"jedenáct",12:"dvanáct",15:"patnáct",20:"dvacet",30:"třicet"]
        return map[n] ?? "\(n)"
    }

    private static func randomPraise() -> String {
        let phrases = [
            "Výborně! Série odjetá.",
            "Skvělá série, drž tempo!",
            "Tohle byl čistý rep, makej dál.",
            "Přesně takhle. Jsi na správný cestě.",
            "Solidní výkon!",
            "Jedna série za tebou. Jedeš!",
            "Čistá technika. Přesně jak má být.",
            "Tohle je základ síly. Pokračuj.",
            "Makáš správně. Tělo ti poděkuje."
        ]
        return phrases.randomElement() ?? "Dobrá práce!"
    }
}

// MARK: - AudioCoachService

@MainActor
final class AudioCoachService: NSObject, ObservableObject {

    // MARK: Published State
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var currentPhase: TempoPhase? = nil

    // MARK: Private
    private let synthesizer = AVSpeechSynthesizer()
    private var audioSession: AVAudioSession { .sharedInstance() }

    private var tempoTimer: DispatchSourceTimer?
    private var restTimers: [DispatchWorkItem] = []
    private var speechQueue: [CoachSpeech] = []
    private var isSessionActive = false

    // Voice — preferujeme českou Siri
    private lazy var czechVoice: AVSpeechSynthesisVoice? = {
        AVSpeechSynthesisVoice(language: "cs-CZ")
        ?? AVSpeechSynthesisVoice(language: "cs")
    }()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Enable / Disable

    func enable() {
        guard !isEnabled else { return }
        do {
            // .duckOthers: Spotify/Apple Music se ztlumí, kouč promluví, pak se vrátí
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .allowBluetooth, .mixWithOthers]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            isEnabled = true
            isSessionActive = true
        } catch {
            AppLogger.error("AudioCoachService: session setup failed — \(error)")
        }
    }

    func disable() {
        guard isEnabled else { return }
        stopAll()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        isEnabled = false
        isSessionActive = false
    }

    func toggle() {
        isEnabled ? disable() : enable()
    }

    // MARK: - Session Events

    func announceSessionStart() {
        guard isEnabled else { return }
        speak(.sessionStart)
    }

    // MARK: - Tempo Engine

    /// Spustí metronom pro jednu sérii s daným tempem a počtem opakování.
    /// Volej těsně PŘED tím, než uživatel začne série.
    func startTempo(tempoString: String?, reps: Int) {
        stopTempo()
        guard isEnabled, let raw = tempoString, let tempo = TempoParser.parse(raw) else { return }

        let events = TempoParser.buildEventSequence(tempo: tempo)
        let repDuration = TempoParser.repDuration(tempo)
        let queue = DispatchQueue.global(qos: .userInteractive)

        let timer = DispatchSource.makeTimerSource(queue: queue)
        var repIndex = 0

        // Celý cyklus = reps × repDuration sekund
        timer.schedule(deadline: .now(), repeating: .milliseconds(50))

        let startTime = DispatchTime.now()
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000

            // Zjisti aktuální rep a pozici v repu
            let totalElapsed = elapsed
            let currentRep = min(Int(totalElapsed / repDuration), reps - 1)
            let posInRep = totalElapsed.truncatingRemainder(dividingBy: repDuration)

            if currentRep != repIndex {
                repIndex = currentRep
                // Ohlásíme číslo repu mezi repy
                let repNumber = currentRep + 1
                Task { @MainActor [weak self] in
                    self?.speak(.repComplete(repNumber, reps))
                }
            }

            // Najdi event odpovídající pozici
            if let event = events.last(where: { $0.offsetSeconds <= posInRep }) {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if event.isPhaseStart && event.phase != self.currentPhase {
                        self.currentPhase = event.phase
                        self.speak(.tempoPhase(event.phase))
                    } else if !event.isPhaseStart && event.beatIndex > 1 {
                        self.speak(.tempoBeat(event.beatIndex))
                    }
                }
            }

            // Zastav po posledním repu
            if totalElapsed >= Double(reps) * repDuration {
                timer.cancel()
                Task { @MainActor [weak self] in
                    self?.currentPhase = nil
                    self?.tempoTimer = nil
                }
            }
        }

        tempoTimer = timer
        timer.resume()
    }

    func stopTempo() {
        tempoTimer?.cancel()
        tempoTimer = nil
        currentPhase = nil
    }

    // MARK: - Rest Announcements

    /// Zavolej hned po startu pauzy.
    func announceRestStart(seconds: Int) {
        guard isEnabled else { return }
        cancelRestTimers()
        speak(.restStarted(seconds))

        // Varování 10s před koncem
        let warnAt = Double(seconds) - 10
        if warnAt > 2 {
            let warn = DispatchWorkItem { [weak self] in
                Task { @MainActor [weak self] in
                    self?.speak(.restWarning(10))
                }
            }
            restTimers.append(warn)
            DispatchQueue.global().asyncAfter(
                deadline: .now() + warnAt,
                execute: warn
            )
        }

        // Konec pauzy
        let end = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.speak(.restEnd)
            }
        }
        restTimers.append(end)
        DispatchQueue.global().asyncAfter(
            deadline: .now() + Double(seconds),
            execute: end
        )
    }

    func announceRestSkipped() {
        cancelRestTimers()
        // Žádná hláška — uživatel přeskočil záměrně
    }

    // MARK: - Set / Series

    func announceSetStarting(setIndex: Int, totalSets: Int, tempoString: String?) {
        guard isEnabled else { return }
        speak(.setStarting(setIndex + 1, totalSets))

        if let t = tempoString, let tempo = TempoParser.parse(t) {
            // Stručné info o tempu: "Tempo tři-jedna-dva-nula"
            let tempoText = "Tempo \(tempo.displayString.replacingOccurrences(of: "-", with: " "))"
            let tempoSpeech = makeSpeech(tempoText, rate: 0.48)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.synthesizer.speak(tempoSpeech)
            }
        }
    }

    func announceSetComplete(praise: Bool = true) {
        guard isEnabled else { return }
        stopTempo()
        if praise { speak(.greatSet) }
    }

    func announceNewPRTarget(exerciseName: String) {
        guard isEnabled else { return }
        speak(.prWarning(exerciseName))
    }

    // MARK: - Core Speech

    internal func speak(_ event: CoachSpeech) {
        guard isEnabled, isSessionActive else { return }

        // Deduplikace — nespouštěj stejnou hlášku víckrát rychle za sebou
        // (metronom může spustit tempoPhase opakovaně)
        if case .tempoPhase = event, synthesizer.isSpeaking { return }

        let utterance = makeSpeech(event.utteranceText, rate: event.rate)
        utterance.volume = event.volume

        // Pro tempo cues přeruš stávající mluvení
        if case .tempoPhase = event, synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        DispatchQueue.main.async { [weak self] in
            self?.synthesizer.speak(utterance)
        }
    }

    private func makeSpeech(_ text: String, rate: Float) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice  = czechVoice
        utterance.rate   = rate
        utterance.volume = 1.0
        utterance.pitchMultiplier = 1.05  // mírně vyšší = živější projev
        utterance.preUtteranceDelay  = 0
        utterance.postUtteranceDelay = 0.05
        return utterance
    }

    // MARK: - Cleanup

    func stopAll() {
        stopTempo()
        cancelRestTimers()
        synthesizer.stopSpeaking(at: .immediate)
        speechQueue.removeAll()
        isSpeaking = false
        currentPhase = nil
    }

    private func cancelRestTimers() {
        restTimers.forEach { $0.cancel() }
        restTimers.removeAll()
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioCoachService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
}
