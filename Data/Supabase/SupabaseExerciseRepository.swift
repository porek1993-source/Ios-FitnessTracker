// SupabaseExerciseRepository.swift
// Nativní REST klient pro Supabase — muscle_wiki_data (bez SDK).

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

    // MARK: - MuscleWiki Data

    /// Načte všechny cviky z tabulky `public.muscle_wiki_data`.
    func fetchMuscleWikiAll() async throws -> [MuscleWikiExercise] {
        let url = try buildURL(path: "/rest/v1/muscle_wiki_data", query: [
            ("select", "*"),
            ("order", "muscle_group.asc,name.asc")
        ])
        return try await performRequest(url: url)
    }

    /// Načte cviky z `muscle_wiki_data` filtrované podle svalové skupiny.
    func fetchMuscleWikiByGroup(_ group: String) async throws -> [MuscleWikiExercise] {
        let url = try buildURL(path: "/rest/v1/muscle_wiki_data", query: [
            ("select", "*"),
            ("muscle_group", "eq.\(group)"),
            ("order", "name.asc")
        ])
        return try await performRequest(url: url)
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
                return try decoder.decode(T.self, from: data)

            } catch let error as SupabaseError {
                // If it's a decoding error or specific HTTP error (e.g., 401, 404), do not retry
                switch error {
                case .decodingFailed, .invalidURL:
                    throw error
                case .httpError(let code) where (400...499).contains(code):
                    // Client errors usually don't resolve by retrying (except maybe 429, but let's keep it simple)
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
        
        // This should theoretically be unreachable because the loop throws on maxRetries
        throw SupabaseError.networkError(NSError(domain: "SupabaseRetry", code: -1))
    }
    
    // MARK: - Exponential Backoff
    
    private func performBackoff(attempt: Int) async {
        // Obvyklé časy: 1s, 2s, 4s (s mírným jitterem)
        let baseDelay = pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...0.5)
        let totalDelaySeconds = baseDelay + jitter
        let nanoseconds = UInt64(totalDelaySeconds * 1_000_000_000)
        
        AppLogger.warning("⚠️ [Supabase] Síťová chyba, pokus \(attempt + 1) selhal. Opakuji za \(String(format: "%.1f", totalDelaySeconds))s...")
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}
