// AgileTrainerWatchApp.swift
// Hlavní vstupní bod aplikace pro watchOS

import SwiftUI

@main
struct AgileTrainerWatchApp: App {
    @StateObject private var session = WatchSessionCoordinator.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(session)
        }
    }
}
