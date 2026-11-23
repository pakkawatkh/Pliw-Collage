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

@main
struct TiffyCutApp: App {
    @StateObject private var collageProject = CollageProject()
    @State private var activeFeature: TiffyCutFeature = .collage

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("tiffy-cut") {
            switch activeFeature {
            case .collage:
                ContentView(project: collageProject, activeFeature: $activeFeature)
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1120, height: 760)
        .commands {
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
