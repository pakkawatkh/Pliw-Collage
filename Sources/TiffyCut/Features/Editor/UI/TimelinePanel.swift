import SwiftUI

public struct TimelinePanel: View {
    @ObservedObject var project: TimelineProject

    private let trackHeaderWidth: CGFloat = 86
    private let rulerHeight: CGFloat = 26

    public init(project: TimelineProject) {
        self.project = project
    }

    private var timelineWidth: CGFloat {
        let minSec = max(20.0, project.totalDuration + 10.0)
        return CGFloat(minSec) * project.timelineZoom
    }

    public var body: some View {
        VStack(spacing: 0) {
            timelineToolbar
            Divider().overlay(CapCutTheme.border)

            HStack(spacing: 0) {
                // Fixed left track headers
                VStack(spacing: 0) {
                    Color.clear.frame(height: rulerHeight)
                    Divider().overlay(CapCutTheme.border)
                    trackHeader(title: "ข้อความ", icon: "textformat", color: .orange, height: 34)
                    Divider().overlay(CapCutTheme.border)
                    trackHeader(title: "ซ้อนภาพ", icon: "square.on.square", color: .purple, height: 42)
                    Divider().overlay(CapCutTheme.border)
                    trackHeader(title: "วิดีโอหลัก", icon: "film", color: CapCutTheme.cyan, height: 54)
                    Divider().overlay(CapCutTheme.border)
                    trackHeader(title: "เสียง", icon: "waveform", color: .green, height: 38)
                    Spacer(minLength: 0)
                }
                .frame(width: trackHeaderWidth)
                .background(CapCutTheme.bgPanel)

                Divider().overlay(CapCutTheme.border)

                // Scrollable timeline canvas with ruler, lanes, and cyan playhead
                ScrollView(.horizontal, showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            timeRuler
                            Divider().overlay(CapCutTheme.border)
                            trackLane(kind: .text, height: 34, color: .orange)
                            Divider().overlay(CapCutTheme.border)
                            trackLane(kind: .overlayVideo, height: 42, color: .purple)
                            Divider().overlay(CapCutTheme.border)
                            trackLane(kind: .mainVideo, height: 54, color: CapCutTheme.cyan)
                            Divider().overlay(CapCutTheme.border)
                            trackLane(kind: .audio, height: 38, color: .green)
                            Spacer(minLength: 0)
                        }
                        .frame(width: timelineWidth, alignment: .topLeading)

                        // Draggable Cyan Playhead
                        playheadOverlay
                    }
                    .frame(width: timelineWidth, alignment: .topLeading)
                }
                .background(CapCutTheme.bgBase)
            }
        }
        .background(CapCutTheme.bgPanel)
    }

    private var timelineToolbar: some View {
        HStack(spacing: 10) {
            toolbarButton(icon: "arrow.uturn.backward", help: "เลิกทำ (⌘Z)", disabled: !project.canUndo) {
                project.undo()
            }
            .keyboardShortcut("z", modifiers: [.command])

            toolbarButton(icon: "arrow.uturn.forward", help: "ทำซ้ำ (⌘⇧Z)", disabled: !project.canRedo) {
                project.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])

            Divider().frame(height: 16).overlay(CapCutTheme.border)

            // Split button (CapCut's signature ⌘B)
            Button {
                project.splitAtPlayhead()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "scissors")
                    Text("แบ่งคลิป")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("b", modifiers: [.command])
            .help("ตัดแบ่งคลิปตรงหัวอ่าน (⌘B)")

            toolbarButton(icon: "plus.square.on.square", help: "ทำซ้ำคลิป (⌘D)", disabled: project.selectedClip == nil) {
                project.duplicateSelectedClip()
            }
            .keyboardShortcut("d", modifiers: [.command])

            toolbarButton(icon: "trash", help: "ลบคลิปที่เลือก (⌘⌫)", disabled: project.selectedClip == nil) {
                project.deleteSelectedClip()
            }
            .keyboardShortcut(.delete, modifiers: [.command])

            Divider().frame(height: 16).overlay(CapCutTheme.border)

            Button {
                project.isMagneticMainTrack.toggle()
                if project.isMagneticMainTrack {
                    project.packMainVideoTrack()
                    project.schedulePlayerRebuild()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "magnet")
                    Text("แม่เหล็กแทร็กหลัก")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(project.isMagneticMainTrack ? CapCutTheme.cyan.opacity(0.2) : CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(project.isMagneticMainTrack ? CapCutTheme.cyan : .white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Spacer()

            // Timeline zoom slider
            HStack(spacing: 6) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                Slider(value: $project.timelineZoom, in: 20...160)
                    .frame(width: 110)
                    .tint(CapCutTheme.cyan)
                Image(systemName: "plus.magnifyingglass")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(CapCutTheme.bgPanel)
    }

    private func toolbarButton(icon: String, help: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 26, height: 24)
                .background(CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(disabled ? .white.opacity(0.25) : .white.opacity(0.9))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
    }

    private func trackHeader(title: String, icon: String, color: Color, height: CGFloat) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: height)
    }

    private var timeRuler: some View {
        let totalSecs = Int(ceil(timelineWidth / project.timelineZoom))
        let step = project.timelineZoom < 35 ? 5 : (project.timelineZoom < 65 ? 2 : 1)

        return ZStack(alignment: .bottomLeading) {
            CapCutTheme.bgPanel
            ForEach(Array(stride(from: 0, through: totalSecs, by: step)), id: \.self) { sec in
                let x = CGFloat(sec) * project.timelineZoom
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%02d:%02d", sec / 60, sec % 60))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 1, height: 6)
                }
                .offset(x: x + 2)
            }
        }
        .frame(height: rulerHeight)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    project.pause()
                    let t = Double(max(0, value.location.x) / project.timelineZoom)
                    project.seek(to: t)
                }
        )
    }

    private func trackLane(kind: TrackKind, height: CGFloat, color: Color) -> some View {
        let laneClips = project.clips.filter { $0.trackKind == kind }
        return ZStack(alignment: .leading) {
            Color.clear
                .frame(height: height)
                .contentShape(Rectangle())
                .onTapGesture {
                    project.selectedClipID = nil
                }

            ForEach(laneClips) { clip in
                TimelineClipBar(
                    clip: clip,
                    zoom: project.timelineZoom,
                    height: height - 8,
                    accentColor: color,
                    isSelected: project.selectedClipID == clip.id,
                    thumbnail: clip.mediaID.flatMap { project.thumbnails[$0] },
                    onSelect: { project.selectedClipID = clip.id },
                    onMove: { newStart in project.moveClip(id: clip.id, newStartTime: newStart) },
                    onTrimEnd: { newDur in project.trimClipEnd(id: clip.id, newDuration: newDur) }
                )
                .offset(x: CGFloat(clip.startTime) * project.timelineZoom)
            }
        }
        .frame(height: height)
    }

    private var playheadOverlay: some View {
        let x = CGFloat(project.currentTime) * project.timelineZoom
        return VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(CapCutTheme.cyan)
                .frame(width: 11, height: 13)
            Rectangle()
                .fill(CapCutTheme.cyan)
                .frame(width: 2)
        }
        .frame(maxHeight: .infinity)
        .offset(x: x - 5.5)
        .allowsHitTesting(false)
    }
}

private struct TimelineClipBar: View {
    let clip: TimelineClip
    let zoom: CGFloat
    let height: CGFloat
    let accentColor: Color
    let isSelected: Bool
    let thumbnail: NSImage?
    let onSelect: () -> Void
    let onMove: (Double) -> Void
    let onTrimEnd: (Double) -> Void

    @State private var dragStartTime: Double?
    @State private var trimStartDuration: Double?

    private var barWidth: CGFloat {
        max(22, CGFloat(clip.duration) * zoom)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(accentColor.opacity(0.28))

            HStack(spacing: 6) {
                if let img = thumbnail, barWidth > 54 {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 34, height: height - 4)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(clip.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if height > 36 {
                        Text(String(format: "%.1fs%@", clip.duration, abs(clip.speed - 1.0) > 0.05 ? String(format: " • %.1fx", clip.speed) : ""))
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 6)

            // Right-edge Trim Handle
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.45))
                    .frame(width: 6, height: height - 6)
                    .padding(.trailing, 2)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if trimStartDuration == nil {
                                    trimStartDuration = clip.duration
                                }
                                let deltaSec = Double(value.translation.width / zoom)
                                onTrimEnd((trimStartDuration ?? clip.duration) + deltaSec)
                            }
                            .onEnded { _ in
                                trimStartDuration = nil
                            }
                    )
            }
        }
        .frame(width: barWidth, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Color.white : accentColor.opacity(0.7), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    if dragStartTime == nil {
                        onSelect()
                        dragStartTime = clip.startTime
                    }
                    let deltaSec = Double(value.translation.width / zoom)
                    onMove(max(0, (dragStartTime ?? clip.startTime) + deltaSec))
                }
                .onEnded { _ in
                    dragStartTime = nil
                }
        )
    }
}
