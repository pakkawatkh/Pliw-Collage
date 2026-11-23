import AVFoundation
import CoreImage
import Foundation

public struct CollageRenderConfig {
    public let aspectRatio: AspectRatioPreset
    public let renderSize: CGSize
    public let layout: CollageLayout
    public let slots: [ClipSlot]
    public let spacing: CGFloat
    public let outerPadding: CGFloat
    public let cornerRadius: CGFloat
    public let backgroundColor: CIColor
    public let durationMode: DurationMode
    public let frameRate: Int32

    public init(
        aspectRatio: AspectRatioPreset,
        renderSize: CGSize? = nil,
        layout: CollageLayout,
        slots: [ClipSlot],
        spacing: CGFloat,
        outerPadding: CGFloat,
        cornerRadius: CGFloat,
        backgroundColor: CIColor,
        durationMode: DurationMode,
        frameRate: Int32 = 30
    ) {
        self.aspectRatio = aspectRatio
        let chosenSize = renderSize ?? aspectRatio.renderSize
        self.renderSize = CanvasDimensionHelper.sanitizedSize(
            width: Int(chosenSize.width.rounded()),
            height: Int(chosenSize.height.rounded())
        )
        self.layout = layout
        self.slots = slots
        self.spacing = spacing
        self.outerPadding = outerPadding
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.durationMode = durationMode
        self.frameRate = frameRate
    }
}

public struct BuiltCollageComposition {
    public let composition: AVMutableComposition
    public let videoComposition: AVMutableVideoComposition
    public let audioMix: AVMutableAudioMix
    public let duration: CMTime
}

public enum CollageCompositionError: LocalizedError {
    case noVideos
    case failedToCreateTrack
    case invalidDuration

    public var errorDescription: String? {
        switch self {
        case .noVideos:
            return "กรุณาเพิ่มวิดีโออย่างน้อย 1 คลิปก่อนส่งออก"
        case .failedToCreateTrack:
            return "ไม่สามารถสร้างแทร็กวิดีโอสำหรับการรวมคลิปได้"
        case .invalidDuration:
            return "ความยาวของวิดีโอไม่ถูกต้อง"
        }
    }
}

public enum CollageCompositionBuilder {

    public static func build(config: CollageRenderConfig) async throws -> BuiltCollageComposition {
        let activeSlots = Array(config.slots.prefix(config.layout.slotCount))
        let totalSeconds = LayoutCalculator.targetDuration(for: activeSlots, mode: config.durationMode)
        guard totalSeconds > 0.05 else {
            throw CollageCompositionError.noVideos
        }

        let targetDuration = CMTime(seconds: totalSeconds, preferredTimescale: 600)
        let composition = AVMutableComposition()
        let renderSize = config.renderSize

        let bottomLeftRects = LayoutCalculator.slotRectsBottomLeft(
            layout: config.layout,
            canvasSize: renderSize,
            spacing: config.spacing,
            outerPadding: config.outerPadding
        )

        var descriptors: [CompositorSlotDescriptor] = []
        var audioInputParams: [AVMutableAudioMixInputParameters] = []

        for (index, slot) in activeSlots.enumerated() {
            guard let url = slot.url, slot.hasVideo, index < bottomLeftRects.count else {
                continue
            }

            let asset = AVURLAsset(url: url)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let sourceVideoTrack = videoTracks.first else {
                continue
            }

            let naturalSize = try await sourceVideoTrack.load(.naturalSize)
            let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
            let assetDuration = try await asset.load(.duration)
            let assetSeconds = CMTimeGetSeconds(assetDuration)
            guard assetSeconds > 0 else { continue }

            let trimStartSec = max(0, min(slot.trimStart, assetSeconds - 0.05))
            let rawEndSec = slot.trimEnd > trimStartSec ? min(slot.trimEnd, assetSeconds) : assetSeconds
            let trimDurationSec = max(0.05, rawEndSec - trimStartSec)

            let clipStart = CMTime(seconds: trimStartSec, preferredTimescale: 600)
            let clipDuration = CMTime(seconds: trimDurationSec, preferredTimescale: 600)

            guard let compVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw CollageCompositionError.failedToCreateTrack
            }

            let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
            let sourceAudioTrack = audioTracks.first
            var compAudioTrack: AVMutableCompositionTrack?
            if sourceAudioTrack != nil && !slot.isMuted && slot.volume > 0.001 {
                compAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
            }

            // Insert clip repeatedly (looping) until targetDuration is filled.
            var cursor = CMTime.zero
            while CMTimeCompare(cursor, targetDuration) < 0 {
                let remaining = CMTimeSubtract(targetDuration, cursor)
                let segmentDuration = CMTimeMinimum(clipDuration, remaining)
                if CMTimeGetSeconds(segmentDuration) < 0.005 { break }

                let sourceRange = CMTimeRange(start: clipStart, duration: segmentDuration)
                try compVideoTrack.insertTimeRange(sourceRange, of: sourceVideoTrack, at: cursor)

                if let srcAudio = sourceAudioTrack, let dstAudio = compAudioTrack {
                    try? dstAudio.insertTimeRange(sourceRange, of: srcAudio, at: cursor)
                }

                cursor = CMTimeAdd(cursor, segmentDuration)
            }

            if let dstAudio = compAudioTrack {
                let params = AVMutableAudioMixInputParameters(track: dstAudio)
                params.setVolume(slot.volume, at: .zero)
                audioInputParams.append(params)
            }

            descriptors.append(
                CompositorSlotDescriptor(
                    trackID: compVideoTrack.trackID,
                    naturalSize: naturalSize,
                    preferredTransform: preferredTransform,
                    targetRectBottomLeft: bottomLeftRects[index],
                    cornerRadius: config.cornerRadius,
                    scale: slot.scale,
                    offsetX: slot.offsetX,
                    offsetY: slot.offsetY
                )
            )
        }

        guard !descriptors.isEmpty else {
            throw CollageCompositionError.noVideos
        }

        let instruction = CollageCompositionInstruction(
            timeRange: CMTimeRange(start: .zero, duration: targetDuration),
            renderSize: renderSize,
            backgroundColor: config.backgroundColor,
            slots: descriptors
        )

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: config.frameRate)
        videoComposition.customVideoCompositorClass = CollageVideoCompositor.self
        videoComposition.instructions = [instruction]

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = audioInputParams

        return BuiltCollageComposition(
            composition: composition,
            videoComposition: videoComposition,
            audioMix: audioMix,
            duration: targetDuration
        )
    }
}
