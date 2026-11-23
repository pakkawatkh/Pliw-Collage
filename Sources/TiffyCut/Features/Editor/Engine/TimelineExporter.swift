import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

public final class TimelineExporter: @unchecked Sendable {
    private let stateQueue = DispatchQueue(label: "com.local.tiffy-cut.timeline.exporter")
    private var cancelledFlag = false
    private var activeReader: AVAssetReader?
    private var activeWriter: AVAssetWriter?

    public init() {}

    public func cancel() {
        stateQueue.sync {
            cancelledFlag = true
            activeReader?.cancelReading()
            activeWriter?.cancelWriting()
        }
    }

    private func isCancelled() -> Bool {
        stateQueue.sync { cancelledFlag }
    }

    private func resetState(reader: AVAssetReader?, writer: AVAssetWriter?) {
        stateQueue.sync {
            cancelledFlag = false
            activeReader = reader
            activeWriter = writer
        }
    }

    public func export(
        clips: [TimelineClip],
        renderSize: CGSize,
        settings: EditorExportSettings,
        outputURL: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        // Scale canvas size to requested export resolution while preserving aspect ratio
        let ratio = renderSize.width / max(1, renderSize.height)
        let shortSide = Double(settings.resolution.shortSidePixels)
        let targetW: Double = ratio <= 1.0 ? shortSide : shortSide * ratio
        let targetH: Double = ratio <= 1.0 ? shortSide / ratio : shortSide
        let finalSize = CanvasDimensionHelper.sanitizedSize(
            width: Int(targetW.rounded()),
            height: Int(targetH.rounded())
        )

        let built = try await TimelineCompositionBuilder.build(
            clips: clips,
            renderSize: finalSize,
            frameRate: settings.frameRate
        )
        let totalDurationSec = max(0.05, CMTimeGetSeconds(built.duration))

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let reader = try AVAssetReader(asset: built.composition)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true

        // Video pipeline
        let videoTracks = try await built.composition.loadTracks(withMediaType: .video)
        let videoOutput = AVAssetReaderVideoCompositionOutput(
            videoTracks: videoTracks,
            videoSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
        )
        videoOutput.videoComposition = built.videoComposition
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else {
            throw CollageExportError.failedToCreateReader("Cannot attach timeline video output")
        }
        reader.add(videoOutput)

        let codecType: AVVideoCodecType = settings.codec == .hevc ? .hevc : .h264
        let bitRate: Int = {
            switch settings.resolution {
            case .p720: return 6_000_000
            case .p1080: return 12_000_000
            case .p2K: return 20_000_000
            case .p4K: return 35_000_000
            }
        }()

        var compressionProps: [String: Any] = [
            AVVideoAverageBitRateKey: bitRate,
            AVVideoMaxKeyFrameIntervalKey: Int(settings.frameRate * 2)
        ]
        if codecType == .h264 {
            compressionProps[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        }

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: codecType,
                AVVideoWidthKey: Int(finalSize.width),
                AVVideoHeightKey: Int(finalSize.height),
                AVVideoCompressionPropertiesKey: compressionProps
            ]
        )
        videoInput.expectsMediaDataInRealTime = false
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(finalSize.width),
                kCVPixelBufferHeightKey as String: Int(finalSize.height)
            ]
        )
        guard writer.canAdd(videoInput) else {
            throw CollageExportError.failedToCreateWriter("Cannot attach video writer input")
        }
        writer.add(videoInput)

        // Optional audio pipeline
        let audioTracks = (try? await built.composition.loadTracks(withMediaType: .audio)) ?? []
        var audioOutput: AVAssetReaderAudioMixOutput?
        var audioInput: AVAssetWriterInput?

        if !audioTracks.isEmpty {
            let aOut = AVAssetReaderAudioMixOutput(
                audioTracks: audioTracks,
                audioSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 2,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false
                ]
            )
            if !built.audioMix.inputParameters.isEmpty {
                aOut.audioMix = built.audioMix
            }
            aOut.alwaysCopiesSampleData = false

            let aIn = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 192_000
                ]
            )
            aIn.expectsMediaDataInRealTime = false
            if reader.canAdd(aOut) && writer.canAdd(aIn) {
                reader.add(aOut)
                writer.add(aIn)
                audioOutput = aOut
                audioInput = aIn
            }
        }

        resetState(reader: reader, writer: writer)
        defer { resetState(reader: nil, writer: nil) }

        guard writer.startWriting() else {
            throw CollageExportError.exportFailed(writer.error?.localizedDescription ?? "Writer failed to start")
        }
        guard reader.startReading() else {
            writer.cancelWriting()
            throw CollageExportError.exportFailed(reader.error?.localizedDescription ?? "Reader failed to start")
        }
        writer.startSession(atSourceTime: .zero)

        let videoQueue = DispatchQueue(label: "com.local.tiffy-cut.timeline.export.video")
        let audioQueue = DispatchQueue(label: "com.local.tiffy-cut.timeline.export.audio")

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    var finished = false
                    videoInput.requestMediaDataWhenReady(on: videoQueue) {
                        while videoInput.isReadyForMoreMediaData {
                            if self?.isCancelled() == true {
                                if !finished {
                                    finished = true
                                    videoInput.markAsFinished()
                                    continuation.resume()
                                }
                                return
                            }
                            if let sample = videoOutput.copyNextSampleBuffer() {
                                let ptsTime = CMSampleBufferGetPresentationTimeStamp(sample)
                                let pts = CMTimeGetSeconds(ptsTime)
                                if pts.isFinite && pts >= 0 {
                                    onProgress(min(0.98, max(0.0, pts / totalDurationSec)))
                                }
                                if let img = CMSampleBufferGetImageBuffer(sample) {
                                    if !pixelBufferAdaptor.append(img, withPresentationTime: ptsTime) {
                                        if !finished {
                                            finished = true
                                            videoInput.markAsFinished()
                                            continuation.resume()
                                        }
                                        return
                                    }
                                }
                            } else {
                                if !finished {
                                    finished = true
                                    videoInput.markAsFinished()
                                    continuation.resume()
                                }
                                return
                            }
                        }
                    }
                }
            }

            if let aOut = audioOutput, let aIn = audioInput {
                group.addTask { [weak self] in
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        var finished = false
                        aIn.requestMediaDataWhenReady(on: audioQueue) {
                            while aIn.isReadyForMoreMediaData {
                                if self?.isCancelled() == true {
                                    if !finished {
                                        finished = true
                                        aIn.markAsFinished()
                                        continuation.resume()
                                    }
                                    return
                                }
                                if let sample = aOut.copyNextSampleBuffer() {
                                    aIn.append(sample)
                                } else {
                                    if !finished {
                                        finished = true
                                        aIn.markAsFinished()
                                        continuation.resume()
                                    }
                                    return
                                }
                            }
                        }
                    }
                }
            }
        }

        if isCancelled() {
            reader.cancelReading()
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            throw CollageExportError.cancelled
        }

        if reader.status == .failed {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            throw CollageExportError.exportFailed(reader.error?.localizedDescription ?? "Decoding failed")
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting { continuation.resume() }
        }

        switch writer.status {
        case .completed:
            onProgress(1.0)
            return outputURL
        case .cancelled:
            try? FileManager.default.removeItem(at: outputURL)
            throw CollageExportError.cancelled
        case .failed:
            try? FileManager.default.removeItem(at: outputURL)
            throw CollageExportError.exportFailed(writer.error?.localizedDescription ?? "MP4 encoding failed")
        default:
            throw CollageExportError.exportFailed("Unexpected writer status")
        }
    }
}
