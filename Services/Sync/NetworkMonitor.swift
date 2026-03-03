// NetworkMonitor.swift
import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected: Bool = true
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    
    private init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = (path.status == .satisfied)
                
                // Pokus o synchronizaci dat, pokud jsme se prve připojili
                if path.status == .satisfied {
                    NotificationCenter.default.post(name: NSNotification.Name("NetworkBecameAvailable"), object: nil)
                }
            }
        }
        monitor.start(queue: queue)
    }
}
