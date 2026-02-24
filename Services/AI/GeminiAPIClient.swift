// GeminiAPIClient.swift

import Foundation

actor GeminiAPIClient {

    private let apiKey: String
    private let model   = "gemini-1.5-flash"
    private let session: URLSession

    private var endpoint: URL {
        URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/"
            + "\(model):generateContent?key=\(apiKey)"
        )!
    }

    init(apiKey: String) {
        self.apiKey  = apiKey
        self.session = URLSession(configuration: .default)
    }

    func generate(systemPrompt: String, userMessage: String, responseSchema: [String: Any]? = nil) async throws -> String {
        var generationConfig: [String: Any] = [
            "temperature": 0.4,
            "topP": 0.85,
            "maxOutputTokens": 2048,
            "responseMimeType": "application/json"
        ]
        
        if let schema = responseSchema {
            generationConfig["responseSchema"] = schema
        }

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": userMessage]]
                ]
            ],
            "generationConfig": generationConfig
        ]

        var request        = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody   = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw GeminiError.httpError(statusCode: http.statusCode, body: body)
        }

        let parsed = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = parsed.candidates.first?.content.parts.first?.text else {
            throw GeminiError.emptyResponse
        }
        return text
    }
}

// MARK: - Wire Types

private struct GeminiResponse: Decodable {
    let candidates: [Candidate]
    struct Candidate: Decodable {
        let content: Content
        struct Content: Decodable {
            let parts: [Part]
            struct Part: Decodable { let text: String }
        }
    }
}

enum GeminiError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case emptyResponse
    case jsonParsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:           return "Neplatná odpověď serveru."
        case .httpError(let s, let b):   return "HTTP \(s): \(b)"
        case .emptyResponse:             return "Gemini vrátilo prázdnou odpověď."
        case .jsonParsingFailed(let m):  return "JSON chyba: \(m)"
        }
    }
}
