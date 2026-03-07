// AppLogger.swift
import Foundation
import SwiftUI

/// Jednoduchý logger, který ukládá zprávy i do paměti pro zobrazení v UI (pro debugování na Windows)
///
/// ✅ FIX #19: Odstraněno @unchecked Sendable — kombinace @MainActor + @unchecked Sendable
/// říká kompilátoru "důvěřuj mi" ale mutable @Published var logs je přístupný
/// ze nonisolated log() přes Task { @MainActor }, přičemž při rychlém logování
/// více konkurenčních Tasks může způsobit nekonzistentní pořadí logů.
///
/// Oprava: AppLogger je @MainActor (bez @unchecked Sendable). Sdílená instance je
/// nonisolated(unsafe) — přijatelné pro singleton přístup k @MainActor třídě,
/// protože všechny mutace probíhají výhradně přes Task { @MainActor }.
@MainActor
final class AppLogger: ObservableObject {
    nonisolated static let shared = AppLogger()
    
    nonisolated init() {}
    @Published var logs: [LogEntry] = []
    private let maxLogs = 100
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let message: String
        let type: LogType
    }
    
    enum LogType { case info, success, error, warning }
    
    nonisolated func log(_ message: String, type: LogType = .info) {
        print("\(type == .error ? "❌" : (type == .success ? "✅" : "ℹ️")) \(message)")
        
        Task { @MainActor in
            self.logs.insert(LogEntry(message: message, type: type), at: 0)
            if self.logs.count > self.maxLogs {
                self.logs.removeLast()
            }
        }
    }
    
    // Static helpers for easier access
    nonisolated static func info(_ message: String) { shared.log(message, type: .info) }
    nonisolated static func error(_ message: String) { shared.log(message, type: .error) }
    nonisolated static func success(_ message: String) { shared.log(message, type: .success) }
    nonisolated static func warning(_ message: String) { shared.log(message, type: .warning) }
}

/// Překryvná vrstva pro zobrazení logů přímo v aplikaci
struct DebugOverlayView: View {
    @ObservedObject var logger = AppLogger.shared
    @State private var isVisible = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if isVisible {
                // Console UI
                VStack(spacing: 0) {
                    HStack {
                        Text("Debug Console")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        Spacer()
                        Button("Kopírovat") {
                            let logsText = logger.logs.map { "\($0.timestamp) [\($0.type)]: \($0.message)" }.joined(separator: "\n")
                            #if os(iOS)
                            UIPasteboard.general.string = logsText
                            #endif
                        }
                        .font(.system(size: 12))
                        Button("Smazat") { logger.logs.removeAll() }
                            .font(.system(size: 12))
                            .padding(.leading, 10)
                        Button("Zavřít") { withAnimation { isVisible = false } }
                            .font(.system(size: 12))
                            .padding(.leading, 10)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.9))
                    .foregroundStyle(.white)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(logger.logs) { entry in
                                    HStack(alignment: .top, spacing: 5) {
                                        Text(entry.timestamp, style: .time)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.gray)
                                        
                                        let color: Color = {
                                            switch entry.type {
                                            case .info: return .white
                                            case .success: return .green
                                            case .error: return .red
                                            case .warning: return .yellow
                                            }
                                        }()
                                        
                                        Text(entry.message)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(color)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Divider().background(Color.gray.opacity(0.3))
                                        .id(entry.id)
                                }
                            }
                            .padding(10)
                        }
                        .background(Color.black.opacity(0.85))
                        .onChange(of: logger.logs.count) {
                            if let first = logger.logs.first {
                                withAnimation { proxy.scrollTo(first.id, anchor: .top) }
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                .padding()
                .padding(.top, 40) // Don't cover status bar area
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
            }
            
            // Invisible trigger area (Trojí klepnutí vlevo nahoře)
            // Fix: Added frame(maxWidth: infinity) to ensure ZStack fills the screen
            // so topLeading is truly top-left.
            Rectangle()
                .fill(Color.black.opacity(0.001)) // Almost transparent but clickable
                .frame(width: 80, height: 80)
                .onTapGesture(count: 3) {
                    withAnimation(.spring()) { isVisible.toggle() }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(true) // Ensure it captures taps
    }
}
