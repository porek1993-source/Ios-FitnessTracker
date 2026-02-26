// PerformanceHelpers.swift
// Pomocníky pro výkon, baterii a prevenci memory leaků.

import Foundation
import Combine

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Debouncer
// MARK: ═══════════════════════════════════════════════════════════════════════

/// Debouncer pro omezení frekvence spouštění akcí (API volání, překreslování UI).
/// Šetří baterii a API kvóty.
final class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?

    init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }

    /// Spustí akci až po uplynutí doby od posledního volání.
    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancel() {
        workItem?.cancel()
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Throttler
// MARK: ═══════════════════════════════════════════════════════════════════════

/// Throttler — povolí maximálně 1 akci za daný interval.
final class Throttler {
    private let interval: TimeInterval
    private var lastExecution: Date = .distantPast

    init(interval: TimeInterval = 1.0) {
        self.interval = interval
    }

    func throttle(action: @escaping () -> Void) {
        let now = Date()
        guard now.timeIntervalSince(lastExecution) >= interval else { return }
        lastExecution = now
        action()
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Safe Async Task (Weak Self Pattern)
// MARK: ═══════════════════════════════════════════════════════════════════════

/// Bezpečné spuštění async práce z ObservableObject bez retain cyklů.
///
/// Příklad použití v libovolném @MainActor ObservableObject:
/// ```swift
/// class MyVM: ObservableObject {
///     func load() {
///         SafeTask.run(on: self) { vm in
///             let data = try await api.fetch()
///             vm.items = data         // vm je [weak self], bezpečné
///         }
///     }
/// }
/// ```
enum SafeTask {

    /// Spustí async úlohu s [weak self] ochranou.
    /// Pokud je objekt uvolněn z paměti, úloha se přeskočí.
    @discardableResult
    @MainActor
    static func run<T: AnyObject>(
        on object: T,
        priority: TaskPriority = .userInitiated,
        operation: @escaping (T) async throws -> Void
    ) -> Task<Void, Never> {
        Task(priority: priority) { [weak object] in
            guard let object else { return }
            try? await operation(object)
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Ukázka správného [weak self] v praxi
// MARK: ═══════════════════════════════════════════════════════════════════════

/*
 ❌ ŠPATNĚ — Retain Cycle:
 
 class WorkoutVM: ObservableObject {
     func fetchPlan() {
         Task {
             let plan = try await api.generatePlan()
             self.plan = plan           // self je silně zachycen → memory leak
         }
     }
 }

 ✅ SPRÁVNĚ — Weak Self:
 
 class WorkoutVM: ObservableObject {
     func fetchPlan() {
         Task { [weak self] in
             guard let self else { return }
             let plan = try await api.generatePlan()
             await MainActor.run {
                 self.plan = plan
             }
         }
     }
 }
 
 ✅ NEJLEPŠÍ — SafeTask helper:
 
 class WorkoutVM: ObservableObject {
     func fetchPlan() {
         SafeTask.run(on: self) { vm in
             let plan = try await api.generatePlan()
             vm.plan = plan
         }
     }
 }
*/
