import AVFoundation
import CoreImage
import CoreVideo
import Foundation

public struct CompositorSlotDescriptor: Sendable {
    public let trackID: CMPersistentTrackID
    public let naturalSize: CGSize
    public let preferredTransform: CGAffineTransform
    public let targetRectBottomLeft: CGRect
    public let cornerRadius: CGFloat
    public let scale: CGFloat
    public let offsetX: CGFloat
    public let offsetY: CGFloat

    public init(
        trackID: CMPersistentTrackID,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        targetRectBottomLeft: CGRect,
        cornerRadius: CGFloat,
        scale: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) {
        self.trackID = trackID
        self.naturalSize = naturalSize
        self.preferredTransform = preferredTransform
        self.targetRectBottomLeft = targetRectBottomLeft
        self.cornerRadius = cornerRadius
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

public final class CollageCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    public let timeRange: CMTimeRange
    public let enablePostProcessing: Bool = false
    public let containsTweening: Bool = true
    public let requiredSourceTrackIDs: [NSValue]?
    public let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    public let renderSize: CGSize
    public let backgroundColor: CIColor
    public let slots: [CompositorSlotDescriptor]

    public init(
        timeRange: CMTimeRange,
        renderSize: CGSize,
        backgroundColor: CIColor,
        slots: [CompositorSlotDescriptor]
    ) {
        self.timeRange = timeRange
        self.renderSize = renderSize
        self.backgroundColor = backgroundColor
        self.slots = slots
        self.requiredSourceTrackIDs = slots.map { NSNumber(value: $0.trackID) }
        super.init()
    }
}

public final class CollageVideoCompositor: NSObject, AVVideoCompositing {
    private static let sharedCIContext: CIContext = {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return CIContext(options: [
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace,
            .useSoftwareRenderer: false
        ])
    }()

    private let renderQueue = DispatchQueue(label: "com.local.pliw-cut.compositor", qos: .userInitiated)
    private var shouldCancelPending = false

    public var sourcePixelBufferAttributes: [String: any Sendable]? {
        [
            kCVPixelBufferPixelFormatTypeKey as String: [
                Int(kCVPixelFormatType_32BGRA)
            ]
        ]
    }

    public var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
    }

    public func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    public func cancelAllPendingVideoCompositionRequests() {
        shouldCancelPending = true
        renderQueue.async { [weak self] in
            self?.shouldCancelPending = false
        }
    }

    public func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        renderQueue.async { [weak self] in
            guard let self else { return }
            if self.shouldCancelPending {
                asyncVideoCompositionRequest.finishCancelledRequest()
                return
            }

            guard let instruction = asyncVideoCompositionRequest.videoCompositionInstruction as? CollageCompositionInstruction else {
                asyncVideoCompositionRequest.finish(with: NSError(
                    domain: "ClipCollage",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid composition instruction"]
                ))
                return
            }

            guard let outputBuffer = asyncVideoCompositionRequest.renderContext.newPixelBuffer() else {
                asyncVideoCompositionRequest.finish(with: NSError(
                    domain: "ClipCollage",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to allocate output pixel buffer"]
                ))
                return
            }

            let canvasRect = CGRect(origin: .zero, size: instruction.renderSize)
            var composite = CIImage(color: instruction.backgroundColor).cropped(to: canvasRect)

            for slot in instruction.slots {
                guard let pixelBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: slot.trackID) else {
                    continue
                }

                let rawImage = CIImage(cvPixelBuffer: pixelBuffer)
                let rawSize = rawImage.extent.size
                let orientation = LayoutCalculator.coreImageOrientationTransform(
                    naturalSize: rawSize,
                    preferredTransform: slot.preferredTransform
                )

                let upright = rawImage.transformed(by: orientation.transform)
                let fillTransform = LayoutCalculator.aspectFillTransform(
                    sourceSize: orientation.orientedSize,
                    into: slot.targetRectBottomLeft,
                    zoom: slot.scale,
                    offsetX: slot.offsetX,
                    offsetY: slot.offsetY
                )

                let placed = upright
                    .transformed(by: fillTransform)
                    .cropped(to: slot.targetRectBottomLeft)

                let radius = min(
                    slot.cornerRadius,
                    min(slot.targetRectBottomLeft.width, slot.targetRectBottomLeft.height) * 0.5
                )

                if radius > 0.5, let roundedMask = Self.makeRoundedRectMask(rect: slot.targetRectBottomLeft, radius: radius) {
                    if let blendFilter = CIFilter(name: "CIBlendWithMask") {
                        blendFilter.setValue(placed, forKey: kCIInputImageKey)
                        blendFilter.setValue(composite, forKey: kCIInputBackgroundImageKey)
                        blendFilter.setValue(roundedMask, forKey: kCIInputMaskImageKey)
                        if let output = blendFilter.outputImage {
                            composite = output.cropped(to: canvasRect)
                            continue
                        }
                    }
                }

                composite = placed.composited(over: composite).cropped(to: canvasRect)
            }

            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            Self.sharedCIContext.render(
                composite,
                to: outputBuffer,
                bounds: canvasRect,
                colorSpace: colorSpace
            )

            asyncVideoCompositionRequest.finish(withComposedVideoFrame: outputBuffer)
        }
    }

    private static func makeRoundedRectMask(rect: CGRect, radius: CGFloat) -> CIImage? {
        guard let filter = CIFilter(name: "CIRoundedRectangleGenerator") else { return nil }
        filter.setValue(CIVector(cgRect: rect), forKey: "inputExtent")
        filter.setValue(radius, forKey: "inputRadius")
        filter.setValue(CIColor.white, forKey: "inputColor")
        return filter.outputImage?.cropped(to: rect)
    }
}
