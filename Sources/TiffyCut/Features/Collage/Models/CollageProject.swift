import AppKit
import AVFoundation
import Combine
import CoreImage
import Foundation
import SwiftUI

@MainActor
public final class CollageProject: ObservableObject {
    @Published public var aspectRatio: AspectRatioPreset = .tiktok9x16
    @Published public var layout: CollageLayout = .splitVertical {
        didSet {
            if selectedSlotIndex >= layout.slotCount {
                selectedSlotIndex = 0
            }
            clampCurrentTime()
        }
    }

    @Published public var slots: [ClipSlot] = (0..<4).map { ClipSlot(id: $0) }
    @Published public var selectedSlotIndex: Int = 0

    /// Spacing in 1080p export pixels (scaled proportionally in preview).
    @Published public var spacing: CGFloat = 12
    /// Outer margin in 1080p export pixels.
    @Published public var outerPadding: CGFloat = 16
    /// Corner radius in 1080p export pixels.
    @Published public var cornerRadius: CGFloat = 24
    @Published public var backgroundColor: Color = .black
    @Published public var durationMode: DurationMode = .longestLoop {
        didSet { clampCurrentTime() }
    }

    // Playback state
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0

    // Export state
    @Published public var isExporting: Bool = false
    @Published public var exportProgress: Double = 0
    @Published public var exportedURL: URL?
    @Published public var exportErrorMessage: String?

    // Preview players (one per slot index 0..3)
    public private(set) var players: [AVPlayer?] = [nil, nil, nil, nil]
    private var playbackTimer: Timer?
    private var lastTickDate: Date?
    private let exporter = CollageExporter()

    public init() {}

    public var activeSlots: [ClipSlot] {
        Array(slots.prefix(layout.slotCount))
    }

    public var hasAnyVideo: Bool {
        activeSlots.contains { $0.hasVideo }
    }

    public var targetDuration: Double {
        LayoutCalculator.targetDuration(for: activeSlots, mode: durationMode)
    }

    public func loadVideo(url: URL, into slotIndex: Int) {
        guard slotIndex >= 0 && slotIndex < slots.count else { return }
        pause()

        Task {
            let asset = AVURLAsset(url: url)
            do {
                let durationCM = try await asset.load(.duration)
                let durationSec = CMTimeGetSeconds(durationCM)
                guard durationSec > 0 else { return }

                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                guard let videoTrack = videoTracks.first else { return }

                let naturalSize = try await videoTrack.load(.naturalSize)
                let preferredTransform = try await videoTrack.load(.preferredTransform)
                let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []

                var updated = ClipSlot(id: slotIndex)
                updated.url = url
                updated.duration = durationSec
                updated.naturalSize = naturalSize
                updated.preferredTransform = preferredTransform
                updated.hasAudio = !audioTracks.isEmpty
                updated.trimStart = 0
                updated.trimEnd = durationSec
                updated.isMuted = false
                updated.volume = 1.0

                let player = AVPlayer(url: url)
                player.actionAtItemEnd = .pause
                player.isMuted = updated.isMuted
                player.volume = updated.volume

                self.players[slotIndex]?.pause()
                self.players[slotIndex] = player
                self.slots[slotIndex] = updated
                self.selectedSlotIndex = slotIndex
                self.seek(to: 0)
            } catch {
                self.exportErrorMessage = "ไม่สามารถเปิดไฟล์วิดีโอได้: \(error.localizedDescription)"
            }
        }
    }

    public func clearSlot(_ index: Int) {
        guard index >= 0 && index < slots.count else { return }
        pause()
        players[index]?.pause()
        players[index] = nil
        slots[index].clear()
        clampCurrentTime()
    }

    public func swapSlots(_ a: Int, _ b: Int) {
        guard a != b, a >= 0, b >= 0, a < slots.count, b < slots.count else { return }
        pause()
        let slotA = slots[a]
        let slotB = slots[b]
        var newA = slotB
        var newB = slotA
        // Preserve slot ids
        newA = ClipSlot(id: a)
        copySlotProperties(from: slotB, to: &newA)
        newB = ClipSlot(id: b)
        copySlotProperties(from: slotA, to: &newB)

        slots[a] = newA
        slots[b] = newB
        players.swapAt(a, b)
        seek(to: currentTime)
    }

    private func copySlotProperties(from src: ClipSlot, to dst: inout ClipSlot) {
        dst.url = src.url
        dst.duration = src.duration
        dst.naturalSize = src.naturalSize
        dst.preferredTransform = src.preferredTransform
        dst.hasAudio = src.hasAudio
        dst.trimStart = src.trimStart
        dst.trimEnd = src.trimEnd
        dst.isMuted = src.isMuted
        dst.volume = src.volume
        dst.scale = src.scale
        dst.offsetX = src.offsetX
        dst.offsetY = src.offsetY
    }

    public func syncAudioSettings(for index: Int) {
        guard index >= 0 && index < slots.count, let player = players[index] else { return }
        player.isMuted = slots[index].isMuted
        player.volume = slots[index].volume
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        guard hasAnyVideo, targetDuration > 0 else { return }
        if currentTime >= targetDuration - 0.05 {
            currentTime = 0
        }
        isPlaying = true
        lastTickDate = Date()

        for index in 0..<layout.slotCount {
            guard slots[index].hasVideo, let player = players[index] else { continue }
            player.isMuted = slots[index].isMuted
            player.volume = slots[index].volume
            let slotTime = mappedSlotTime(for: slots[index], globalTime: currentTime)
            let cm = CMTime(seconds: slotTime, preferredTimescale: 600)
            player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                player.play()
            }
        }

        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackTick()
            }
        }
    }

    public func pause() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        lastTickDate = nil
        for player in players {
            player?.pause()
        }
    }

    public func seek(to time: Double) {
        let dur = targetDuration
        let clamped = dur > 0 ? max(0, min(time, dur)) : 0
        currentTime = clamped

        for index in 0..<layout.slotCount {
            guard slots[index].hasVideo, let player = players[index] else { continue }
            let slotTime = mappedSlotTime(for: slots[index], globalTime: clamped)
            let cm = CMTime(seconds: slotTime, preferredTimescale: 600)
            player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    public func previewSlotFrame(index: Int, at localTime: Double) {
        guard index >= 0 && index < slots.count, let player = players[index] else { return }
        pause()
        let clamped = max(0, min(localTime, slots[index].duration))
        let cm = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func handlePlaybackTick() {
        guard isPlaying else { return }
        let now = Date()
        let dt = now.timeIntervalSince(lastTickDate ?? now)
        lastTickDate = now

        let dur = targetDuration
        guard dur > 0 else {
            pause()
            return
        }

        var nextTime = currentTime + dt
        if nextTime >= dur {
            nextTime = 0
            currentTime = 0
            // Restart all slots cleanly on loop
            for index in 0..<layout.slotCount {
                guard slots[index].hasVideo, let player = players[index] else { continue }
                let cm = CMTime(seconds: slots[index].trimStart, preferredTimescale: 600)
                player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
                if player.rate == 0 { player.play() }
            }
            return
        }

        currentTime = nextTime

        // Loop individual shorter clips seamlessly when in longestLoop mode
        for index in 0..<layout.slotCount {
            guard slots[index].hasVideo, let player = players[index] else { continue }
            let slot = slots[index]
            let end = slot.trimEnd > slot.trimStart ? slot.trimEnd : slot.duration
            let playerSec = CMTimeGetSeconds(player.currentTime())
            if playerSec >= end - 0.04 {
                let cm = CMTime(seconds: slot.trimStart, preferredTimescale: 600)
                player.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
                if player.rate == 0 { player.play() }
            }
        }
    }

    private func mappedSlotTime(for slot: ClipSlot, globalTime: Double) -> Double {
        let clipDur = slot.trimmedDuration
        guard clipDur > 0 else { return slot.trimStart }
        let localOffset = globalTime.truncatingRemainder(dividingBy: clipDur)
        return slot.trimStart + localOffset
    }

    private func clampCurrentTime() {
        if currentTime > targetDuration {
            currentTime = 0
        }
    }

    public func makeRenderConfig() -> CollageRenderConfig {
        let nsColor = NSColor(backgroundColor).usingColorSpace(.sRGB) ?? NSColor.black
        let ciColor = CIColor(
            red: nsColor.redComponent,
            green: nsColor.greenComponent,
            blue: nsColor.blueComponent,
            alpha: 1.0
        )

        return CollageRenderConfig(
            aspectRatio: aspectRatio,
            layout: layout,
            slots: activeSlots,
            spacing: spacing,
            outerPadding: outerPadding,
            cornerRadius: cornerRadius,
            backgroundColor: ciColor,
            durationMode: durationMode,
            frameRate: 30
        )
    }

    public func presentExportPanel() {
        guard hasAnyVideo else { return }
        pause()

        let panel = NSSavePanel()
        panel.title = "Export Video Collage"
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.canCreateDirectories = true
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        panel.nameFieldStringValue = "tiffy-cut-collage-\(aspectRatio.rawValue.replacingOccurrences(of: ":", with: "x"))-\(dateFormatter.string(from: Date())).mp4"

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }
        startExport(to: destinationURL)
    }

    public func startExport(to outputURL: URL) {
        let config = makeRenderConfig()
        isExporting = true
        exportProgress = 0
        exportedURL = nil
        exportErrorMessage = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                let savedURL = try await self.exporter.export(config: config, outputURL: outputURL) { [weak self] progress in
                    Task { @MainActor in
                        self?.exportProgress = progress
                    }
                }
                self.isExporting = false
                self.exportProgress = 1.0
                self.exportedURL = savedURL
            } catch {
                self.isExporting = false
                if case CollageExportError.cancelled = error {
                    // User cancelled; no error alert needed.
                } else {
                    self.exportErrorMessage = error.localizedDescription
                }
            }
        }
    }

    public func cancelExport() {
        exporter.cancel()
        isExporting = false
    }

    public func openFilePicker(for slotIndex: Int) {
        let panel = NSOpenPanel()
        panel.title = "เลือกไฟล์วิดีโอสำหรับช่องที่ \(slotIndex + 1)"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .video]
        if panel.runModal() == .OK, let url = panel.url {
            loadVideo(url: url, into: slotIndex)
        }
    }

    public static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00.0" }
        let mins = Int(seconds) / 60
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%04.1f", mins, secs)
    }
}
