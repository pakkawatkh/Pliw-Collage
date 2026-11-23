import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

public enum CollageExportError: LocalizedError {
    case failedToCreateReader(String)
    case failedToCreateWriter(String)
    case cancelled
    case exportFailed(String)

    public var errorDescription: String? {
        switch self {
        case .failedToCreateReader(let reason):
            return "ไม่สามารถอ่านวิดีโอต้นฉบับได้: \(reason)"
        case .failedToCreateWriter(let reason):
            return "ไม่สามารถสร้างไฟล์ MP4 ได้: \(reason)"
        case .cancelled:
            return "ยกเลิกการส่งออกแล้ว"
        case .exportFailed(let reason):
            return "ส่งออกวิดีโอไม่สำเร็จ: \(reason)"
        }
    }
}

public final class CollageExporter: @unchecked Sendable {
    private let stateQueue = DispatchQueue(label: "com.local.tiffy-cut.exporter.state")
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
        config: CollageRenderConfig,
        outputURL: URL,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let built = try await CollageCompositionBuilder.build(config: config)
        let totalDurationSec = max(0.05, CMTimeGetSeconds(built.duration))
        let renderSize = config.renderSize

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: built.composition)
        } catch {
            throw CollageExportError.failedToCreateReader(error.localizedDescription)
        }

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
            writer.shouldOptimizeForNetworkUse = true
        } catch {
            throw CollageExportError.failedToCreateWriter(error.localizedDescription)
        }

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
            throw CollageExportError.failedToCreateReader("Cannot attach video composition output")
        }
        reader.add(videoOutput)

        let videoInputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(renderSize.width),
            AVVideoHeightKey: Int(renderSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: Int(config.frameRate * 2)
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoInputSettings)
        videoInput.expectsMediaDataInRealTime = false
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(renderSize.width),
                kCVPixelBufferHeightKey as String: Int(renderSize.height)
            ]
        )
        guard writer.canAdd(videoInput) else {
            throw CollageExportError.failedToCreateWriter("Cannot attach H.264 video writer input")
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

        let videoQueue = DispatchQueue(label: "com.local.clip-collage.export.video")
        let audioQueue = DispatchQueue(label: "com.local.clip-collage.export.audio")

        var appendedFrames = 0
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
                                if let imageBuffer = CMSampleBufferGetImageBuffer(sample) {
                                    if pixelBufferAdaptor.append(imageBuffer, withPresentationTime: ptsTime) {
                                        appendedFrames += 1
                                    } else {
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
            throw CollageExportError.exportFailed(reader.error?.localizedDescription ?? "Video decoding failed")
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting {
                continuation.resume()
            }
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
            let msg = writer.error.map { String(describing: $0 as NSError) } ?? "MP4 encoding failed"
            throw CollageExportError.exportFailed(msg)
        default:
            throw CollageExportError.exportFailed("Unexpected writer status: \(writer.status.rawValue)")
        }
    }
}
