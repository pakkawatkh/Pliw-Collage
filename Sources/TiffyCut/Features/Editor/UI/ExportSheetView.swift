import SwiftUI

public struct ExportSheetView: View {
    @ObservedObject var project: TimelineProject

    public init(project: TimelineProject) {
        self.project = project
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("ส่งออกวิดีโอ (Export)", systemImage: "square.and.arrow.up.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if !project.isExporting {
                    Button {
                        project.showExportSheet = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().overlay(CapCutTheme.border)

            if project.isExporting {
                VStack(spacing: 16) {
                    ProgressView(value: project.exportProgress, total: 1.0)
                        .tint(CapCutTheme.cyan)
                    Text("กำลังเรนเดอร์ MP4... \(Int(project.exportProgress * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white)
                    Button("ยกเลิกการส่งออก", role: .cancel) {
                        project.cancelExport()
                    }
                }
                .padding(.vertical, 24)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ชื่อไฟล์")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                        TextField("tiffy-cut-video", text: $project.exportSettings.fileName)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("ความละเอียด")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                        Spacer()
                        Picker("", selection: $project.exportSettings.resolution) {
                            ForEach(ExportResolution.allCases) { res in
                                Text(res.rawValue).tag(res)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }

                    HStack {
                        Text("เฟรมเรต (FPS)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                        Spacer()
                        Picker("", selection: $project.exportSettings.frameRate) {
                            Text("24 fps").tag(Int32(24))
                            Text("30 fps").tag(Int32(30))
                            Text("60 fps").tag(Int32(60))
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }

                    HStack {
                        Text("โค้ดวิดีโอ (Codec)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                        Spacer()
                        Picker("", selection: $project.exportSettings.codec) {
                            ForEach(ExportCodec.allCases) { codec in
                                Text(codec.rawValue).tag(codec)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                }

                Divider().overlay(CapCutTheme.border)

                HStack {
                    Text("ความยาว: \(TimelineProject.formatTimecode(project.totalDuration))  •  MP4")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Button("ยกเลิก") {
                        project.showExportSheet = false
                    }
                    Button {
                        project.runExportWithSavePanel()
                    } label: {
                        Text("ส่งออก (Export)")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(CapCutTheme.cyan, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(22)
        .frame(width: 420)
        .background(CapCutTheme.bgPanel)
    }
}
