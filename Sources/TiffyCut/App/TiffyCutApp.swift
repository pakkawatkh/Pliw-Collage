import AppKit
import SwiftUI

public enum TiffyCutFeature: String, CaseIterable, Identifiable {
    case collage

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .collage: return "Collage"
        }
    }

    public var iconName: String {
        switch self {
        case .collage: return "rectangle.split.2x2.fill"
        }
    }
}

public enum TiffyCutRoute: Equatable {
    case home
    case feature(TiffyCutFeature)
}

@main
struct TiffyCutApp: App {
    @StateObject private var collageProject = CollageProject()
    @State private var route: TiffyCutRoute = .home

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("tiffy-cut") {
            Group {
                switch route {
                case .home:
                    HomeView(collageProject: collageProject) { feature in
                        route = .feature(feature)
                    }
                case .feature(let feature):
                    switch feature {
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
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(after: .newItem) {
                Button("หน้าแรก (Home)") {
                    collageProject.pause()
                    route = .home
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(route == .home)

                Divider()

                Button("Export MP4...") {
                    collageProject.presentExportPanel()
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(route != .feature(.collage) || !collageProject.hasAnyVideo || collageProject.isExporting)
            }
        }
    }
}
