// AppLogger.swift
import Foundation
import SwiftUI

/// Jednoduchý logger, který ukládá zprávy i do paměti pro zobrazení v UI (pro debugování na Windows)
final class AppLogger: ObservableObject {
    static let shared = AppLogger()
    
    @Published var logs: [LogEntry] = []
    private let maxLogs = 100
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let message: String
        let type: LogType
    }
    
    enum LogType { case info, success, error, warning }
    
    func log(_ message: String, type: LogType = .info) {
        print("\(type == .error ? "❌" : (type == .success ? "✅" : "ℹ️")) \(message)")
        
        DispatchQueue.main.async {
            self.logs.insert(LogEntry(message: message, type: type), at: 0)
            if self.logs.count > self.maxLogs {
                self.logs.removeLast()
            }
        }
    }
}

/// Překryvná vrstva pro zobrazení logů přímo v aplikaci
struct DebugOverlayView: View {
    @ObservedObject var logger = AppLogger.shared
    @State private var isVisible = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if isVisible {
                VStack(spacing: 0) {
                    HStack {
                        Text("Thor Debug Console")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        Spacer()
                        Button("Smazat") { logger.logs.removeAll() }
                            .font(.system(size: 12))
                        Button("Zavřít") { isVisible = false }
                            .font(.system(size: 12))
                            .padding(.leading, 10)
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.9))
                    .foregroundColor(.white)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(logger.logs) { entry in
                                HStack(alignment: .top, spacing: 5) {
                                    Text(entry.timestamp, style: .time)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.gray)
                                    
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
                                        .foregroundColor(color)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Divider().background(Color.gray.opacity(0.3))
                            }
                        }
                        .padding(10)
                    }
                    .background(Color.black.opacity(0.85))
                }
                .frame(maxHeight: 400)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.5), lineWidth: 1))
                .padding()
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
            }
            
            // Neviditelné tlačítko pro vyvolání (trojí klepnutí vlevo nahoře)
            Color.clear
                .frame(width: 60, height: 60)
                .contentShape(Rectangle())
                .onTapGesture(count: 3) {
                    withAnimation(.spring()) { isVisible.toggle() }
                }
        }
    }
}
