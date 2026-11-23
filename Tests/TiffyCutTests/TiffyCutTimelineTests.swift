import AVFoundation
import CoreGraphics
import CoreVideo
import XCTest
@testable import TiffyCut

final class TiffyCutTimelineTests: XCTestCase {

    @MainActor
    func testSplitAtPlayheadMagneticPackAndUndoRedo() {
        let project = TimelineProject()
        let item = MediaItem(
            url: URL(fileURLWithPath: "/tmp/sample.mp4"),
            name: "sample.mp4",
            kind: .video,
            duration: 4.0,
            naturalSize: CGSize(width: 1080, height: 1920),
            hasAudio: false
        )
        project.addMediaToTimeline(item, asOverlay: false)
        XCTAssertEqual(project.clips.count, 1)
        XCTAssertEqual(project.clips[0].duration, 4.0, accuracy: 0.01)

        // Split at 1.5s
        project.currentTime = 1.5
        let didSplit = project.splitAtPlayhead()
        XCTAssertTrue(didSplit)
        XCTAssertEqual(project.clips.count, 2)
        XCTAssertEqual(project.clips[0].duration, 1.5, accuracy: 0.01)
        XCTAssertEqual(project.clips[1].startTime, 1.5, accuracy: 0.01)
        XCTAssertEqual(project.clips[1].sourceStart, 1.5, accuracy: 0.01)
        XCTAssertEqual(project.clips[1].duration, 2.5, accuracy: 0.01)

        // Delete first clip -> second clip magnetically snaps to 0.0s
        project.selectedClipID = project.clips[0].id
        project.deleteSelectedClip()
        XCTAssertEqual(project.clips.count, 1)
        XCTAssertEqual(project.clips[0].startTime, 0.0, accuracy: 0.01)
        XCTAssertEqual(project.clips[0].duration, 2.5, accuracy: 0.01)

        // Undo restores 2 clips; Redo goes back to 1 clip
        project.undo()
        XCTAssertEqual(project.clips.count, 2)
        project.redo()
        XCTAssertEqual(project.clips.count, 1)
    }

    func testEndToEndTimelineExportWithFilterTransitionAndTextOverlay() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tiffy-cut-timeline-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let srcURL = tmpDir.appendingPathComponent("src.mp4")
        let outURL = tmpDir.appendingPathComponent("edited.mp4")
        try await Self.generateTestVideo(url: srcURL, size: CGSize(width: 640, height: 360), durationSeconds: 1.0)

        var videoClip = TimelineClip(
            trackKind: .mainVideo,
            mediaURL: srcURL,
            mediaKind: .video,
            title: "src.mp4",
            startTime: 0,
            sourceStart: 0,
            sourceDuration: 1.0,
            fullMediaDuration: 1.0
        )
        videoClip.adjustments.filter = .vivid
        videoClip.transitionIn = .fadeBlack
        videoClip.transitionDuration = 0.25

        let textClip = TimelineClip(
            trackKind: .text,
            title: "Hello tiffy-cut",
            startTime: 0.1,
            sourceStart: 0,
            sourceDuration: 0.8,
            textStyle: TextOverlayStyle(text: "Hello tiffy-cut")
        )

        var settings = EditorExportSettings()
        settings.resolution = .p1080
        settings.frameRate = 30
        settings.codec = .h264

        let exporter = TimelineExporter()
        let exported = try await exporter.export(
            clips: [videoClip, textClip],
            renderSize: AspectRatioPreset.tiktok9x16.renderSize,
            settings: settings,
            outputURL: outURL
        ) { _ in }

        XCTAssertTrue(FileManager.default.fileExists(atPath: exported.path))
        let asset = AVURLAsset(url: exported)
        let duration = CMTimeGetSeconds(try await asset.load(.duration))
        XCTAssertGreaterThan(duration, 0.8)
        XCTAssertLessThan(duration, 1.2)

        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let size = try await track.load(.naturalSize)
        XCTAssertEqual(size.width, 1080, accuracy: 2.0)
        XCTAssertEqual(size.height, 1920, accuracy: 2.0)
    }

    private static func generateTestVideo(url: URL, size: CGSize, durationSeconds: Double) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ])
        input.expectsMediaDataInRealTime = false
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let count = max(2, Int(durationSeconds * Double(fps)))
        for f in 0..<count {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            var px: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, attrs as CFDictionary, &px)
            if let px {
                CVPixelBufferLockBaseAddress(px, [])
                if let base = CVPixelBufferGetBaseAddress(px) {
                    memset(base, 120, CVPixelBufferGetBytesPerRow(px) * Int(size.height))
                }
                CVPixelBufferUnlockBaseAddress(px, [])
                adaptor.append(px, withPresentationTime: CMTime(value: CMTimeValue(f), timescale: fps))
            }
        }
        input.markAsFinished()
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            writer.finishWriting { c.resume() }
        }
    }
}
