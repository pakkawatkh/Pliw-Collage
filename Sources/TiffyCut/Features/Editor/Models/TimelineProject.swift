import AppKit
import AVFoundation
import Combine
import Foundation
import SwiftUI

@MainActor
public final class TimelineProject: ObservableObject {
    @Published public var projectID: UUID = UUID()
    @Published public var projectName: String = "โปรเจกต์ใหม่"
    @Published public var aspectRatio: AspectRatioPreset = .tiktok9x16 {
        didSet {
            if aspectRatio != .custom {
                let sz = aspectRatio.renderSize
                customWidth = Int(sz.width)
                customHeight = Int(sz.height)
            }
            schedulePlayerRebuild()
        }
    }
    @Published public var customWidth: Int = 1080
    @Published public var customHeight: Int = 1920

    @Published public var mediaItems: [MediaItem] = []
    @Published public var thumbnails: [UUID: NSImage] = [:]
    @Published public var clips: [TimelineClip] = []
    @Published public var selectedClipID: UUID?

    @Published public var isMagneticMainTrack: Bool = true
    @Published public var timelineZoom: CGFloat = 60.0 // pixels per second

    // Playback
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0
    public let player = AVPlayer()

    // Export
    @Published public var showExportSheet: Bool = false
    @Published public var exportSettings = EditorExportSettings()
    @Published public var isExporting: Bool = false
    @Published public var exportProgress: Double = 0
    @Published public var exportedURL: URL?
    @Published public var errorMessage: String?

    // Undo / Redo
    @Published public private(set) var canUndo: Bool = false
    @Published public private(set) var canRedo: Bool = false
    private var undoStack: [[TimelineClip]] = []
    private var redoStack: [[TimelineClip]] = []

    // Saved recent projects
    @Published public var recentProjects: [TimelineSnapshot] = []

    private var timeObserverToken: Any?
    private var rebuildTask: Task<Void, Never>?
    private let exporter = TimelineExporter()

    public init() {
        setupTimeObserver()
        loadRecentProjectsList()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    public var renderSize: CGSize {
        if aspectRatio == .custom {
            return CanvasDimensionHelper.sanitizedSize(width: customWidth, height: customHeight)
        }
        return aspectRatio.renderSize
    }

    public var totalDuration: Double {
        clips.map { $0.endTime }.max() ?? 0
    }

    public var selectedClipIndex: Int? {
        guard let id = selectedClipID else { return nil }
        return clips.firstIndex { $0.id == id }
    }

    public var selectedClip: TimelineClip? {
        guard let idx = selectedClipIndex else { return nil }
        return clips[idx]
    }

    public var hasVisualContent: Bool {
        clips.contains { $0.trackKind == .mainVideo || $0.trackKind == .overlayVideo }
    }

    // MARK: - Project Lifecycle

    public func createNewProject(name: String = "โปรเจกต์ใหม่", aspect: AspectRatioPreset = .tiktok9x16) {
        pause()
        projectID = UUID()
        projectName = name
        aspectRatio = aspect
        mediaItems = []
        clips = []
        selectedClipID = nil
        undoStack = []
        redoStack = []
        canUndo = false
        canRedo = false
        currentTime = 0
        player.replaceCurrentItem(with: nil)
    }

    public func loadSnapshot(_ snapshot: TimelineSnapshot) {
        pause()
        projectID = snapshot.projectID
        projectName = snapshot.projectName
        aspectRatio = snapshot.aspectRatio
        customWidth = snapshot.customWidth
        customHeight = snapshot.customHeight
        mediaItems = snapshot.mediaItems
        clips = snapshot.clips
        selectedClipID = clips.first?.id
        undoStack = []
        redoStack = []
        canUndo = false
        canRedo = false
        currentTime = 0

        for item in mediaItems where item.kind == .video {
            generateThumbnail(for: item)
        }
        schedulePlayerRebuild()
    }

    public func saveCurrentProject() {
        let snapshot = TimelineSnapshot(
            projectID: projectID,
            projectName: projectName,
            aspectRatio: aspectRatio,
            customWidth: customWidth,
            customHeight: customHeight,
            mediaItems: mediaItems,
            clips: clips,
            updatedAt: Date()
        )
        let dir = Self.projectsDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("\(projectID.uuidString).json")
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: fileURL)
        }
        loadRecentProjectsList()
    }

    public func deleteSavedProject(_ snapshot: TimelineSnapshot) {
        let fileURL = Self.projectsDirectory().appendingPathComponent("\(snapshot.projectID.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
        loadRecentProjectsList()
    }

    public func loadRecentProjectsList() {
        let dir = Self.projectsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            recentProjects = []
            return
        }
        let decoder = JSONDecoder()
        let loaded = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> TimelineSnapshot? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(TimelineSnapshot.self, from: data)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
        recentProjects = loaded
    }

    private static func projectsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("tiffy-cut/Projects", isDirectory: true)
    }

    // MARK: - Media Import

    public func openMediaPicker(audioOnly: Bool = false) {
        let panel = NSOpenPanel()
        panel.title = audioOnly ? "นำเข้าไฟล์เสียง (Audio)" : "นำเข้าสื่อ (Video / Audio)"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = audioOnly
            ? [.audio, .mp3, .mpeg4Audio, .wav]
            : [.movie, .mpeg4Movie, .quickTimeMovie, .video, .audio, .mp3, .mpeg4Audio, .wav]

        if panel.runModal() == .OK {
            for url in panel.urls {
                importMedia(url: url, autoAddToTimeline: clips.isEmpty)
            }
        }
    }

    public func importMedia(url: URL, autoAddToTimeline: Bool = false) {
        Task {
            let asset = AVURLAsset(url: url)
            do {
                let durCM = try await asset.load(.duration)
                let durSec = CMTimeGetSeconds(durCM)
                guard durSec > 0.05 else { return }

                let videoTracks = (try? await asset.loadTracks(withMediaType: .video)) ?? []
                let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []

                let kind: MediaKind = videoTracks.isEmpty ? .audio : .video
                var size = CGSize.zero
                if let vt = videoTracks.first {
                    let nat = try await vt.load(.naturalSize)
                    let tf = try await vt.load(.preferredTransform)
                    let r = CGRect(origin: .zero, size: nat).applying(tf)
                    size = CGSize(width: abs(r.width), height: abs(r.height))
                }

                let item = MediaItem(
                    url: url,
                    kind: kind,
                    duration: durSec,
                    naturalSize: size,
                    hasAudio: !audioTracks.isEmpty
                )
                self.mediaItems.append(item)
                if kind == .video {
                    self.generateThumbnail(for: item)
                }
                if autoAddToTimeline {
                    self.addMediaToTimeline(item, asOverlay: false)
                }
            } catch {
                self.errorMessage = "ไม่สามารถนำเข้าไฟล์ได้: \(error.localizedDescription)"
            }
        }
    }

    private func generateThumbnail(for item: MediaItem) {
        Task.detached {
            let asset = AVURLAsset(url: item.url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 240, height: 240)
            if let cg = try? gen.copyCGImage(at: CMTime(seconds: min(0.5, item.duration * 0.2), preferredTimescale: 600), actualTime: nil) {
                let nsImg = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                await MainActor.run { [weak self] in
                    self?.thumbnails[item.id] = nsImg
                }
            }
        }
    }

    // MARK: - Timeline Editing

    public func pushUndo() {
        undoStack.append(clips)
        if undoStack.count > 40 { undoStack.removeFirst() }
        redoStack.removeAll()
        canUndo = !undoStack.isEmpty
        canRedo = false
    }

    public func undo() {
        guard let prev = undoStack.popLast() else { return }
        redoStack.append(clips)
        clips = prev
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        schedulePlayerRebuild()
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(clips)
        clips = next
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        schedulePlayerRebuild()
    }

    public func addMediaToTimeline(_ item: MediaItem, asOverlay: Bool = false) {
        pushUndo()
        let trackKind: TrackKind
        let insertStart: Double

        if item.kind == .audio {
            trackKind = .audio
            insertStart = currentTime
        } else if asOverlay {
            trackKind = .overlayVideo
            insertStart = currentTime
        } else {
            trackKind = .mainVideo
            let mainEnd = clips.filter { $0.trackKind == .mainVideo }.map { $0.endTime }.max() ?? 0
            insertStart = mainEnd
        }

        var clip = TimelineClip(
            trackKind: trackKind,
            mediaID: item.id,
            mediaURL: item.url,
            mediaKind: item.kind,
            title: item.name,
            startTime: insertStart,
            sourceStart: 0,
            sourceDuration: item.duration,
            fullMediaDuration: item.duration
        )
        if trackKind == .overlayVideo {
            clip.scale = 0.5
        }

        clips.append(clip)
        if isMagneticMainTrack && trackKind == .mainVideo {
            packMainVideoTrack()
        }
        selectedClipID = clip.id
        schedulePlayerRebuild()
        saveCurrentProject()
    }

    public func addTextClip(text: String = "ข้อความใหม่", duration: Double = 3.0) {
        pushUndo()
        let clip = TimelineClip(
            trackKind: .text,
            title: text,
            startTime: currentTime,
            sourceStart: 0,
            sourceDuration: duration,
            fullMediaDuration: 60.0,
            textStyle: TextOverlayStyle(text: text)
        )
        clips.append(clip)
        selectedClipID = clip.id
        schedulePlayerRebuild()
        saveCurrentProject()
    }

    /// CapCut-style Split (⌘B): splits the selected clip (or the main track clip at playhead) at `currentTime`.
    @discardableResult
    public func splitAtPlayhead() -> Bool {
        let targetIndex: Int? = {
            if let idx = selectedClipIndex,
               currentTime > clips[idx].startTime + 0.1 && currentTime < clips[idx].endTime - 0.1 {
                return idx
            }
            return clips.firstIndex {
                $0.trackKind == .mainVideo && currentTime > $0.startTime + 0.1 && currentTime < $0.endTime - 0.1
            }
        }()

        guard let idx = targetIndex else { return false }
        pushUndo()

        let original = clips[idx]
        let splitOffsetTimeline = currentTime - original.startTime
        let safeSpeed = max(0.25, min(4.0, original.speed))
        let splitOffsetSource = splitOffsetTimeline * safeSpeed

        var left = original
        left.sourceDuration = max(0.1, splitOffsetSource)

        var right = TimelineClip(
            id: UUID(),
            trackKind: original.trackKind,
            mediaID: original.mediaID,
            mediaURL: original.mediaURL,
            mediaKind: original.mediaKind,
            title: original.title,
            startTime: currentTime,
            sourceStart: original.sourceStart + splitOffsetSource,
            sourceDuration: max(0.1, original.sourceDuration - splitOffsetSource),
            fullMediaDuration: original.fullMediaDuration,
            textStyle: original.textStyle
        )
        right.speed = original.speed
        right.scale = original.scale
        right.positionX = original.positionX
        right.positionY = original.positionY
        right.rotationDegrees = original.rotationDegrees
        right.opacity = original.opacity
        right.isFlippedHorizontal = original.isFlippedHorizontal
        right.volume = original.volume
        right.isMuted = original.isMuted
        right.adjustments = original.adjustments

        clips[idx] = left
        clips.insert(right, at: idx + 1)
        if isMagneticMainTrack && original.trackKind == .mainVideo {
            packMainVideoTrack()
        }
        selectedClipID = right.id
        schedulePlayerRebuild()
        saveCurrentProject()
        return true
    }

    public func deleteSelectedClip() {
        guard let idx = selectedClipIndex else { return }
        pushUndo()
        let wasMain = clips[idx].trackKind == .mainVideo
        clips.remove(at: idx)
        if wasMain && isMagneticMainTrack {
            packMainVideoTrack()
        }
        selectedClipID = clips.first?.id
        schedulePlayerRebuild()
        saveCurrentProject()
    }

    public func duplicateSelectedClip() {
        guard let clip = selectedClip else { return }
        pushUndo()
        var copy = clip
        let newClip = TimelineClip(
            id: UUID(),
            trackKind: copy.trackKind,
            mediaID: copy.mediaID,
            mediaURL: copy.mediaURL,
            mediaKind: copy.mediaKind,
            title: copy.title,
            startTime: copy.endTime,
            sourceStart: copy.sourceStart,
            sourceDuration: copy.sourceDuration,
            fullMediaDuration: copy.fullMediaDuration,
            textStyle: copy.textStyle
        )
        copy = newClip
        copy.speed = clip.speed
        copy.scale = clip.scale
        copy.positionX = clip.positionX
        copy.positionY = clip.positionY
        copy.rotationDegrees = clip.rotationDegrees
        copy.opacity = clip.opacity
        copy.isFlippedHorizontal = clip.isFlippedHorizontal
        copy.volume = clip.volume
        copy.isMuted = clip.isMuted
        copy.adjustments = clip.adjustments

        clips.append(copy)
        if isMagneticMainTrack && copy.trackKind == .mainVideo {
            packMainVideoTrack()
        }
        selectedClipID = copy.id
        schedulePlayerRebuild()
        saveCurrentProject()
    }

    public func updateSelectedClip(_ mutate: (inout TimelineClip) -> Void, commitUndo: Bool = false) {
        guard let idx = selectedClipIndex else { return }
        if commitUndo { pushUndo() }
        let oldDuration = clips[idx].duration
        mutate(&clips[idx])
        if clips[idx].trackKind == .mainVideo && isMagneticMainTrack && abs(clips[idx].duration - oldDuration) > 0.001 {
            packMainVideoTrack()
        }
        schedulePlayerRebuild()
    }

    public func moveClip(id: UUID, newStartTime: Double) {
        guard let idx = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[idx].startTime = max(0, newStartTime)
        if clips[idx].trackKind == .mainVideo && isMagneticMainTrack {
            packMainVideoTrack()
        }
        schedulePlayerRebuild()
    }

    public func trimClipEnd(id: UUID, newDuration: Double) {
        guard let idx = clips.firstIndex(where: { $0.id == id }) else { return }
        let clip = clips[idx]
        let safeSpeed = max(0.25, min(4.0, clip.speed))
        let maxSource = max(0.2, clip.fullMediaDuration - clip.sourceStart)
        let desiredSource = max(0.2, min(newDuration * safeSpeed, maxSource))
        clips[idx].sourceDuration = desiredSource
        if clip.trackKind == .mainVideo && isMagneticMainTrack {
            packMainVideoTrack()
        }
        schedulePlayerRebuild()
    }

    public func packMainVideoTrack() {
        let mainIndices = clips.indices
            .filter { clips[$0].trackKind == .mainVideo }
            .sorted { clips[$0].startTime < clips[$1].startTime }
        var cursor: Double = 0
        for idx in mainIndices {
            clips[idx].startTime = cursor
            cursor += clips[idx].duration
        }
    }

    // MARK: - Playback & Live Composition Sync

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] cmTime in
            Task { @MainActor in
                guard let self, self.isPlaying else { return }
                let sec = CMTimeGetSeconds(cmTime)
                if sec.isFinite && sec >= 0 {
                    self.currentTime = min(sec, self.totalDuration)
                    if sec >= self.totalDuration - 0.04 && self.totalDuration > 0 {
                        self.pause()
                    }
                }
            }
        }
    }

    public func schedulePlayerRebuild() {
        rebuildTask?.cancel()
        let snapshotClips = clips
        let size = renderSize
        let preserveTime = currentTime

        rebuildTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 90_000_000)
            guard !Task.isCancelled, let self else { return }

            if snapshotClips.isEmpty || !snapshotClips.contains(where: { $0.trackKind == .mainVideo || $0.trackKind == .overlayVideo }) {
                self.player.pause()
                self.isPlaying = false
                self.player.replaceCurrentItem(with: nil)
                return
            }

            do {
                let previewSize = CanvasDimensionHelper.sizeForAspectRatio(
                    ratioW: max(1, Int(size.width)),
                    ratioH: max(1, Int(size.height)),
                    baseShortSide: 720
                )
                let built = try await TimelineCompositionBuilder.build(
                    clips: snapshotClips,
                    renderSize: previewSize,
                    frameRate: 30
                )
                guard !Task.isCancelled else { return }

                let item = AVPlayerItem(asset: built.composition)
                item.videoComposition = built.videoComposition
                if !built.audioMix.inputParameters.isEmpty {
                    item.audioMix = built.audioMix
                }

                let wasPlaying = self.isPlaying
                self.player.replaceCurrentItem(with: item)
                let targetSec = min(preserveTime, max(0, CMTimeGetSeconds(built.duration) - 0.02))
                await self.player.seek(to: CMTime(seconds: targetSec, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                if wasPlaying {
                    self.player.play()
                }
            } catch {
                // Ignore transient rebuild errors while editing
            }
        }
    }

    public func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    public func play() {
        guard hasVisualContent, totalDuration > 0 else { return }
        if currentTime >= totalDuration - 0.05 {
            seek(to: 0)
        }
        isPlaying = true
        player.play()
    }

    public func pause() {
        isPlaying = false
        player.pause()
    }

    public func seek(to seconds: Double) {
        let clamped = max(0, min(seconds, max(0, totalDuration)))
        currentTime = clamped
        let cm = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Export

    public func runExportWithSavePanel() {
        guard hasVisualContent else { return }
        pause()

        let panel = NSSavePanel()
        panel.title = "Export Video (tiffy-cut)"
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        let safeName = exportSettings.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        panel.nameFieldStringValue = "\(safeName.isEmpty ? "tiffy-cut" : safeName).mp4"

        guard panel.runModal() == .OK, let destination = panel.url else { return }

        let snapshotClips = clips
        let size = renderSize
        let settings = exportSettings

        isExporting = true
        exportProgress = 0
        exportedURL = nil
        errorMessage = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                let saved = try await self.exporter.export(
                    clips: snapshotClips,
                    renderSize: size,
                    settings: settings,
                    outputURL: destination
                ) { [weak self] p in
                    Task { @MainActor in
                        self?.exportProgress = p
                    }
                }
                self.isExporting = false
                self.exportProgress = 1.0
                self.showExportSheet = false
                self.exportedURL = saved
            } catch {
                self.isExporting = false
                if case CollageExportError.cancelled = error {
                    // Cancelled by user
                } else {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func cancelExport() {
        exporter.cancel()
        isExporting = false
    }

    public static func formatTimecode(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00.0" }
        let mins = Int(seconds) / 60
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%04.1f", mins, secs)
    }
}
