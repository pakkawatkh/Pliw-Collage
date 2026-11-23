import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import XCTest
@testable import TiffyCut

final class TiffyCutCollageTests: XCTestCase {

    func testAllLayoutsProduceNonOverlappingPositiveRectsInsideCanvas() {
        let canvas = CGSize(width: 1080, height: 1920)
        let spacing: CGFloat = 12
        let padding: CGFloat = 16

        for layout in CollageLayout.allCases {
            let rects = LayoutCalculator.slotRectsTopLeft(
                layout: layout,
                canvasSize: canvas,
                spacing: spacing,
                outerPadding: padding
            )
            XCTAssertEqual(rects.count, layout.slotCount, "Layout \(layout) count mismatch")

            for (i, rect) in rects.enumerated() {
                XCTAssertGreaterThan(rect.width, 0)
                XCTAssertGreaterThan(rect.height, 0)
                XCTAssertGreaterThanOrEqual(rect.minX, padding - 0.01)
                XCTAssertGreaterThanOrEqual(rect.minY, padding - 0.01)
                XCTAssertLessThanOrEqual(rect.maxX, canvas.width - padding + 0.01)
                XCTAssertLessThanOrEqual(rect.maxY, canvas.height - padding + 0.01)

                for j in (i + 1)..<rects.count {
                    XCTAssertFalse(
                        rect.intersects(rects[j]),
                        "Slots \(i) and \(j) overlap in layout \(layout)"
                    )
                }
            }
        }
    }

    func testBottomLeftConversionPreservesDimensionsAndFlipsY() {
        let canvas = CGSize(width: 1080, height: 1920)
        let topLeft = LayoutCalculator.slotRectsTopLeft(
            layout: .splitVertical,
            canvasSize: canvas,
            spacing: 10,
            outerPadding: 20
        )
        let bottomLeft = LayoutCalculator.slotRectsBottomLeft(
            layout: .splitVertical,
            canvasSize: canvas,
            spacing: 10,
            outerPadding: 20
        )
        XCTAssertEqual(topLeft.count, 2)
        XCTAssertEqual(bottomLeft.count, 2)
        // Top slot in top-left has smaller minY, so in bottom-left it must have larger minY
        XCTAssertLessThan(topLeft[0].minY, topLeft[1].minY)
        XCTAssertGreaterThan(bottomLeft[0].minY, bottomLeft[1].minY)
        XCTAssertEqual(topLeft[0].size.width, bottomLeft[0].size.width, accuracy: 0.01)
        XCTAssertEqual(topLeft[0].size.height, bottomLeft[0].size.height, accuracy: 0.01)
    }

    func testCoreImageOrientationTransformFor90DegreePortraitVideo() {
        // Standard iPhone portrait recording: 1920x1080 raw with 90° CW preferredTransform
        let rawSize = CGSize(width: 1920, height: 1080)
        let portraitTransform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)

        let result = LayoutCalculator.coreImageOrientationTransform(
            naturalSize: rawSize,
            preferredTransform: portraitTransform
        )
        XCTAssertEqual(result.orientedSize.width, 1080, accuracy: 0.01)
        XCTAssertEqual(result.orientedSize.height, 1920, accuracy: 0.01)

        // Verify transformed bounding box lands at origin (0, 0) with size (1080, 1920)
        let mapped = CGRect(origin: .zero, size: rawSize).applying(result.transform)
        XCTAssertEqual(mapped.minX, 0, accuracy: 0.01)
        XCTAssertEqual(mapped.minY, 0, accuracy: 0.01)
        XCTAssertEqual(mapped.width, 1080, accuracy: 0.01)
        XCTAssertEqual(mapped.height, 1920, accuracy: 0.01)
    }

    func testTargetDurationShortestAndLongestModes() {
        var slot0 = ClipSlot(id: 0)
        slot0.url = URL(fileURLWithPath: "/tmp/a.mp4")
        slot0.duration = 10
        slot0.trimStart = 1
        slot0.trimEnd = 6 // trimmed = 5s

        var slot1 = ClipSlot(id: 1)
        slot1.url = URL(fileURLWithPath: "/tmp/b.mp4")
        slot1.duration = 12
        slot1.trimStart = 0
        slot1.trimEnd = 12 // trimmed = 12s

        let emptySlot = ClipSlot(id: 2)

        let shortest = LayoutCalculator.targetDuration(for: [slot0, slot1, emptySlot], mode: .shortest)
        let longest = LayoutCalculator.targetDuration(for: [slot0, slot1, emptySlot], mode: .longestLoop)

        XCTAssertEqual(shortest, 5.0, accuracy: 0.01)
        XCTAssertEqual(longest, 12.0, accuracy: 0.01)
    }

    func testCustomGridLayoutsAndDimensionSanitizer() {
        // Odd sizes must snap to even H.264 dimensions and clamp bounds
        let odd = CanvasDimensionHelper.sanitizedSize(width: 1081, height: 1923)
        XCTAssertEqual(Int(odd.width), 1080)
        XCTAssertEqual(Int(odd.height), 1922)

        let tiny = CanvasDimensionHelper.sanitizedSize(width: 100, height: 9999)
        XCTAssertEqual(Int(tiny.width), 320)
        XCTAssertEqual(Int(tiny.height), 3840)

        let ratio3x4 = CanvasDimensionHelper.sizeForAspectRatio(ratioW: 3, ratioH: 4)
        XCTAssertEqual(Int(ratio3x4.width), 1080)
        XCTAssertEqual(Int(ratio3x4.height), 1440)

        let custom6 = CollageLayout.customGrid(rows: 3, columns: 2)
        let rects6 = LayoutCalculator.slotRectsTopLeft(
            layout: custom6,
            canvasSize: ratio3x4,
            spacing: 12,
            outerPadding: 16
        )
        XCTAssertEqual(rects6.count, 6)
        for i in 0..<rects6.count {
            for j in (i + 1)..<rects6.count {
                XCTAssertFalse(rects6[i].intersects(rects6[j]))
            }
        }
    }

    func testEndToEndVideoCollageExport9x16() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-collage-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let clipA = tmpDir.appendingPathComponent("clipA.mp4")
        let clipB = tmpDir.appendingPathComponent("clipB.mp4")
        let outputURL = tmpDir.appendingPathComponent("collage.mp4")

        try await Self.generateSyntheticMP4(
            url: clipA,
            size: CGSize(width: 640, height: 360),
            durationSeconds: 0.6,
            r: 230, g: 60, b: 80
        )
        try await Self.generateSyntheticMP4(
            url: clipB,
            size: CGSize(width: 360, height: 640),
            durationSeconds: 1.0,
            r: 50, g: 160, b: 240
        )

        var slot0 = ClipSlot(id: 0)
        slot0.url = clipA
        slot0.duration = 0.6
        slot0.naturalSize = CGSize(width: 640, height: 360)
        slot0.trimStart = 0
        slot0.trimEnd = 0.6

        var slot1 = ClipSlot(id: 1)
        slot1.url = clipB
        slot1.duration = 1.0
        slot1.naturalSize = CGSize(width: 360, height: 640)
        slot1.trimStart = 0
        slot1.trimEnd = 1.0

        let config = CollageRenderConfig(
            aspectRatio: .tiktok9x16,
            layout: .splitVertical,
            slots: [slot0, slot1],
            spacing: 12,
            outerPadding: 16,
            cornerRadius: 24,
            backgroundColor: CIColor.black,
            durationMode: .longestLoop,
            frameRate: 30
        )

        let exporter = CollageExporter()
        let exported = try await exporter.export(config: config, outputURL: outputURL) { _ in }

        XCTAssertTrue(FileManager.default.fileExists(atPath: exported.path))
        let outAsset = AVURLAsset(url: exported)
        let outDuration = try await CMTimeGetSeconds(outAsset.load(.duration))
        XCTAssertGreaterThan(outDuration, 0.85)
        XCTAssertLessThan(outDuration, 1.15)

        let outTracks = try await outAsset.loadTracks(withMediaType: .video)
        let outTrack = try XCTUnwrap(outTracks.first)
        let outSize = try await outTrack.load(.naturalSize)
        XCTAssertEqual(outSize.width, 1080, accuracy: 1.0)
        XCTAssertEqual(outSize.height, 1920, accuracy: 1.0)
    }

    private static func generateSyntheticMP4(
        url: URL,
        size: CGSize,
        durationSeconds: Double,
        r: UInt8,
        g: UInt8,
        b: UInt8
    ) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attrs
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let frameCount = max(2, Int(durationSeconds * Double(fps)))

        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(size.width),
                Int(size.height),
                kCVPixelFormatType_32BGRA,
                attrs as CFDictionary,
                &buffer
            )
            if let px = buffer {
                CVPixelBufferLockBaseAddress(px, [])
                if let base = CVPixelBufferGetBaseAddress(px) {
                    let bytesPerRow = CVPixelBufferGetBytesPerRow(px)
                    let ptr = base.assumingMemoryBound(to: UInt8.self)
                    for y in 0..<Int(size.height) {
                        let row = ptr.advanced(by: y * bytesPerRow)
                        for x in 0..<Int(size.width) {
                            let idx = x * 4
                            row[idx] = b
                            row[idx + 1] = g
                            row[idx + 2] = r
                            row[idx + 3] = 255
                        }
                    }
                }
                CVPixelBufferUnlockBaseAddress(px, [])
                let pts = CMTime(value: CMTimeValue(frame), timescale: fps)
                adaptor.append(px, withPresentationTime: pts)
            }
        }

        input.markAsFinished()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writer.finishWriting { cont.resume() }
        }
        if let err = writer.error {
            throw err
        }
    }
}
