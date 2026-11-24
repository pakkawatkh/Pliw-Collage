import AppKit
import SwiftUI

public enum TiffyCutFeature: String, CaseIterable, Identifiable {
    case editor
    case collage

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .editor: return "Video Editor"
        case .collage: return "Collage"
        }
    }

    public var iconName: String {
        switch self {
        case .editor: return "scissors"
        case .collage: return "rectangle.split.2x2.fill"
        }
    }
}

public enum TiffyCutRoute: Equatable {
    case home
    case feature(TiffyCutFeature)
}

final class TiffyCutAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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
struct TiffyCutApp: App {
    @NSApplicationDelegateAdaptor(TiffyCutAppDelegate.self) private var appDelegate
    @StateObject private var timelineProject = TimelineProject()
    @StateObject private var collageProject = CollageProject()
    @State private var route: TiffyCutRoute = .home

    var body: some Scene {
        WindowGroup("Tiffy Cut") {
            Group {
                switch route {
                case .home:
                    HomeView(
                        timelineProject: timelineProject,
                        collageProject: collageProject,
                        onStartNewProject: {
                            timelineProject.createNewProject()
                            route = .feature(.editor)
                        },
                        onOpenProject: { snapshot in
                            timelineProject.loadSnapshot(snapshot)
                            route = .feature(.editor)
                        },
                        onOpenCollage: {
                            route = .feature(.collage)
                        }
                    )
                case .feature(let feature):
                    switch feature {
                    case .editor:
                        EditorWorkspaceView(
                            project: timelineProject,
                            onBackHome: {
                                timelineProject.pause()
                                route = .home
                            }
                        )
                    case .collage:
                        ContentView(
                            project: collageProject,
                            onBackHome: {
                                collageProject.pause()
                                route = .home
                            }
                        )
                    }
                }
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 780)
        .commands {
            CommandGroup(after: .newItem) {
                Button("หน้าแรก (Home)") {
                    timelineProject.pause()
                    collageProject.pause()
                    route = .home
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(route == .home)

                Divider()

                Button("Export MP4...") {
                    switch route {
                    case .feature(.editor):
                        timelineProject.exportSettings.fileName = timelineProject.projectName
                        timelineProject.showExportSheet = true
                    case .feature(.collage):
                        collageProject.presentExportPanel()
                    case .home:
                        break
                    }
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(route == .home)
            }
        }
    }
}
