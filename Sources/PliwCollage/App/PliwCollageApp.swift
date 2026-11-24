import AppKit
import SwiftUI

final class PliwCollageAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Task { @MainActor in
            PliwCollageUpdateManager.shared.checkForUpdates(manual: false)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }
}

@main
struct PliwCollageApp: App {
    @NSApplicationDelegateAdaptor(PliwCollageAppDelegate.self) private var appDelegate
    @StateObject private var collageProject = CollageProject()

    var body: some Scene {
        WindowGroup("Pliw Collage") {
            ContentView(project: collageProject)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("ตรวจสอบอัปเดต... (Check for Updates)") {
                    PliwCollageUpdateManager.shared.checkForUpdates(manual: true)
                }
            }

            CommandGroup(after: .newItem) {
                Button("Export MP4...") {
                    collageProject.presentExportPanel()
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(!collageProject.hasAnyVideo || collageProject.isExporting)
            }
        }
    }
}
