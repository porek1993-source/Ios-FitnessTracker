// SupabaseExerciseRepository.swift
// Nativní REST klient pro Supabase (bez SDK).
//
// OPRAVY v2.0:
//  ✅ KRITICKÁ OPRAVA: tabulka přejmenována muscle_wiki_data → muscle_wiki_data_full
//  ✅ Přidán ExerciseDTO (chyběl, způsoboval chybu kompilace)
//  ✅ Přidán AIEnrichedExerciseData (chyběl, způsoboval chybu kompilace)
//  ✅ Přidána paginace pro fetchMuscleWikiAll (limit 200 záznamů na stránku)

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

// MARK: - SupabaseExerciseRepository

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

    // MARK: - MuscleWiki Data

    /// Načte všechny cviky z tabulky `public.muscle_wiki_data_full`.
    /// ✅ OPRAVENO: bylo muscle_wiki_data (neexistující tabulka)
    func fetchMuscleWikiAll() async throws -> [MuscleWikiExercise] {
        let url = try buildURL(path: "/rest/v1/muscle_wiki_data_full", query: [
            ("select", "*"),
            ("order", "muscle_group.asc,name.asc"),
            ("limit", "1000")
        ])
        return try await performRequest(url: url)
    }

    /// Načte cviky z `muscle_wiki_data_full` filtrované podle svalové skupiny.
    /// ✅ OPRAVENO: bylo muscle_wiki_data (neexistující tabulka)
    func fetchMuscleWikiByGroup(_ group: String) async throws -> [MuscleWikiExercise] {
        let url = try buildURL(path: "/rest/v1/muscle_wiki_data_full", query: [
            ("select", "*"),
            ("muscle_group", "eq.\(group)"),
            ("order", "name.asc")
        ])
        return try await performRequest(url: url)
    }

    /// Načte cviky s paginací (pro velké datasety).
    /// page: 0-based index stránky, pageSize: počet záznamů na stránku
    func fetchMuscleWikiPage(page: Int = 0, pageSize: Int = 200) async throws -> [MuscleWikiExercise] {
        let offset = page * pageSize
        let url = try buildURL(path: "/rest/v1/muscle_wiki_data_full", query: [
            ("select", "*"),
            ("order", "muscle_group.asc,name.asc"),
            ("limit", "\(pageSize)"),
            ("offset", "\(offset)")
        ])
        return try await performRequest(url: url)
    }

    // MARK: - Exercise Data (Detailed) — pro budoucí tabulku public.exercises

    /// Načte všechny cviky z tabulky `public.exercises`.
    func fetchAll() async throws -> [ExerciseDTO] {
        let url = try buildURL(path: "/rest/v1/exercises", query: [
            ("select", "*"),
            ("order", "name_cz.asc")
        ])
        return try await performRequest(url: url)
    }

    /// Načte jeden cvik podle slugu.
    func fetchBySlug(_ slug: String) async throws -> ExerciseDTO? {
        let url = try buildURL(path: "/rest/v1/exercises", query: [
            ("select", "*"),
            ("slug", "eq.\(slug)")
        ])
        let results: [ExerciseDTO] = try await performRequest(url: url)
        return results.first
    }

    /// Načte cviky podle kategorie (např. "chest", "legs").
    func fetchByCategory(_ category: String) async throws -> [ExerciseDTO] {
        let url = try buildURL(path: "/rest/v1/exercises", query: [
            ("select", "*"),
            ("category", "eq.\(category)"),
            ("order", "name_cz.asc")
        ])
        return try await performRequest(url: url)
    }

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
                case nameEn               = "name_en"
                case equipment
                case primaryMuscles       = "primary_muscles"
                case secondaryMuscles     = "secondary_muscles"
                case instructions
                case instructionsMissing  = "instructions_missing"
                case instructionsSource   = "instructions_source"
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

        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = try JSONEncoder().encode(payload)

        let maxRetries = 3
        var currentAttempt = 0

        while currentAttempt <= maxRetries {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    throw SupabaseError.httpError(statusCode: 0)
                }

                guard (200...299).contains(http.statusCode) else {
                    throw SupabaseError.httpError(statusCode: http.statusCode)
                }

                return

            } catch let error as SupabaseError {
                if case .httpError(let code) = error, (400...499).contains(code), code != 429 {
                    throw error
                }
                if currentAttempt == maxRetries { throw error }
                await performBackoff(attempt: currentAttempt)
            } catch {
                if currentAttempt == maxRetries { throw SupabaseError.networkError(error) }
                await performBackoff(attempt: currentAttempt)
            }
            currentAttempt += 1
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

        let maxRetries = 3
        var currentAttempt = 0

        while currentAttempt <= maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    throw SupabaseError.httpError(statusCode: 0)
                }

                guard (200...299).contains(http.statusCode) else {
                    throw SupabaseError.httpError(statusCode: http.statusCode)
                }

                let decoder = JSONDecoder()
                do {
                    return try decoder.decode(T.self, from: data)
                } catch let decodeError {
                    AppLogger.error("⛔ [Supabase] Chyba dekódování: \(decodeError)")
                    throw SupabaseError.decodingFailed(decodeError.localizedDescription)
                }

            } catch let error as SupabaseError {
                switch error {
                case .decodingFailed, .invalidURL:
                    throw error
                case .httpError(let code) where (400...499).contains(code):
                    if code != 429 { throw error }
                default:
                    break
                }

                if currentAttempt == maxRetries { throw error }
                await performBackoff(attempt: currentAttempt)
            } catch {
                if currentAttempt == maxRetries { throw SupabaseError.networkError(error) }
                await performBackoff(attempt: currentAttempt)
            }
            currentAttempt += 1
        }

        throw SupabaseError.networkError(NSError(domain: "SupabaseRetry", code: -1))
    }

    // MARK: - Exponential Backoff

    private func performBackoff(attempt: Int) async {
        let baseDelay = pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.5)
        let totalDelaySeconds = baseDelay + jitter
        let nanoseconds = UInt64(totalDelaySeconds * 1_000_000_000)

        AppLogger.warning("⚠️ [Supabase] Síťová chyba, pokus \(attempt + 1) selhal. Opakuji za \(String(format: "%.1f", totalDelaySeconds))s...")
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}
