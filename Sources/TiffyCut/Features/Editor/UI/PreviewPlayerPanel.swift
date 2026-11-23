import AppKit
import AVFoundation
import SwiftUI

public struct PreviewPlayerPanel: View {
    @ObservedObject var project: TimelineProject

    public init(project: TimelineProject) {
        self.project = project
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Player viewport
            GeometryReader { geo in
                let maxW = max(120, geo.size.width - 36)
                let maxH = max(120, geo.size.height - 28)
                let ratio = project.renderSize.width / max(1, project.renderSize.height)

                let canvasSize: CGSize = {
                    if maxW / maxH > ratio {
                        return CGSize(width: maxH * ratio, height: maxH)
                    } else {
                        return CGSize(width: maxW, height: maxW / ratio)
                    }
                }()

                ZStack {
                    if project.hasVisualContent {
                        TimelinePlayerNSView(player: project.player)
                            .allowsHitTesting(false)
                            .frame(width: canvasSize.width, height: canvasSize.height)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .shadow(color: .black.opacity(0.5), radius: 14)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black)
                            .frame(width: canvasSize.width, height: canvasSize.height)
                            .overlay(
                                VStack(spacing: 10) {
                                    Image(systemName: "play.rectangle")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.white.opacity(0.25))
                                    Text("เพิ่มคลิปลงไทม์ไลน์เพื่อเริ่มตัดต่อ")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.45))
                                }
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(CapCutTheme.bgBase)

            // CapCut-style transport bar below preview
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Text(TimelineProject.formatTimecode(project.currentTime))
                        .foregroundStyle(CapCutTheme.cyan)
                    Text("/")
                        .foregroundStyle(.white.opacity(0.35))
                    Text(TimelineProject.formatTimecode(project.totalDuration))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))

                Spacer()

                Button {
                    project.togglePlayPause()
                } label: {
                    Image(systemName: project.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(CapCutTheme.bgElevated, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!project.hasVisualContent)
                .keyboardShortcut(.space, modifiers: [])

                Spacer()

                // Aspect ratio quick menu
                Menu {
                    ForEach(AspectRatioPreset.allCases) { preset in
                        Button {
                            project.aspectRatio = preset
                        } label: {
                            if project.aspectRatio == preset {
                                Label("\(preset.title) (\(preset.subtitle))", systemImage: "checkmark")
                            } else {
                                Text("\(preset.title) (\(preset.subtitle))")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(project.aspectRatio == .custom
                             ? "\(Int(project.renderSize.width))×\(Int(project.renderSize.height))"
                             : project.aspectRatio.title)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white.opacity(0.85))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(CapCutTheme.bgPanel)
        }
    }
}

private struct TimelinePlayerNSView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerHostView {
        let v = PlayerHostView()
        v.playerLayer.player = player
        return v
    }

    func updateNSView(_ nsView: PlayerHostView, context: Context) {
        if nsView.playerLayer.player !== player {
            nsView.playerLayer.player = player
        }
    }

    final class PlayerHostView: NSView {
        let playerLayer = AVPlayerLayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.backgroundColor = NSColor.black.cgColor
            playerLayer.videoGravity = .resizeAspect
            layer?.addSublayer(playerLayer)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            playerLayer.frame = bounds
            CATransaction.commit()
        }
    }
}
