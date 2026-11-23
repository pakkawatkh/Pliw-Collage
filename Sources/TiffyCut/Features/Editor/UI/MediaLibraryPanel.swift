import SwiftUI
import UniformTypeIdentifiers

public enum CapCutTheme {
    public static let bgBase = Color(red: 0.08, green: 0.08, blue: 0.09)
    public static let bgPanel = Color(red: 0.11, green: 0.11, blue: 0.13)
    public static let bgElevated = Color(red: 0.16, green: 0.16, blue: 0.19)
    public static let border = Color.white.opacity(0.08)
    public static let cyan = Color(red: 0.0, green: 0.82, blue: 0.91)
}

public struct MediaLibraryPanel: View {
    @ObservedObject var project: TimelineProject
    @State private var selectedTab: LibraryTab = .media
    @State private var isDropTargeted = false

    private enum LibraryTab: String, CaseIterable {
        case media = "สื่อ"
        case audio = "เสียง"
        case text = "ข้อความ"
        case filters = "ฟิลเตอร์"
        case transitions = "ทรานซิชัน"

        var icon: String {
            switch self {
            case .media: return "photo.on.rectangle"
            case .audio: return "music.note"
            case .text: return "textformat"
            case .filters: return "camera.filters"
            case .transitions: return "square.2.layers.3d.top.filled"
            }
        }
    }

    public init(project: TimelineProject) {
        self.project = project
    }

    public var body: some View {
        VStack(spacing: 0) {
            // CapCut-style horizontal category tabs
            HStack(spacing: 2) {
                ForEach(LibraryTab.allCases, id: \.self) { tab in
                    let active = selectedTab == tab
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13))
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: active ? .semibold : .regular))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(active ? CapCutTheme.cyan : .white.opacity(0.65))
                        .background(active ? CapCutTheme.cyan.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(CapCutTheme.bgPanel)

            Divider().overlay(CapCutTheme.border)

            // Tab content
            Group {
                switch selectedTab {
                case .media:
                    mediaGridTab
                case .audio:
                    audioTab
                case .text:
                    textPresetsTab
                case .filters:
                    filtersTab
                case .transitions:
                    transitionsTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(CapCutTheme.bgPanel)
    }

    private var mediaGridTab: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    project.openMediaPicker(audioOnly: false)
                } label: {
                    Label("นำเข้าสื่อ (Import)", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(CapCutTheme.cyan.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(CapCutTheme.cyan)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if project.mediaItems.filter({ $0.kind != .audio }).isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(isDropTargeted ? CapCutTheme.cyan : .white.opacity(0.35))
                    Text("ลากไฟล์วิดีโอมาวางที่นี่")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.75))
                    Text("รองรับ MP4, MOV, M4V")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isDropTargeted ? CapCutTheme.cyan : Color.white.opacity(0.15),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                        )
                        .padding(12)
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(project.mediaItems.filter { $0.kind != .audio }) { item in
                            MediaCardCell(
                                item: item,
                                thumbnail: project.thumbnails[item.id],
                                onAddMain: { project.addMediaToTimeline(item, asOverlay: false) },
                                onAddOverlay: { project.addMediaToTimeline(item, asOverlay: true) }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleFileDrop(providers: providers)
        }
    }

    private var audioTab: some View {
        VStack(spacing: 12) {
            Button {
                project.openMediaPicker(audioOnly: true)
            } label: {
                Label("นำเข้าเพลง / เสียง (MP3, WAV, M4A)", systemImage: "music.note.list")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(CapCutTheme.cyan.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(CapCutTheme.cyan)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 10)

            let audioItems = project.mediaItems.filter { $0.kind == .audio }
            if audioItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("ยังไม่มีไฟล์เสียง")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(audioItems) { item in
                            HStack(spacing: 10) {
                                Image(systemName: "music.note")
                                    .foregroundStyle(CapCutTheme.cyan)
                                    .frame(width: 28, height: 28)
                                    .background(CapCutTheme.cyan.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(TimelineProject.formatTimecode(item.duration))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                Spacer()
                                Button {
                                    project.addMediaToTimeline(item, asOverlay: false)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(CapCutTheme.cyan)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleFileDrop(providers: providers)
        }
    }

    private var textPresetsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("เพิ่มข้อความลงไทม์ไลน์")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))

                let presets: [(String, String, String, String)] = [
                    ("ข้อความมาตรฐาน", "พิมพ์ข้อความที่นี่", "#FFFFFF", "#000000"),
                    ("หัวข้อเด่น (เหลือง)", "หัวข้อสำคัญ!", "#FFE600", "#000000"),
                    ("ป้ายไซแอน (TikTok)", "กดติดตามเลย!", "#00D1E8", "#111111"),
                    ("แคปชันมินิมอล", "คำบรรยายใต้คลิป", "#FFFFFF", "#222222")
                ]

                ForEach(presets, id: \.0) { preset in
                    Button {
                        project.addTextClip(text: preset.1)
                        project.updateSelectedClip { clip in
                            clip.textStyle?.textColorHex = preset.2
                            clip.textStyle?.backgroundColorHex = preset.3
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.0)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(preset.1)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(CapCutTheme.cyan)
                        }
                        .padding(10)
                        .background(CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
    }

    private var filtersTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("คลิกเพื่อใช้ฟิลเตอร์กับคลิปที่เลือก")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(FilterPreset.allCases) { preset in
                        let isActive = project.selectedClip?.adjustments.filter == preset
                        Button {
                            project.updateSelectedClip({ $0.adjustments.filter = preset }, commitUndo: true)
                        } label: {
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(filterPreviewGradient(preset))
                                    .frame(height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(isActive ? CapCutTheme.cyan : Color.clear, lineWidth: 2)
                                    )
                                Text(preset.rawValue)
                                    .font(.caption2.weight(isActive ? .bold : .regular))
                                    .foregroundStyle(isActive ? CapCutTheme.cyan : .white.opacity(0.85))
                            }
                            .padding(6)
                            .background(CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(project.selectedClip == nil)
                    }
                }
            }
            .padding(12)
        }
    }

    private var transitionsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("เลือกทรานซิชันเข้าสำหรับคลิปที่เลือก")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(TransitionType.allCases) { tr in
                        let isActive = project.selectedClip?.transitionIn == tr
                        Button {
                            project.updateSelectedClip({ $0.transitionIn = tr }, commitUndo: true)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: tr == .none ? "nosign" : "sparkles.rectangle.stack")
                                    .font(.title3)
                                    .foregroundStyle(isActive ? CapCutTheme.cyan : .white.opacity(0.7))
                                    .frame(height: 36)
                                Text(tr.rawValue)
                                    .font(.caption2.weight(isActive ? .bold : .regular))
                                    .foregroundStyle(isActive ? CapCutTheme.cyan : .white.opacity(0.85))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(CapCutTheme.bgElevated, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(isActive ? CapCutTheme.cyan : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(project.selectedClip == nil)
                    }
                }
            }
            .padding(12)
        }
    }

    private func filterPreviewGradient(_ preset: FilterPreset) -> LinearGradient {
        switch preset {
        case .none: return LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .vivid: return LinearGradient(colors: [.pink, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .warm: return LinearGradient(colors: [.orange, .red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cool: return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .bw: return LinearGradient(colors: [.white.opacity(0.85), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cinematic: return LinearGradient(colors: [.teal, .orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fade: return LinearGradient(colors: [.purple.opacity(0.5), .gray.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var resolved: URL?
                if let data = item as? Data {
                    resolved = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    resolved = url
                }
                guard let url = resolved else { return }
                Task { @MainActor in
                    project.importMedia(url: url, autoAddToTimeline: false)
                }
            }
        }
        return true
    }
}

private struct MediaCardCell: View {
    let item: MediaItem
    let thumbnail: NSImage?
    let onAddMain: () -> Void
    let onAddOverlay: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack {
                if let img = thumbnail {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(CapCutTheme.bgElevated)
                    Image(systemName: "film")
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .frame(height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(alignment: .bottomLeading) {
                Text(TimelineProject.formatTimecode(item.duration))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.white)
                    .padding(4)
            }
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 4) {
                    if isHovered {
                        Button(action: onAddOverlay) {
                            Text("PIP")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 3)
                                .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .help("เพิ่มเป็นเลเยอร์ซ้อน (Overlay)")
                    }
                    Button(action: onAddMain) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(CapCutTheme.cyan)
                            .background(Circle().fill(.black.opacity(0.7)))
                    }
                    .buttonStyle(.plain)
                    .help("เพิ่มลงแทร็กหลัก")
                }
                .padding(4)
            }

            Text(item.name)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
        .onHover { isHovered = $0 }
    }
}
