import AppKit
import SwiftUI

public struct ContentView: View {
    @ObservedObject var project: CollageProject
    let onBackHome: () -> Void

    public init(project: CollageProject, onBackHome: @escaping () -> Void) {
        self.project = project
        self.onBackHome = onBackHome
    }

    public var body: some View {
        VStack(spacing: 0) {
            topToolbar
            Divider()
            HStack(spacing: 0) {
                SidebarControlsView(project: project)
                Divider()
                VStack(spacing: 0) {
                    CollageCanvasView(project: project)
                    Divider()
                    playbackBar
                }
                Divider()
                SlotInspectorView(project: project)
            }
        }
        .frame(minWidth: 960, minHeight: 660)
        .sheet(isPresented: $project.isExporting) {
            ExportProgressSheet(project: project)
        }
        .alert("ส่งออกวิดีโอเสร็จแล้ว!", isPresented: Binding(
            get: { project.exportedURL != nil },
            set: { if !$0 { project.exportedURL = nil } }
        )) {
            Button("เปิดดูใน Finder") {
                if let url = project.exportedURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                project.exportedURL = nil
            }
            Button("ตกลง", role: .cancel) {
                project.exportedURL = nil
            }
        } message: {
            if let url = project.exportedURL {
                Text("บันทึกไฟล์ที่ \(url.lastPathComponent) เรียบร้อยแล้ว พร้อมอัปโหลดลง TikTok / IG ได้เลย")
            }
        }
        .alert("เกิดข้อผิดพลาด", isPresented: Binding(
            get: { project.exportErrorMessage != nil },
            set: { if !$0 { project.exportErrorMessage = nil } }
        )) {
            Button("ตกลง", role: .cancel) {
                project.exportErrorMessage = nil
            }
        } message: {
            Text(project.exportErrorMessage ?? "")
        }
    }

    private var topToolbar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Button(action: onBackHome) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.bold))
                        Text("หน้าแรก")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .help("กลับไปหน้าแรก (⌘⇧H)")

                Divider()
                    .frame(height: 18)

                HStack(spacing: 6) {
                    Image(systemName: "rectangle.split.2x2.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                    Text("Collage")
                        .font(.headline)
                }
            }

            Spacer()

            // Aspect ratio selector
            HStack(spacing: 6) {
                ForEach(AspectRatioPreset.allCases) { preset in
                    let selected = project.aspectRatio == preset
                    Button {
                        project.aspectRatio = preset
                    } label: {
                        HStack(spacing: 5) {
                            Text(preset.title)
                                .font(.caption.bold())
                            Text(preset.subtitle)
                                .font(.caption2)
                                .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            selected ? Color.accentColor : Color.secondary.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                        .foregroundStyle(selected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button {
                project.presentExportPanel()
            } label: {
                Label("Export MP4", systemImage: "square.and.arrow.up.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!project.hasAnyVideo || project.isExporting)
            .keyboardShortcut("e", modifiers: [.command])
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var playbackBar: some View {
        HStack(spacing: 12) {
            Button {
                project.togglePlayPause()
            } label: {
                Image(systemName: project.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(project.hasAnyVideo ? 0.18 : 0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!project.hasAnyVideo)
            .keyboardShortcut(.space, modifiers: [])

            Text(CollageProject.formatTime(project.currentTime))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)

            Slider(
                value: Binding(
                    get: { project.currentTime },
                    set: { newTime in
                        project.pause()
                        project.seek(to: newTime)
                    }
                ),
                in: 0...max(0.1, project.targetDuration)
            )
            .disabled(!project.hasAnyVideo)

            Text(CollageProject.formatTime(project.targetDuration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            Text("\(Int(project.aspectRatio.renderSize.width))×\(Int(project.aspectRatio.renderSize.height))")
                .font(.caption2.monospacedDigit())
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct ExportProgressSheet: View {
    @ObservedObject var project: CollageProject

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "film.stack")
                .font(.system(size: 36))
                .foregroundStyle(Color.accentColor)

            Text("กำลังส่งออกวิดีโอคอลลาจ...")
                .font(.headline)

            ProgressView(value: project.exportProgress, total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 280)

            Text("\(Int(project.exportProgress * 100))%  •  1080p MP4 (H.264)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Button("ยกเลิก", role: .cancel) {
                project.cancelExport()
            }
            .controlSize(.regular)
        }
        .padding(28)
        .frame(width: 360)
    }
}
