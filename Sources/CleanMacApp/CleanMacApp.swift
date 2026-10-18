import SwiftUI
import AppKit
import CleanMacCore

@main
struct CleanMacApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        // Main Application Window
        WindowGroup {
            MainView()
                .environmentObject(appState)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }
        
        // Menu Bar Extra for quick glance and 1-click clean
        MenuBarExtra("CleanMac", systemImage: "sparkles") {
            MenuBarExtraView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
