// OnboardingAIManager.swift
// Agilní Fitness Trenér — AI manager pro konverzační onboarding

import Foundation
import SwiftData

// MARK: - Chat Message Model

struct OnboardingChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var text: String
    let timestamp: Date
    var isStreaming: Bool

    enum MessageRole { case user, assistant }

    init(role: MessageRole, text: String, isStreaming: Bool = false) {
        self.id        = UUID()
        self.role      = role
        self.text      = text
        self.timestamp = .now
        self.isStreaming = isStreaming
    }
}

// MARK: - Extracted Profile DTO (from JSON block)

struct OnboardingProfileDTO: Decodable {
    let name:                  String
    let ageYears:              Int
    let gender:                String
    let heightCm:              Double
    let weightKg:              Double
    let primaryGoal:           String
    let fitnessLevel:          String
    let availableDaysPerWeek:  Int
    let preferredSplitType:    String
    let sessionDurationMinutes: Int

    enum CodingKeys: String, CodingKey {
        case name, jmeno
        case ageYears, age, vek
        case gender, pohlavi
        case heightCm = "heightCm"
        case height_cm, vyska
        case weightKg = "weightKg"
        case weight_kg, vaha
        case primaryGoal, goal, cil
        case fitnessLevel = "fitnessLevel"
        case experience_level, uroven_zkusenosti
        case availableDaysPerWeek = "availableDaysPerWeek"
        case training_days_per_week, pocet_treninkovych_dnu
        case preferredSplitType = "preferredSplitType"
        case preferred_split
        case sessionDurationMinutes = "sessionDurationMinutes"
        case session_duration, delka_treninku
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decodeIfPresent(String.self, forKey: .name) ??
               container.decodeIfPresent(String.self, forKey: .jmeno) ?? "Neznámý"
               
        ageYears = try container.decodeIfPresent(Int.self, forKey: .ageYears) ??
                   container.decodeIfPresent(Int.self, forKey: .age) ??
                   container.decodeIfPresent(Int.self, forKey: .vek) ?? 30
                   
        gender = try container.decodeIfPresent(String.self, forKey: .gender) ??
                 container.decodeIfPresent(String.self, forKey: .pohlavi) ?? "other"
                 
        // DVOJÍ PARSOVÁNÍ čísel (AI občas pošle "175" jako string místo 175 číslo)
        if let hDouble = try? container.decodeIfPresent(Double.self, forKey: .heightCm) { heightCm = hDouble }
        else if let hString = try? container.decodeIfPresent(String.self, forKey: .heightCm), let h = Double(hString) { heightCm = h }
        else if let hDouble2 = try? container.decodeIfPresent(Double.self, forKey: .height_cm) { heightCm = hDouble2 }
        else if let hDouble3 = try? container.decodeIfPresent(Double.self, forKey: .vyska) { heightCm = hDouble3 }
        else { heightCm = 175.0 }
        
        if let wDouble = try? container.decodeIfPresent(Double.self, forKey: .weightKg) { weightKg = wDouble }
        else if let wString = try? container.decodeIfPresent(String.self, forKey: .weightKg), let w = Double(wString) { weightKg = w }
        else if let wDouble2 = try? container.decodeIfPresent(Double.self, forKey: .weight_kg) { weightKg = wDouble2 }
        else if let wDouble3 = try? container.decodeIfPresent(Double.self, forKey: .vaha) { weightKg = wDouble3 }
        else { weightKg = 75.0 }
                   
        primaryGoal = try container.decodeIfPresent(String.self, forKey: .primaryGoal) ??
                      container.decodeIfPresent(String.self, forKey: .goal) ??
                      container.decodeIfPresent(String.self, forKey: .cil) ?? "hypertrophy"
                      
        fitnessLevel = try container.decodeIfPresent(String.self, forKey: .fitnessLevel) ??
                       container.decodeIfPresent(String.self, forKey: .experience_level) ??
                       container.decodeIfPresent(String.self, forKey: .uroven_zkusenosti) ?? "intermediate"
                       
        availableDaysPerWeek = try container.decodeIfPresent(Int.self, forKey: .availableDaysPerWeek) ??
                               container.decodeIfPresent(Int.self, forKey: .training_days_per_week) ??
                               container.decodeIfPresent(Int.self, forKey: .pocet_treninkovych_dnu) ?? 3
                               
        preferredSplitType = try container.decodeIfPresent(String.self, forKey: .preferredSplitType) ??
                             container.decodeIfPresent(String.self, forKey: .preferred_split) ?? "ppl"
                             
        sessionDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .sessionDurationMinutes) ??
                                 container.decodeIfPresent(Int.self, forKey: .session_duration) ??
                                 container.decodeIfPresent(Int.self, forKey: .delka_treninku) ?? 60
    }

    /// Converts DTO → SwiftData UserProfile
    func toUserProfile() -> UserProfile {
        let calendar = Calendar.current
        let birthYear = calendar.component(.year, from: .now) - ageYears
        var components = DateComponents()
        components.year  = birthYear
        components.month = 1
        components.day   = 1
        let dob = calendar.date(from: components) ?? .now

        let goal: FitnessGoal = {
            switch primaryGoal {
            case "strength":    return .strength
            case "hypertrophy": return .hypertrophy
            case "weightLoss":  return .weightLoss
            case "endurance":   return .endurance
            default:            return .hypertrophy
            }
        }()

        let level: FitnessLevel = {
            switch fitnessLevel {
            case "beginner":    return .beginner
            case "intermediate":return .intermediate
            case "advanced":    return .advanced
            default:            return .intermediate
            }
        }()

        let split: SplitType = {
            switch preferredSplitType {
            case "fullBody":    return .fullBody
            case "upperLower":  return .upperLower
            case "ppl":         return .ppl
            default:            return .ppl
            }
        }()

        let genderEnum: Gender = {
            switch gender {
            case "male":   return .male
            case "female": return .female
            default:       return .other
            }
        }()

        let profile = UserProfile(
            name:                  name,
            dateOfBirth:           dob,
            gender:                genderEnum,
            heightCm:              heightCm,
            weightKg:              weightKg,
            primaryGoal:           goal,
            fitnessLevel:          level,
            availableDaysPerWeek:  availableDaysPerWeek,
            preferredSplitType:    split,
            sessionDurationMinutes: sessionDurationMinutes
        )
        return profile
    }
}

// MARK: - OnboardingAIManager

@MainActor
final class OnboardingAIManager: ObservableObject {

    // MARK: - Published State
    @Published var messages: [OnboardingChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var inputDisabled: Bool = false
    @Published var extractedProfile: UserProfile? = nil
    @Published var errorMessage: String? = nil

    // Marker booleans
    @Published private(set) var profileReady: Bool = false

    // MARK: - Private
    private let apiKey: String
    private let session: URLSession
    private let model   = "gemini-2.5-flash"
    private lazy var endpoint: URL = {
        URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)"
        ) ?? URL(fileURLWithPath: "/")
    }()

    private var systemPrompt: String = ""

    // Separators used by AI to wrap the JSON block
    private let jsonStartTag = "###PROFILE_JSON###"
    private let jsonEndTag   = "###END_JSON###"

    // MARK: - Init

    init(apiKey: String) {
        self.apiKey   = apiKey
        self.session  = URLSession(configuration: .default)
        self.systemPrompt = Self.loadSystemPrompt()
    }

    private static func loadSystemPrompt() -> String {
        guard
            let url  = Bundle.main.url(forResource: "OnboardingSystemPrompt", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            // Inline fallback — pokud soubor chybí
            return """
            Jsi Thor, osobní fitness trenér. Zjisti od uživatele jméno, věk, výšku, váhu, cíl, úroveň zkušeností a počet tréninkových dní. Mluv přátelsky, tykej. Až budeš mít vše, ukonči odpověď blokem ###PROFILE_JSON### { ... } ###END_JSON###.
            """
        }
        return text
    }

    // MARK: - Public API

    /// Spustí konverzaci — Thor pošle úvodní zprávu automaticky
    func startConversation() async {
        guard messages.isEmpty else { return }
        await fetchResponse(userMessage: "__START__")
    }

    /// Odešle uživatelovu zprávu a načte odpověď
    func send(message: String) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        messages.append(OnboardingChatMessage(role: .user, text: trimmed))
        await fetchResponse(userMessage: trimmed)
    }

    // MARK: - Core API Call

    private func fetchResponse(userMessage: String) async {
        isLoading     = true
        errorMessage  = nil

        messages.append(OnboardingChatMessage(role: .assistant, text: "", isStreaming: true))
        let streamIndex = messages.count - 1

        defer {
            isLoading = false
            if streamIndex < messages.count {
                messages[streamIndex].isStreaming = false
            }
        }

        do {
            var attempts = 0
            let maxAttempts = 3
            
            while attempts < maxAttempts {
                do {
                    var fullText = ""
                    for try await chunk in try await streamGemini(userMessage: userMessage) {
                        fullText += chunk
                        let (displayText, jsonBlock) = parseResponse(fullText)

                        // Update bubble with display text (without JSON markers)
                        if streamIndex < messages.count {
                            messages[streamIndex].text = displayText
                        }

                        // If JSON is completely found, handle it and we are done
                        if let jsonString = jsonBlock, profileReady == false {
                            await handleExtractedJSON(jsonString)
                        }
                    }

                    // Post-stream fallback: JSON tags may have been split across chunks
                    if !profileReady {
                        AppLogger.shared.log("OnboardingAIManager: Stream skončil, profil zatím nenalezen. Délka textu: \(fullText.count) znaků. Zkouším post-stream fallback...", type: .info)
                        let (displayText, jsonBlock) = parseResponse(fullText)
                        if streamIndex < messages.count {
                            messages[streamIndex].text = displayText
                        }
                        if let jsonString = jsonBlock {
                            AppLogger.shared.log("OnboardingAIManager: Post-stream fallback našel JSON blok!", type: .success)
                            await handleExtractedJSON(jsonString)
                        } else {
                            AppLogger.shared.log("OnboardingAIManager: Ani post-stream fallback nenašel JSON tagy.", type: .warning)
                        }
                    }
                    return // Success!

                } catch let error as GeminiError {
                    if case .httpError(let statusCode, _) = error, statusCode == 429 {
                        attempts += 1
                        if attempts >= maxAttempts { throw error }
                        
                        let delay = pow(2.0, Double(attempts)) + Double.random(in: 0...1)
                        AppLogger.shared.log("OnboardingAIManager: Rate limit (429). Retry \(attempts)/\(maxAttempts) za \(String(format: "%.1f", delay))s...", type: .warning)
                        if streamIndex < messages.count {
                            messages[streamIndex].text = "Šetřím energii (API rate limit)... zkouším znovu za chvíli. 💪"
                        }
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                    throw error
                } catch {
                    throw error
                }
            }
        } catch {
            let errorDetail = errorMessage ?? error.localizedDescription
            if streamIndex < messages.count {
                messages[streamIndex].text = "Jejda, něco se pokazilo.\n\nDetail chyby: \(errorDetail)\n\nZkontroluj v nastavení/prostředí, zda je správně nastaven GEMINI_API_KEY a zkus to prosím znovu."
            }
            errorMessage = errorDetail
        }
    }

    // MARK: - Gemini API

    private func streamGemini(userMessage: String) async throws -> AsyncThrowingStream<String, Error> {
        // Build conversation history for multi-turn
        var contents: [[String: Any]] = []

        for msg in messages where !msg.isStreaming {
            if msg.role == .assistant && msg.text.isEmpty { continue }

            let role = msg.role == .user ? "user" : "model"
            let content: [String: Any] = [
                "role": role,
                "parts": [["text": msg.text]]
            ]
            contents.append(content)
        }

        if userMessage == "__START__" {
            contents.append([
                "role": "user",
                "parts": [["text": "Začni konverzaci."]]
            ])
        }

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": contents,
            "generationConfig": [
                "temperature": 0.75,
                "topP": 0.90,
                "maxOutputTokens": 1024,
                "responseMimeType": "text/plain"
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: body)

        var request        = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody   = data
        request.timeoutInterval = 45

        let (result, response) = try await session.bytes(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GeminiError.httpError(statusCode: statusCode, body: "Stream failed: \(statusCode)")
        }

        struct GeminiStreamChunk: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]?
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in result.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = line.dropFirst(6)
                        guard jsonString != "[DONE]" else { continue }
                        
                        if let data = jsonString.data(using: .utf8),
                           let chunk = try? JSONDecoder().decode(GeminiStreamChunk.self, from: data),
                           let text = chunk.candidates?.first?.content.parts.first?.text {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Response Parsing

    /// Splits AI response into (displayText, jsonBlock?)
    private func parseResponse(_ raw: String) -> (String, String?) {
        guard raw.contains(jsonStartTag) else {
            return (raw.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }

        let parts = raw.components(separatedBy: jsonStartTag)
        let displayText = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)

        guard parts.count > 1 else { return (displayText, nil) }

        let jsonPart = parts[1]
        // CRITICAL FIX: Only return the jsonString if we have BOTH tags.
        // During streaming, we don't want to try parsing partial JSON.
        guard let endRange = jsonPart.range(of: jsonEndTag) else {
            return (displayText, nil)
        }

        let jsonString = String(jsonPart[jsonPart.startIndex..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (displayText, jsonString.isEmpty ? nil : jsonString)
    }

    // MARK: - Profile Extraction

    private func handleExtractedJSON(_ jsonString: String) async {
        // Use regex for a more robust extraction if there's trailing junk or nested markers
        // We look for everything between the first '{' and the last '}'
        var cleaned = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let firstBrace = cleaned.firstIndex(of: "{"),
           let lastBrace = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[firstBrace...lastBrace])
        }

        guard let data = cleaned.data(using: .utf8) else {
            AppLogger.shared.log("OnboardingAIManager: Nelze převést vyčištěný JSON string na data.", type: .error)
            errorMessage = "Nepodařilo se přečíst profil."
            return
        }

        do {
            let dto = try JSONDecoder().decode(OnboardingProfileDTO.self, from: data)
            let profile = dto.toUserProfile()
            extractedProfile = profile
            profileReady = true
            inputDisabled = true  // Freeze chat — we're done
            AppLogger.shared.log("OnboardingAIManager: Profil úspěšně dekódován a připraven k uložení!", type: .success)
        } catch {
            AppLogger.shared.log("OnboardingAIManager: Chyba dekódování JSONu - \(error)", type: .error)
            AppLogger.shared.log("OnboardingAIManager: Selhaný JSON: \(cleaned)", type: .info)
            // Ořezání chyby na uživatelsky přívětivější text
            errorMessage = "Chyba struktury profilu. Thor zřejmě nevygeneroval přesná data."
        }
    }

    // MARK: - Convenience

    var lastAssistantMessage: OnboardingChatMessage? {
        messages.last { $0.role == .assistant }
    }
}
