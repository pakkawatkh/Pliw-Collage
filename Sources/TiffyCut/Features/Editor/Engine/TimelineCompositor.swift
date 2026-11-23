import AppKit
import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

public struct TimelineVideoLayerDescriptor: Sendable {
    public let trackID: CMPersistentTrackID
    public let startTime: Double
    public let endTime: Double
    public let preferredTransform: CGAffineTransform
    public let scale: CGFloat
    public let positionX: CGFloat
    public let positionY: CGFloat
    public let rotationDegrees: Double
    public let opacity: Double
    public let isFlippedHorizontal: Bool
    public let adjustments: ColorAdjustments
    public let transitionIn: TransitionType
    public let transitionDuration: Double
    public let zIndex: Int

    public init(
        trackID: CMPersistentTrackID,
        startTime: Double,
        endTime: Double,
        preferredTransform: CGAffineTransform,
        scale: CGFloat,
        positionX: CGFloat,
        positionY: CGFloat,
        rotationDegrees: Double,
        opacity: Double,
        isFlippedHorizontal: Bool,
        adjustments: ColorAdjustments,
        transitionIn: TransitionType,
        transitionDuration: Double,
        zIndex: Int
    ) {
        self.trackID = trackID
        self.startTime = startTime
        self.endTime = endTime
        self.preferredTransform = preferredTransform
        self.scale = scale
        self.positionX = positionX
        self.positionY = positionY
        self.rotationDegrees = rotationDegrees
        self.opacity = opacity
        self.isFlippedHorizontal = isFlippedHorizontal
        self.adjustments = adjustments
        self.transitionIn = transitionIn
        self.transitionDuration = transitionDuration
        self.zIndex = zIndex
    }
}

public struct TimelineTextLayerDescriptor: Sendable {
    public let startTime: Double
    public let endTime: Double
    public let style: TextOverlayStyle
    public let scale: CGFloat
    public let positionX: CGFloat
    public let positionY: CGFloat
    public let rotationDegrees: Double
    public let opacity: Double

    public init(
        startTime: Double,
        endTime: Double,
        style: TextOverlayStyle,
        scale: CGFloat,
        positionX: CGFloat,
        positionY: CGFloat,
        rotationDegrees: Double,
        opacity: Double
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.style = style
        self.scale = scale
        self.positionX = positionX
        self.positionY = positionY
        self.rotationDegrees = rotationDegrees
        self.opacity = opacity
    }
}

public final class TimelineCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    public let timeRange: CMTimeRange
    public let enablePostProcessing: Bool = false
    public let containsTweening: Bool = true
    public let requiredSourceTrackIDs: [NSValue]?
    public let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    public let renderSize: CGSize
    public let videoLayers: [TimelineVideoLayerDescriptor]
    public let textLayers: [TimelineTextLayerDescriptor]

    public init(
        timeRange: CMTimeRange,
        renderSize: CGSize,
        videoLayers: [TimelineVideoLayerDescriptor],
        textLayers: [TimelineTextLayerDescriptor]
    ) {
        self.timeRange = timeRange
        self.renderSize = renderSize
        self.videoLayers = videoLayers.sorted { $0.zIndex < $1.zIndex }
        self.textLayers = textLayers
        let uniqueTrackIDs = Array(Set(videoLayers.map { $0.trackID }))
        self.requiredSourceTrackIDs = uniqueTrackIDs.map { NSNumber(value: $0) }
        super.init()
    }
}

public final class TimelineCompositor: NSObject, AVVideoCompositing {
    private static let sharedCIContext: CIContext = {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return CIContext(options: [
            .workingColorSpace: colorSpace,
            .outputColorSpace: colorSpace,
            .useSoftwareRenderer: false
        ])
    }()

    private let renderQueue = DispatchQueue(label: "com.local.tiffy-cut.timeline.compositor", qos: .userInitiated)
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

            guard let instruction = asyncVideoCompositionRequest.videoCompositionInstruction as? TimelineCompositionInstruction else {
                asyncVideoCompositionRequest.finish(with: NSError(
                    domain: "TiffyCut",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid timeline instruction"]
                ))
                return
            }

            guard let outputBuffer = asyncVideoCompositionRequest.renderContext.newPixelBuffer() else {
                asyncVideoCompositionRequest.finish(with: NSError(
                    domain: "TiffyCut",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to allocate pixel buffer"]
                ))
                return
            }

            let t = CMTimeGetSeconds(asyncVideoCompositionRequest.compositionTime)
            let canvasRect = CGRect(origin: .zero, size: instruction.renderSize)
            var composite = CIImage(color: CIColor.black).cropped(to: canvasRect)

            // 1. Render active video layers in z-order
            for layer in instruction.videoLayers {
                guard t >= layer.startTime - 0.02 && t <= layer.endTime + 0.02 else { continue }
                guard let pixelBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: layer.trackID) else { continue }

                let rawImage = CIImage(cvPixelBuffer: pixelBuffer)
                let orientation = LayoutCalculator.coreImageOrientationTransform(
                    naturalSize: rawImage.extent.size,
                    preferredTransform: layer.preferredTransform
                )
                var img = rawImage.transformed(by: orientation.transform)

                // Apply color grading & filter presets
                img = Self.applyColorAdjustments(img, adjustments: layer.adjustments)

                // Fit to canvas (aspect fit for main track / overlay) + user scale, flip, rotation, translation
                let srcSize = orientation.orientedSize
                let fitScale = min(canvasRect.width / max(1, srcSize.width), canvasRect.height / max(1, srcSize.height))
                var finalScale = fitScale * max(0.05, layer.scale)
                var alpha = max(0.0, min(1.0, layer.opacity))
                var extraShiftX: CGFloat = 0

                // Transition In progress (0 -> 1)
                if layer.transitionIn != .none && layer.transitionDuration > 0.01 {
                    let elapsed = t - layer.startTime
                    if elapsed >= 0 && elapsed < layer.transitionDuration {
                        let p = max(0.0, min(1.0, elapsed / layer.transitionDuration))
                        switch layer.transitionIn {
                        case .none:
                            break
                        case .crossDissolve, .fadeBlack:
                            alpha *= p
                        case .slideLeft:
                            extraShiftX = canvasRect.width * CGFloat(1.0 - p)
                        case .zoomIn:
                            finalScale *= CGFloat(0.65 + 0.35 * p)
                            alpha *= p
                        }
                    }
                }

                // Center at origin -> flip -> scale -> rotate -> translate to canvas center + user offset
                var transform = CGAffineTransform(translationX: -srcSize.width / 2.0, y: -srcSize.height / 2.0)
                if layer.isFlippedHorizontal {
                    transform = transform.concatenating(CGAffineTransform(scaleX: -1, y: 1))
                }
                transform = transform.concatenating(CGAffineTransform(scaleX: finalScale, y: finalScale))
                if abs(layer.rotationDegrees) > 0.01 {
                    let radians = CGFloat(-layer.rotationDegrees * .pi / 180.0)
                    transform = transform.concatenating(CGAffineTransform(rotationAngle: radians))
                }
                let tx = canvasRect.midX + layer.positionX * (canvasRect.width * 0.5) + extraShiftX
                let ty = canvasRect.midY - layer.positionY * (canvasRect.height * 0.5)
                transform = transform.concatenating(CGAffineTransform(translationX: tx, y: ty))

                img = img.transformed(by: transform)

                if alpha < 0.999 {
                    img = img.applyingFilter("CIColorMatrix", parameters: [
                        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(alpha))
                    ])
                }

                composite = img.composited(over: composite).cropped(to: canvasRect)
            }

            // 2. Render active text layers on top
            for textLayer in instruction.textLayers {
                guard t >= textLayer.startTime - 0.01 && t <= textLayer.endTime + 0.01 else { continue }
                if let textCI = Self.renderTextLayer(textLayer, canvasSize: instruction.renderSize) {
                    composite = textCI.composited(over: composite).cropped(to: canvasRect)
                }
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

    private static func applyColorAdjustments(_ image: CIImage, adjustments: ColorAdjustments) -> CIImage {
        if adjustments.isDefault { return image }
        var current = image

        // Filter preset
        switch adjustments.filter {
        case .none:
            break
        case .vivid:
            current = current.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.35,
                kCIInputContrastKey: 1.1
            ])
        case .warm:
            current = current.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: 5200, y: 0)
            ])
        case .cool:
            current = current.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: 8000, y: 0)
            ])
        case .bw:
            current = current.applyingFilter("CIPhotoEffectMono")
        case .cinematic:
            current = current.applyingFilter("CIPhotoEffectProcess")
        case .fade:
            current = current.applyingFilter("CIPhotoEffectFade")
        }

        // Manual adjustments
        if abs(adjustments.brightness) > 0.001 || abs(adjustments.contrast - 1.0) > 0.001 || abs(adjustments.saturation - 1.0) > 0.001 {
            current = current.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: adjustments.brightness,
                kCIInputContrastKey: adjustments.contrast,
                kCIInputSaturationKey: adjustments.saturation
            ])
        }

        if abs(adjustments.exposure) > 0.001 {
            current = current.applyingFilter("CIExposureAdjust", parameters: [
                kCIInputEVKey: adjustments.exposure
            ])
        }

        if abs(adjustments.temperature) > 0.001 {
            let targetK = 6500.0 - adjustments.temperature * 2000.0
            current = current.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: CGFloat(targetK), y: 0)
            ])
        }

        return current
    }

    private static func renderTextLayer(_ layer: TimelineTextLayerDescriptor, canvasSize: CGSize) -> CIImage? {
        let text = layer.style.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let scaleFactor = canvasSize.width / 1080.0
        let fontSize = max(14, layer.style.fontSize * scaleFactor * max(0.3, layer.scale))
        let font = layer.style.isBold
            ? NSFont.systemFont(ofSize: fontSize, weight: .bold)
            : NSFont.systemFont(ofSize: fontSize, weight: .regular)

        let textColor = nsColor(fromHex: layer.style.textColorHex) ?? .white
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]

        if layer.style.hasShadow {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.75)
            shadow.shadowBlurRadius = 6 * scaleFactor
            shadow.shadowOffset = NSSize(width: 0, height: -2 * scaleFactor)
            attrs[.shadow] = shadow
        }

        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let maxBoxW = canvasSize.width * 0.88
        let textBounds = attrStr.boundingRect(
            with: NSSize(width: maxBoxW, height: canvasSize.height * 0.6),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        let padX: CGFloat = 24 * scaleFactor
        let padY: CGFloat = 14 * scaleFactor
        let boxW = ceil(textBounds.width + padX * 2)
        let boxH = ceil(textBounds.height + padY * 2)

        guard boxW > 4, boxH > 4 else { return nil }

        let widthInt = Int(boxW)
        let heightInt = Int(boxH)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: widthInt,
            height: heightInt,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

        if layer.style.backgroundOpacity > 0.01 {
            let bgColor = (nsColor(fromHex: layer.style.backgroundColorHex) ?? .black)
                .withAlphaComponent(layer.style.backgroundOpacity)
            bgColor.setFill()
            let bgPath = NSBezierPath(
                roundedRect: NSRect(x: 0, y: 0, width: boxW, height: boxH),
                xRadius: 14 * scaleFactor,
                yRadius: 14 * scaleFactor
            )
            bgPath.fill()
        }

        attrStr.draw(in: NSRect(x: padX, y: padY, width: ceil(textBounds.width), height: ceil(textBounds.height)))
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = ctx.makeImage() else { return nil }
        var ci = CIImage(cgImage: cgImage)

        let tx = canvasSize.width * 0.5 + layer.positionX * (canvasSize.width * 0.5) - boxW / 2.0
        let ty = canvasSize.height * 0.5 - layer.positionY * (canvasSize.height * 0.5) - boxH / 2.0
        ci = ci.transformed(by: CGAffineTransform(translationX: tx, y: ty))

        let alpha = max(0.0, min(1.0, layer.opacity))
        if alpha < 0.999 {
            ci = ci.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(alpha))
            ])
        }

        return ci
    }

    private static func nsColor(fromHex hex: String) -> NSColor? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let rgb = UInt64(cleaned, radix: 16) else { return nil }
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
