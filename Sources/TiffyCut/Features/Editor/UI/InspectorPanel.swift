import SwiftUI

public struct InspectorPanel: View {
    @ObservedObject var project: TimelineProject
    @State private var videoTab: VideoInspectorTab = .video

    private enum VideoInspectorTab: String, CaseIterable {
        case video = "วิดีโอ"
        case audio = "เสียง"
        case speed = "ความเร็ว"
        case adjust = "ปรับสี"
    }

    public init(project: TimelineProject) {
        self.project = project
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let clip = project.selectedClip {
                if clip.trackKind == .text {
                    textInspector(clip: clip)
                } else if clip.trackKind == .audio {
                    audioOnlyInspector(clip: clip)
                } else {
                    videoClipInspector(clip: clip)
                }
            } else {
                projectSettingsInspector
            }
        }
        .background(CapCutTheme.bgPanel)
    }

    private func videoClipInspector(clip: TimelineClip) -> some View {
        VStack(spacing: 0) {
            // CapCut-style inspector tabs
            HStack(spacing: 4) {
                ForEach(VideoInspectorTab.allCases, id: \.self) { tab in
                    let active = videoTab == tab
                    Button {
                        videoTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: active ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(active ? CapCutTheme.cyan : .white.opacity(0.65))
                            .overlay(alignment: .bottom) {
                                if active {
                                    Rectangle()
                                        .fill(CapCutTheme.cyan)
                                        .frame(height: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)

            Divider().overlay(CapCutTheme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch videoTab {
                    case .video:
                        videoTransformControls(clip: clip)
                    case .audio:
                        audioControls(clip: clip)
                    case .speed:
                        speedControls(clip: clip)
                    case .adjust:
                        colorControls(clip: clip)
                    }
                }
                .padding(14)
            }
        }
    }

    private func videoTransformControls(clip: TimelineClip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ปรับขนาดและตำแหน่ง")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Spacer()
                Button("รีเซ็ต") {
                    project.updateSelectedClip({
                        $0.scale = 1.0
                        $0.positionX = 0
                        $0.positionY = 0
                        $0.rotationDegrees = 0
                        $0.opacity = 1.0
                        $0.isFlippedHorizontal = false
                    }, commitUndo: true)
                }
                .buttonStyle(.borderless)
                .font(.caption2)
                .foregroundStyle(CapCutTheme.cyan)
            }

            inspectorSlider(
                label: "ขนาด (Scale)",
                valueText: "\(Int(clip.scale * 100))%",
                value: Binding(
                    get: { Double(clip.scale) },
                    set: { val in project.updateSelectedClip { $0.scale = CGFloat(val) } }
                ),
                range: 0.1...3.0
            )

            inspectorSlider(
                label: "ตำแหน่ง X",
                valueText: "\(Int(clip.positionX * 100))%",
                value: Binding(
                    get: { Double(clip.positionX) },
                    set: { val in project.updateSelectedClip { $0.positionX = CGFloat(val) } }
                ),
                range: -1.0...1.0
            )

            inspectorSlider(
                label: "ตำแหน่ง Y",
                valueText: "\(Int(clip.positionY * 100))%",
                value: Binding(
                    get: { Double(clip.positionY) },
                    set: { val in project.updateSelectedClip { $0.positionY = CGFloat(val) } }
                ),
                range: -1.0...1.0
            )

            inspectorSlider(
                label: "หมุน (Rotate)",
                valueText: "\(Int(clip.rotationDegrees))°",
                value: Binding(
                    get: { clip.rotationDegrees },
                    set: { val in project.updateSelectedClip { $0.rotationDegrees = val } }
                ),
                range: -180...180
            )

            inspectorSlider(
                label: "ความทึบแสง (Opacity)",
                valueText: "\(Int(clip.opacity * 100))%",
                value: Binding(
                    get: { clip.opacity },
                    set: { val in project.updateSelectedClip { $0.opacity = val } }
                ),
                range: 0.0...1.0
            )

            Toggle(isOn: Binding(
                get: { clip.isFlippedHorizontal },
                set: { val in project.updateSelectedClip({ $0.isFlippedHorizontal = val }, commitUndo: true) }
            )) {
                Text("กลับด้านซ้าย-ขวา (Mirror)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private func audioControls(clip: TimelineClip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(
                get: { !clip.isMuted },
                set: { enabled in project.updateSelectedClip({ $0.isMuted = !enabled }, commitUndo: true) }
            )) {
                Text(clip.isMuted ? "ปิดเสียงอยู่" : "เปิดเสียง")
                    .font(.caption)
                    .foregroundStyle(.white)
            }

            if !clip.isMuted {
                inspectorSlider(
                    label: "ระดับเสียง",
                    valueText: "\(Int(clip.volume * 100))%",
                    value: Binding(
                        get: { Double(clip.volume) },
                        set: { val in project.updateSelectedClip { $0.volume = Float(val) } }
                    ),
                    range: 0.0...2.0
                )

                inspectorSlider(
                    label: "เฟดเสียงเข้า (Fade In)",
                    valueText: String(format: "%.1fs", clip.fadeInDuration),
                    value: Binding(
                        get: { clip.fadeInDuration },
                        set: { val in project.updateSelectedClip { $0.fadeInDuration = val } }
                    ),
                    range: 0.0...min(3.0, clip.duration * 0.5)
                )

                inspectorSlider(
                    label: "เฟดเสียงออก (Fade Out)",
                    valueText: String(format: "%.1fs", clip.fadeOutDuration),
                    value: Binding(
                        get: { clip.fadeOutDuration },
                        set: { val in project.updateSelectedClip { $0.fadeOutDuration = val } }
                    ),
                    range: 0.0...min(3.0, clip.duration * 0.5)
                )
            }
        }
    }

    private func audioOnlyInspector(clip: TimelineClip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label("แทร็กเสียง", systemImage: "waveform")
                    .font(.headline)
                    .foregroundStyle(CapCutTheme.cyan)
                Text(clip.title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Divider().overlay(CapCutTheme.border)
                audioControls(clip: clip)
            }
            .padding(14)
        }
    }

    private func speedControls(clip: TimelineClip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            inspectorSlider(
                label: "ความเร็ว (Speed)",
                valueText: String(format: "%.2fx", clip.speed),
                value: Binding(
                    get: { clip.speed },
                    set: { val in project.updateSelectedClip { $0.speed = val } }
                ),
                range: 0.25...4.0
            )

            HStack(spacing: 6) {
                ForEach([0.5, 1.0, 1.5, 2.0, 3.0], id: \.self) { sp in
                    Button("\(sp == 1.0 ? "1x" : String(format: "%.1fx", sp))") {
                        project.updateSelectedClip({ $0.speed = sp }, commitUndo: true)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(abs(clip.speed - sp) < 0.05 ? CapCutTheme.cyan : nil)
                }
            }

            Text("ความยาวบนไทม์ไลน์: \(TimelineProject.formatTimecode(clip.duration))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func colorControls(clip: TimelineClip) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ปรับแต่งสี")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                Spacer()
                Button("รีเซ็ต") {
                    project.updateSelectedClip({ $0.adjustments = ColorAdjustments() }, commitUndo: true)
                }
                .buttonStyle(.borderless)
                .font(.caption2)
                .foregroundStyle(CapCutTheme.cyan)
            }

            inspectorSlider(
                label: "ความสว่าง (Brightness)",
                valueText: String(format: "%.0f", clip.adjustments.brightness * 100),
                value: Binding(
                    get: { clip.adjustments.brightness },
                    set: { val in project.updateSelectedClip { $0.adjustments.brightness = val } }
                ),
                range: -0.4...0.4
            )

            inspectorSlider(
                label: "คอนทราสต์ (Contrast)",
                valueText: "\(Int(clip.adjustments.contrast * 100))%",
                value: Binding(
                    get: { clip.adjustments.contrast },
                    set: { val in project.updateSelectedClip { $0.adjustments.contrast = val } }
                ),
                range: 0.5...1.6
            )

            inspectorSlider(
                label: "ความอิ่มสี (Saturation)",
                valueText: "\(Int(clip.adjustments.saturation * 100))%",
                value: Binding(
                    get: { clip.adjustments.saturation },
                    set: { val in project.updateSelectedClip { $0.adjustments.saturation = val } }
                ),
                range: 0.0...2.0
            )

            inspectorSlider(
                label: "การรับแสง (Exposure)",
                valueText: String(format: "%.1f", clip.adjustments.exposure),
                value: Binding(
                    get: { clip.adjustments.exposure },
                    set: { val in project.updateSelectedClip { $0.adjustments.exposure = val } }
                ),
                range: -1.5...1.5
            )

            inspectorSlider(
                label: "อุณหภูมิสี (Temp)",
                valueText: String(format: "%.0f", clip.adjustments.temperature * 100),
                value: Binding(
                    get: { clip.adjustments.temperature },
                    set: { val in project.updateSelectedClip { $0.adjustments.temperature = val } }
                ),
                range: -1.0...1.0
            )
        }
    }

    private func textInspector(clip: TimelineClip) -> some View {
        let style = clip.textStyle ?? TextOverlayStyle()
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label("แก้ไขข้อความ", systemImage: "textformat")
                    .font(.headline)
                    .foregroundStyle(CapCutTheme.cyan)

                TextEditor(text: Binding(
                    get: { style.text },
                    set: { newText in
                        project.updateSelectedClip {
                            if $0.textStyle == nil { $0.textStyle = TextOverlayStyle() }
                            $0.textStyle?.text = newText
                            $0.title = newText.isEmpty ? "ข้อความ" : newText
                        }
                    }
                ))
                .font(.body)
                .frame(height: 74)
                .padding(6)
                .background(CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 8))

                inspectorSlider(
                    label: "ขนาดตัวอักษร",
                    valueText: "\(Int(style.fontSize)) pt",
                    value: Binding(
                        get: { Double(style.fontSize) },
                        set: { val in project.updateSelectedClip { $0.textStyle?.fontSize = CGFloat(val) } }
                    ),
                    range: 24...140
                )

                inspectorSlider(
                    label: "ตำแหน่ง X",
                    valueText: "\(Int(clip.positionX * 100))%",
                    value: Binding(
                        get: { Double(clip.positionX) },
                        set: { val in project.updateSelectedClip { $0.positionX = CGFloat(val) } }
                    ),
                    range: -0.9...0.9
                )

                inspectorSlider(
                    label: "ตำแหน่ง Y",
                    valueText: "\(Int(clip.positionY * 100))%",
                    value: Binding(
                        get: { Double(clip.positionY) },
                        set: { val in project.updateSelectedClip { $0.positionY = CGFloat(val) } }
                    ),
                    range: -0.9...0.9
                )

                inspectorSlider(
                    label: "ความทึบพื้นหลังกล่อง",
                    valueText: "\(Int(style.backgroundOpacity * 100))%",
                    value: Binding(
                        get: { style.backgroundOpacity },
                        set: { val in project.updateSelectedClip { $0.textStyle?.backgroundOpacity = val } }
                    ),
                    range: 0.0...1.0
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("สีตัวอักษร")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                    HStack(spacing: 8) {
                        ForEach(["#FFFFFF", "#FFE600", "#00D1E8", "#FF3B6B", "#111111"], id: \.self) { hex in
                            Button {
                                project.updateSelectedClip({ $0.textStyle?.textColorHex = hex }, commitUndo: true)
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle().strokeBorder(style.textColorHex == hex ? CapCutTheme.cyan : .white.opacity(0.3), lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    private var projectSettingsInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label("รายละเอียดโปรเจกต์", systemImage: "info.circle")
                    .font(.headline)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 6) {
                    Text("ชื่อโปรเจกต์")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("ชื่อโปรเจกต์", text: $project.projectName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("สัดส่วนหน้าจอ")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Picker("", selection: $project.aspectRatio) {
                        ForEach(AspectRatioPreset.allCases) { preset in
                            Text("\(preset.title) — \(preset.subtitle)").tag(preset)
                        }
                    }
                    .labelsHidden()
                }

                if project.aspectRatio == .custom {
                    HStack(spacing: 8) {
                        TextField("W", value: $project.customWidth, format: .number)
                            .textFieldStyle(.roundedBorder)
                        Text("×").foregroundStyle(.secondary)
                        TextField("H", value: $project.customHeight, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    .onChange(of: project.customWidth) { _ in project.schedulePlayerRebuild() }
                    .onChange(of: project.customHeight) { _ in project.schedulePlayerRebuild() }
                }

                Divider().overlay(CapCutTheme.border)

                HStack {
                    Text("ขนาดแคนวาส")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("\(Int(project.renderSize.width)) × \(Int(project.renderSize.height)) px")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                }

                HStack {
                    Text("จำนวนคลิป")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("\(project.clips.count) ชิ้น")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                }
            }
            .padding(14)
        }
    }

    private func inspectorSlider(
        label: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(valueText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white)
            }
            Slider(value: value, in: range)
                .tint(CapCutTheme.cyan)
        }
    }
}

private extension Color {
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
