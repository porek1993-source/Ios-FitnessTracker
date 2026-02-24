// SupabaseExerciseRepository.swift
// Nativní REST klient pro Supabase tabulku public.exercises (bez SDK).

import Foundation

enum SupabaseError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int)
    case decodingFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:               return "Neplatná URL adresa."
        case .httpError(let code):      return "Server vrátil chybu \(code)."
        case .decodingFailed(let msg):  return "Chyba parsování: \(msg)"
        case .networkError(let err):    return "Síťová chyba: \(err.localizedDescription)"
        }
    }
}

actor SupabaseExerciseRepository {

    private let baseURL: String
    private let apiKey: String

    /// Headers pro Supabase REST API (PostgREST).
    private var defaultHeaders: [String: String] {
        [
            "apikey": apiKey,
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        ]
    }

    init(projectURL: String = AppConstants.supabaseURL,
         apiKey: String = AppConstants.supabaseAnonKey) {
        self.baseURL = projectURL.hasSuffix("/") ? String(projectURL.dropLast()) : projectURL
        self.apiKey  = apiKey
    }

    // MARK: - Fetch All

    /// Načte všechny cviky z tabulky `public.exercises`.
    func fetchAll() async throws -> [ExerciseDTO] {
        let url = try buildURL(path: "/rest/v1/exercises", query: [
            ("select", "*"),
            ("order", "name_cz.asc")
        ])
        return try await performRequest(url: url)
    }

    // MARK: - Fetch by Slug

    /// Načte jeden cvik podle slugu.
    func fetchBySlug(_ slug: String) async throws -> ExerciseDTO? {
        let url = try buildURL(path: "/rest/v1/exercises", query: [
            ("select", "*"),
            ("slug", "eq.\(slug)")
        ])
        let results: [ExerciseDTO] = try await performRequest(url: url)
        return results.first
    }

    // MARK: - Fetch by Category

    /// Načte cviky podle kategorie (např. "chest", "legs").
    func fetchByCategory(_ category: String) async throws -> [ExerciseDTO] {
        let url = try buildURL(path: "/rest/v1/exercises", query: [
            ("select", "*"),
            ("category", "eq.\(category)"),
            ("order", "name_cz.asc")
        ])
        return try await performRequest(url: url)
    }

    // MARK: - Fetch Missing Instructions

    /// Načte cviky s chybějícími instrukcemi (pro AI enrichment).
    func fetchMissingInstructions() async throws -> [ExerciseDTO] {
        let url = try buildURL(path: "/rest/v1/exercises", query: [
            ("select", "*"),
            ("instructions_missing", "eq.true"),
            ("order", "name_cz.asc")
        ])
        return try await performRequest(url: url)
    }

    // MARK: - Update Exercise (Write-back)

    /// Aktualizuje data cviku v Supabase po dogenerování AI.
    func updateExercise(slug: String, with aiData: AIEnrichedExerciseData) async throws {
        let url = try buildURL(path: "/rest/v1/exercises", query: [
            ("slug", "eq.\(slug)")
        ])

        struct ExerciseUpdatePayload: Encodable {
            let nameEn: String
            let equipment: String
            let primaryMuscles: [String]
            let secondaryMuscles: [String]
            let instructions: String
            let instructionsMissing: Bool
            let instructionsSource: String
            let instructionsUpdatedAt: String

            enum CodingKeys: String, CodingKey {
                case nameEn = "name_en"
                case equipment
                case primaryMuscles = "primary_muscles"
                case secondaryMuscles = "secondary_muscles"
                case instructions
                case instructionsMissing = "instructions_missing"
                case instructionsSource = "instructions_source"
                case instructionsUpdatedAt = "instructions_updated_at"
            }
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())

        let payload = ExerciseUpdatePayload(
            nameEn: aiData.nameEn,
            equipment: aiData.equipment,
            primaryMuscles: aiData.primaryMuscles,
            secondaryMuscles: aiData.secondaryMuscles,
            instructions: aiData.instructions,
            instructionsMissing: false,
            instructionsSource: "ai_gemini_flash",
            instructionsUpdatedAt: timestamp
        )

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 15
        
        // Setup headers manually since defaultHeaders has Prefer: return=representation. We may not need it here, or we can use it.
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.httpError(statusCode: 0)
        }

        // 200...299 indicates successful patch
        guard (200...299).contains(http.statusCode) else {
            throw SupabaseError.httpError(statusCode: http.statusCode)
        }
    }

    // MARK: - Helpers

    private func buildURL(path: String, query: [(String, String)]) throws -> URL {
        var components = URLComponents(string: baseURL + path)
        components?.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = components?.url else { throw SupabaseError.invalidURL }
        return url
    }

    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SupabaseError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.httpError(statusCode: 0)
        }

        guard (200...299).contains(http.statusCode) else {
            throw SupabaseError.httpError(statusCode: http.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SupabaseError.decodingFailed(error.localizedDescription)
        }
    }
}
