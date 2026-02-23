// OnboardingAIManager.swift
// Agilní Fitness Trenér — AI manager pro konverzační onboarding

import Foundation
import SwiftData

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
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
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var inputDisabled: Bool = false
    @Published var extractedProfile: UserProfile? = nil
    @Published var errorMessage: String? = nil

    // Marker booleans
    @Published private(set) var profileReady: Bool = false

    // MARK: - Private
    private let apiKey: String
    private let session: URLSession
    private let model   = "gemini-2.5-flash-lite-preview-06-17"
    private lazy var endpoint: URL = {
        URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)"
        )!
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
            Jsi Jakub, osobní fitness trenér. Zjisti od uživatele jméno, věk, výšku, váhu, cíl, úroveň zkušeností a počet tréninkových dní. Mluv přátelsky, tykej. Až budeš mít vše, ukonči odpověď blokem ###PROFILE_JSON### { ... } ###END_JSON###.
            """
        }
        return text
    }

    // MARK: - Public API

    /// Spustí konverzaci — Jakub pošle úvodní zprávu automaticky
    func startConversation() async {
        guard messages.isEmpty else { return }
        await fetchResponse(userMessage: "__START__")
    }

    /// Odešle uživatelovu zprávu a načte odpověď
    func send(message: String) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        messages.append(ChatMessage(role: .user, text: trimmed))
        await fetchResponse(userMessage: trimmed)
    }

    // MARK: - Core API Call

    private func fetchResponse(userMessage: String) async {
        isLoading     = true
        errorMessage  = nil

        messages.append(ChatMessage(role: .assistant, text: "", isStreaming: true))
        let streamIndex = messages.count - 1

        defer {
            isLoading = false
            if streamIndex < messages.count {
                messages[streamIndex].isStreaming = false
            }
        }

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
        } catch {
            if streamIndex < messages.count {
                messages[streamIndex].text = "Jejda, něco se pokazilo. Zkus to znovu."
            }
            errorMessage = error.localizedDescription
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
            throw GeminiError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, body: "Stream failed")
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
        guard let endRange = jsonPart.range(of: jsonEndTag) else {
            // No end tag — try to parse everything after start tag
            let candidate = jsonPart.trimmingCharacters(in: .whitespacesAndNewlines)
            return (displayText, candidate.isEmpty ? nil : candidate)
        }

        let jsonString = String(jsonPart[jsonPart.startIndex..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (displayText, jsonString.isEmpty ? nil : jsonString)
    }

    // MARK: - Profile Extraction

    private func handleExtractedJSON(_ jsonString: String) async {
        // Clean JSON string (remove potential code fences)
        let cleaned = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            errorMessage = "Nepodařilo se přečíst profil."
            return
        }

        do {
            let dto = try JSONDecoder().decode(OnboardingProfileDTO.self, from: data)
            let profile = dto.toUserProfile()
            extractedProfile = profile
            profileReady = true
            inputDisabled = true  // Freeze chat — we're done
        } catch {
            errorMessage = "Chyba při zpracování profilu: \(error.localizedDescription)"
        }
    }

    // MARK: - Convenience

    var lastAssistantMessage: ChatMessage? {
        messages.last { $0.role == .assistant }
    }
}
