import SwiftUI
import AppKit
import CleanMacCore

/// Application lifecycle delegate ensuring closing and reopening the app window always works reliably on macOS.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private weak var mainWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Observe window creation and attach lifecycle preservation
        DispatchQueue.main.async { [weak self] in
            self?.configureMainWindowIfNeeded()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            Task { @MainActor in
                self?.registerMainWindow(window)
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app active in Dock so clicking the Dock icon or Spotlight immediately reopens the window
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // If no window is currently visible when the user activates the app (e.g. via Cmd+Tab or Dock click), restore it
        let hasVisibleContentWindow = NSApp.windows.contains { isContentWindow($0) && $0.isVisible }
        if !hasVisibleContentWindow {
            showMainWindow()
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if isContentWindow(sender) {
            // Hide the window cleanly instead of destroying its SwiftUI hosting controller,
            // so reopening from the Dock or Spotlight is instant and preserves app state.
            sender.orderOut(nil)
            return false
        }
        return true
    }
    
    func showMainWindow() {
        configureMainWindowIfNeeded()
        if let window = mainWindow ?? NSApp.windows.first(where: { isContentWindow($0) }) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func configureMainWindowIfNeeded() {
        for window in NSApp.windows where isContentWindow(window) {
            registerMainWindow(window)
        }
    }
    
    private func registerMainWindow(_ window: NSWindow) {
        guard isContentWindow(window) else { return }
        mainWindow = window
        window.isReleasedWhenClosed = false
        if window.delegate !== self {
            window.delegate = self
        }
    }
    
    private func isContentWindow(_ window: NSWindow) -> Bool {
        guard !(window is NSPanel) else { return false }
        let className = String(describing: type(of: window))
        if className.contains("StatusBar") || className.contains("MenuBar") || className.contains("Popup") {
            return false
        }
        return window.styleMask.contains(.titled)
    }
}

@main
struct CleanMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        Window("CleanMac", id: "main") {
            MainView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 960, height: 640)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("Show CleanMac Window") {
                    appDelegate.showMainWindow()
                }
                .keyboardShortcut("0", modifiers: [.command])
            }
        }
    }
}
