// CoOpSessionService.swift
// Lightweight Supabase Realtime presence pro "Právě cvičí" funkci.
// Publikuje uživatelovu aktivní sérii a odebírá aktivitu přátel.

import Foundation
@preconcurrency import Supabase

struct LivePresence: Codable, Identifiable {
    var id: String { userId }
    let userId: String
    let displayName: String
    let exerciseName: String
    let setNumber: Int
    let timestamp: Date
}

@MainActor
final class CoOpSessionService: ObservableObject {
    static let shared = CoOpSessionService()

    @Published var activeFriends: [LivePresence] = []
    private var presenceTask: Task<Void, Never>?
    
    private var channel: RealtimeChannelV2?
    private let tableName = "live_sessions"

    private init() {}

    // MARK: - Publish

    /// Zveřejní dokončenou sérii uživatele pro přátele.
    func publishSet(userId: String, displayName: String, exerciseName: String, setNumber: Int) {
        guard !userId.isEmpty else { return }
        Task {
            do {
                let payload: [String: AnyJSON] = [
                    "user_id":       .string(userId),
                    "display_name":  .string(displayName),
                    "exercise_name": .string(exerciseName),
                    "set_number":    .double(Double(setNumber)),
                    "timestamp":     .string(ISO8601DateFormatter().string(from: Date()))
                ]
                _ = try await AppEnvironment.shared.supabase
                    .from(tableName)
                    .upsert(payload)
                    .execute()
            } catch {
                AppLogger.error("CoOpSessionService: Publish selhal — \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Subscribe

    /// Začne sledovat aktivní přátele (aktualizace posledních 15 minut).
    func startListening() {
        presenceTask?.cancel()
        presenceTask = Task { [weak self] in
            guard let self else { return }
            await self.fetchActiveFriends()

            // Poll každých 30 sekund (jednoduchý fallback bez WS)
            for await _ in AsyncTimerSequence(interval: 30) {
                guard !Task.isCancelled else { break }
                await self.fetchActiveFriends()
            }
        }
    }

    func stopListening() {
        presenceTask?.cancel()
        presenceTask = nil
    }

    // MARK: - Private

    private func fetchActiveFriends() async {
        do {
            let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-15 * 60))
            let response = try await AppEnvironment.shared.supabase
                .from(tableName)
                .select()
                .gte("timestamp", value: cutoff)
                .order("timestamp", ascending: false)
                .execute() as PostgrestResponse<Data>

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601

            if let presences = try? decoder.decode([LivePresence].self, from: response.data) {
                activeFriends = presences
            }
        } catch {
            AppLogger.error("CoOpSessionService: Fetch selhal — \(error.localizedDescription)")
        }
    }
}

// MARK: - Async Timer

struct AsyncTimerSequence: AsyncSequence {
    typealias Element = Date
    let interval: TimeInterval

    struct AsyncIterator: AsyncIteratorProtocol {
        let interval: TimeInterval
        mutating func next() async -> Date? {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            return Task.isCancelled ? nil : Date()
        }
    }

    func makeAsyncIterator() -> AsyncIterator { AsyncIterator(interval: interval) }
}
