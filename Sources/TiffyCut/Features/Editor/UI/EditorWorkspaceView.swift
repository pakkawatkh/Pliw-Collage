import AppKit
import SwiftUI

public struct EditorWorkspaceView: View {
    @ObservedObject var project: TimelineProject
    let onBackHome: () -> Void
    @State private var isEditingTitle = false

    public init(project: TimelineProject, onBackHome: @escaping () -> Void) {
        self.project = project
        self.onBackHome = onBackHome
    }

    public var body: some View {
        VStack(spacing: 0) {
            topHeaderBar
            Divider().overlay(CapCutTheme.border)

            // Upper 3-Pane Row (CapCut Desktop Layout: Media | Player | Inspector)
            HStack(spacing: 0) {
                MediaLibraryPanel(project: project)
                    .frame(width: 280)

                Divider().overlay(CapCutTheme.border)

                PreviewPlayerPanel(project: project)
                    .frame(minWidth: 360, maxWidth: .infinity)

                Divider().overlay(CapCutTheme.border)

                InspectorPanel(project: project)
                    .frame(width: 270)
            }
            .frame(minHeight: 360, maxHeight: .infinity)

            Divider().overlay(CapCutTheme.border)

            // Bottom Full-Width Multi-Track Timeline
            TimelinePanel(project: project)
                .frame(height: 245)
        }
        .frame(minWidth: 1080, minHeight: 700)
        .background(CapCutTheme.bgBase)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $project.showExportSheet) {
            ExportSheetView(project: project)
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
                Text("บันทึกไฟล์ \(url.lastPathComponent) เรียบร้อยแล้ว")
            }
        }
        .alert("เกิดข้อผิดพลาด", isPresented: Binding(
            get: { project.errorMessage != nil },
            set: { if !$0 { project.errorMessage = nil } }
        )) {
            Button("ตกลง", role: .cancel) {
                project.errorMessage = nil
            }
        } message: {
            Text(project.errorMessage ?? "")
        }
    }

    private var topHeaderBar: some View {
        HStack(spacing: 12) {
            Button {
                project.saveCurrentProject()
                onBackHome()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                    Text("หน้าแรก")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Image(systemName: "scissors")
                    .foregroundStyle(CapCutTheme.cyan)
                Text("tiffy-cut")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }

            Spacer()

            if isEditingTitle {
                TextField("ชื่อโปรเจกต์", text: $project.projectName)
                    .textFieldStyle(.plain)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(maxWidth: 240)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 6))
                    .onSubmit {
                        isEditingTitle = false
                        NSApp.keyWindow?.makeFirstResponder(nil)
                    }
            } else {
                Button {
                    isEditingTitle = true
                } label: {
                    HStack(spacing: 5) {
                        Text(project.projectName.isEmpty ? "โปรเจกต์ใหม่" : project.projectName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(CapCutTheme.bgElevated.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("คลิกเพื่อเปลี่ยนชื่อโปรเจกต์")
            }

            Spacer()

            Button {
                project.saveCurrentProject()
            } label: {
                Label("บันทึก", systemImage: "square.and.arrow.down")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 7))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("s", modifiers: [.command])

            Button {
                project.exportSettings.fileName = project.projectName
                project.showExportSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption.weight(.bold))
                    Text("ส่งออก (Export)")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(project.hasVisualContent ? CapCutTheme.cyan : CapCutTheme.cyan.opacity(0.3), in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .disabled(!project.hasVisualContent || project.isExporting)
            .keyboardShortcut("e", modifiers: [.command])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(CapCutTheme.bgPanel)
    }
}
