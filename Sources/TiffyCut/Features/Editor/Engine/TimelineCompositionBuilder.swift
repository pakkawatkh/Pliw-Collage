import AVFoundation
import CoreGraphics
import Foundation

public struct BuiltTimelineComposition {
    public let composition: AVMutableComposition
    public let videoComposition: AVMutableVideoComposition
    public let audioMix: AVMutableAudioMix
    public let duration: CMTime
    public let renderSize: CGSize
}

public enum TimelineBuildError: LocalizedError {
    case emptyTimeline
    case failedToCreateTrack

    public var errorDescription: String? {
        switch self {
        case .emptyTimeline:
            return "ยังไม่มีคลิปบนไทม์ไลน์ กรุณาเพิ่มวิดีโอก่อน"
        case .failedToCreateTrack:
            return "ไม่สามารถสร้างแทร็กสำหรับรวมวิดีโอได้"
        }
    }
}

public enum TimelineCompositionBuilder {

    public static func build(
        clips: [TimelineClip],
        renderSize: CGSize,
        frameRate: Int32 = 30
    ) async throws -> BuiltTimelineComposition {
        let totalSeconds = clips.map { $0.endTime }.max() ?? 0
        guard totalSeconds > 0.05 else {
            throw TimelineBuildError.emptyTimeline
        }

        let safeSize = CanvasDimensionHelper.sanitizedSize(
            width: Int(renderSize.width.rounded()),
            height: Int(renderSize.height.rounded())
        )
        let totalCM = CMTime(seconds: totalSeconds, preferredTimescale: 600)

        let composition = AVMutableComposition()
        var videoLayerDescriptors: [TimelineVideoLayerDescriptor] = []
        var textLayerDescriptors: [TimelineTextLayerDescriptor] = []
        var audioInputParams: [AVMutableAudioMixInputParameters] = []

        // Sort clips so mainVideo is rendered below overlayVideo
        let visualClips = clips
            .filter { $0.trackKind == .mainVideo || $0.trackKind == .overlayVideo }
            .sorted { a, b in
                if a.trackKind != b.trackKind {
                    return a.trackKind == .mainVideo
                }
                return a.startTime < b.startTime
            }

        for (index, clip) in visualClips.enumerated() {
            guard let url = clip.mediaURL else { continue }
            let asset = AVURLAsset(url: url)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let srcVideo = videoTracks.first else { continue }

            let preferredTransform = try await srcVideo.load(.preferredTransform)
            let assetDurSec = CMTimeGetSeconds(try await asset.load(.duration))
            guard assetDurSec > 0.02 else { continue }

            let srcStartSec = max(0, min(clip.sourceStart, assetDurSec - 0.02))
            let srcDurSec = max(0.05, min(clip.sourceDuration, assetDurSec - srcStartSec))

            let sourceRange = CMTimeRange(
                start: CMTime(seconds: srcStartSec, preferredTimescale: 600),
                duration: CMTime(seconds: srcDurSec, preferredTimescale: 600)
            )
            let insertAt = CMTime(seconds: clip.startTime, preferredTimescale: 600)
            let scaledDur = CMTime(seconds: clip.duration, preferredTimescale: 600)

            guard let compVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw TimelineBuildError.failedToCreateTrack
            }

            try compVideoTrack.insertTimeRange(sourceRange, of: srcVideo, at: insertAt)
            if abs(clip.speed - 1.0) > 0.01 {
                compVideoTrack.scaleTimeRange(
                    CMTimeRange(start: insertAt, duration: sourceRange.duration),
                    toDuration: scaledDur
                )
            }

            let zIndex = (clip.trackKind == .mainVideo ? 0 : 1000) + index
            videoLayerDescriptors.append(
                TimelineVideoLayerDescriptor(
                    trackID: compVideoTrack.trackID,
                    startTime: clip.startTime,
                    endTime: clip.endTime,
                    preferredTransform: preferredTransform,
                    scale: clip.scale,
                    positionX: clip.positionX,
                    positionY: clip.positionY,
                    rotationDegrees: clip.rotationDegrees,
                    opacity: clip.opacity,
                    isFlippedHorizontal: clip.isFlippedHorizontal,
                    adjustments: clip.adjustments,
                    transitionIn: clip.transitionIn,
                    transitionDuration: min(clip.transitionDuration, clip.duration * 0.5),
                    zIndex: zIndex
                )
            )

            // Attach embedded audio if not muted
            if !clip.isMuted && clip.volume > 0.001 {
                let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
                if let srcAudio = audioTracks.first,
                   let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try? compAudio.insertTimeRange(sourceRange, of: srcAudio, at: insertAt)
                    if abs(clip.speed - 1.0) > 0.01 {
                        compAudio.scaleTimeRange(
                            CMTimeRange(start: insertAt, duration: sourceRange.duration),
                            toDuration: scaledDur
                        )
                    }
                    audioInputParams.append(Self.makeAudioParams(track: compAudio, clip: clip, insertAt: insertAt, duration: scaledDur))
                }
            }
        }

        // Dedicated Audio Track clips
        let audioClips = clips.filter { $0.trackKind == .audio }
        for clip in audioClips {
            guard !clip.isMuted && clip.volume > 0.001, let url = clip.mediaURL else { continue }
            let asset = AVURLAsset(url: url)
            let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
            guard let srcAudio = audioTracks.first else { continue }
            let assetDurSec = CMTimeGetSeconds(try await asset.load(.duration))
            guard assetDurSec > 0.02 else { continue }

            let srcStartSec = max(0, min(clip.sourceStart, assetDurSec - 0.02))
            let srcDurSec = max(0.05, min(clip.sourceDuration, assetDurSec - srcStartSec))
            let sourceRange = CMTimeRange(
                start: CMTime(seconds: srcStartSec, preferredTimescale: 600),
                duration: CMTime(seconds: srcDurSec, preferredTimescale: 600)
            )
            let insertAt = CMTime(seconds: clip.startTime, preferredTimescale: 600)
            let scaledDur = CMTime(seconds: clip.duration, preferredTimescale: 600)

            if let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try? compAudio.insertTimeRange(sourceRange, of: srcAudio, at: insertAt)
                if abs(clip.speed - 1.0) > 0.01 {
                    compAudio.scaleTimeRange(
                        CMTimeRange(start: insertAt, duration: sourceRange.duration),
                        toDuration: scaledDur
                    )
                }
                audioInputParams.append(Self.makeAudioParams(track: compAudio, clip: clip, insertAt: insertAt, duration: scaledDur))
            }
        }

        // Text Overlay clips
        for clip in clips where clip.trackKind == .text {
            guard let style = clip.textStyle else { continue }
            textLayerDescriptors.append(
                TimelineTextLayerDescriptor(
                    startTime: clip.startTime,
                    endTime: clip.endTime,
                    style: style,
                    scale: clip.scale,
                    positionX: clip.positionX,
                    positionY: clip.positionY,
                    rotationDegrees: clip.rotationDegrees,
                    opacity: clip.opacity
                )
            )
        }

        let instruction = TimelineCompositionInstruction(
            timeRange: CMTimeRange(start: .zero, duration: totalCM),
            renderSize: safeSize,
            videoLayers: videoLayerDescriptors,
            textLayers: textLayerDescriptors
        )

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = safeSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: frameRate)
        videoComposition.customVideoCompositorClass = TimelineCompositor.self
        videoComposition.instructions = [instruction]

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = audioInputParams

        return BuiltTimelineComposition(
            composition: composition,
            videoComposition: videoComposition,
            audioMix: audioMix,
            duration: totalCM,
            renderSize: safeSize
        )
    }

    private static func makeAudioParams(
        track: AVCompositionTrack,
        clip: TimelineClip,
        insertAt: CMTime,
        duration: CMTime
    ) -> AVMutableAudioMixInputParameters {
        let params = AVMutableAudioMixInputParameters(track: track)
        let vol = min(2.0, max(0.0, clip.volume))
        params.setVolume(vol, at: insertAt)

        let durSec = CMTimeGetSeconds(duration)
        if clip.fadeInDuration > 0.05 {
            let fadeDur = min(clip.fadeInDuration, durSec * 0.5)
            let range = CMTimeRange(start: insertAt, duration: CMTime(seconds: fadeDur, preferredTimescale: 600))
            params.setVolumeRamp(fromStartVolume: 0, toEndVolume: vol, timeRange: range)
        }
        if clip.fadeOutDuration > 0.05 {
            let fadeDur = min(clip.fadeOutDuration, durSec * 0.5)
            let fadeStart = CMTimeAdd(insertAt, CMTime(seconds: max(0, durSec - fadeDur), preferredTimescale: 600))
            let range = CMTimeRange(start: fadeStart, duration: CMTime(seconds: fadeDur, preferredTimescale: 600))
            params.setVolumeRamp(fromStartVolume: vol, toEndVolume: 0, timeRange: range)
        }
        return params
    }
}
