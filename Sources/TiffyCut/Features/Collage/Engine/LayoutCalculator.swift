import CoreGraphics
import Foundation

/// Pure geometry and transform math for collage layout, aspect-fill framing, and video orientation.
public enum LayoutCalculator {

    /// Computes slot pixel rectangles in **top-left** origin coordinates (for SwiftUI / UI layout).
    public static func slotRectsTopLeft(
        layout: CollageLayout,
        canvasSize: CGSize,
        spacing: CGFloat,
        outerPadding: CGFloat
    ) -> [CGRect] {
        let safePad = max(0, min(outerPadding, min(canvasSize.width, canvasSize.height) * 0.25))
        let safeSpacing = max(0, spacing)
        let innerRect = CGRect(
            x: safePad,
            y: safePad,
            width: max(1, canvasSize.width - safePad * 2),
            height: max(1, canvasSize.height - safePad * 2)
        )

        let epsilon: CGFloat = 0.0001
        return layout.normalizedRects.map { norm in
            let rawX = innerRect.minX + norm.minX * innerRect.width
            let rawY = innerRect.minY + norm.minY * innerRect.height
            let rawMaxX = innerRect.minX + norm.maxX * innerRect.width
            let rawMaxY = innerRect.minY + norm.maxY * innerRect.height

            let insetLeft: CGFloat = norm.minX > epsilon ? safeSpacing / 2 : 0
            let insetRight: CGFloat = norm.maxX < (1 - epsilon) ? safeSpacing / 2 : 0
            let insetTop: CGFloat = norm.minY > epsilon ? safeSpacing / 2 : 0
            let insetBottom: CGFloat = norm.maxY < (1 - epsilon) ? safeSpacing / 2 : 0

            let x = rawX + insetLeft
            let y = rawY + insetTop
            let width = max(1, (rawMaxX - rawX) - insetLeft - insetRight)
            let height = max(1, (rawMaxY - rawY) - insetTop - insetBottom)
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }

    /// Computes slot pixel rectangles in **bottom-left** origin coordinates (for CoreImage rendering).
    public static func slotRectsBottomLeft(
        layout: CollageLayout,
        canvasSize: CGSize,
        spacing: CGFloat,
        outerPadding: CGFloat
    ) -> [CGRect] {
        slotRectsTopLeft(
            layout: layout,
            canvasSize: canvasSize,
            spacing: spacing,
            outerPadding: outerPadding
        ).map { rect in
            CGRect(
                x: rect.minX,
                y: canvasSize.height - rect.maxY,
                width: rect.width,
                height: rect.height
            )
        }
    }

    /// Computes the CoreImage (bottom-left origin) affine transform that applies an AVFoundation
    /// `preferredTransform` (which is defined in top-left origin space) and normalizes the result
    /// to origin `(0, 0)`.
    public static func coreImageOrientationTransform(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform
    ) -> (transform: CGAffineTransform, orientedSize: CGSize) {
        guard naturalSize.width > 0 && naturalSize.height > 0 else {
            return (.identity, .zero)
        }

        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let outSize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))

        let flipIn = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: naturalSize.height)
        let normTransform = preferredTransform.concatenating(
            CGAffineTransform(translationX: -transformedRect.minX, y: -transformedRect.minY)
        )
        let flipOut = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: outSize.height)

        let combined = flipIn.concatenating(normTransform).concatenating(flipOut)
        return (combined, outSize)
    }

    /// Computes the aspect-fill + user zoom + user pan transform mapping an upright source image
    /// of `sourceSize` (at origin 0,0) into `targetRect` (in bottom-left CoreImage coordinates).
    /// `offsetX` and `offsetY` are in `[-1...1]` in UI coordinates (+offsetY moves content down).
    public static func aspectFillTransform(
        sourceSize: CGSize,
        into targetRect: CGRect,
        zoom: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) -> CGAffineTransform {
        guard sourceSize.width > 0, sourceSize.height > 0,
              targetRect.width > 0, targetRect.height > 0 else {
            return .identity
        }

        let safeZoom = max(1.0, zoom)
        let baseScale = max(targetRect.width / sourceSize.width, targetRect.height / sourceSize.height)
        let finalScale = baseScale * safeZoom

        let scaledW = sourceSize.width * finalScale
        let scaledH = sourceSize.height * finalScale

        let maxPanX = max(0, (scaledW - targetRect.width) / 2.0)
        let maxPanY = max(0, (scaledH - targetRect.height) / 2.0)

        let clampedX = max(-1.0, min(1.0, offsetX))
        let clampedY = max(-1.0, min(1.0, offsetY))

        // In CoreImage bottom-left coords, positive UI offsetY (moving content downward) is negative Y.
        let panX = clampedX * maxPanX
        let panY = -clampedY * maxPanY

        let originX = targetRect.midX - scaledW / 2.0 + panX
        let originY = targetRect.midY - scaledH / 2.0 + panY

        return CGAffineTransform(scaleX: finalScale, y: finalScale)
            .concatenating(CGAffineTransform(translationX: originX, y: originY))
    }

    /// Computes the target collage duration given active clips and duration mode.
    public static func targetDuration(for slots: [ClipSlot], mode: DurationMode) -> Double {
        let durations = slots.compactMap { $0.hasVideo ? $0.trimmedDuration : nil }
        guard !durations.isEmpty else { return 0 }
        switch mode {
        case .shortest:
            return durations.min() ?? 0
        case .longestLoop:
            return durations.max() ?? 0
        }
    }
}
