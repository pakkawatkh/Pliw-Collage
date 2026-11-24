#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

// Generates a crisp Apple-style frosted-glass AppIcon.icns for Pliw Collage
// with the unified Pliw App ("P.") bottom-right corner badge.
let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "Resources/AppIcon.icns"
let previewPngPath = args.count > 2 ? args[2] : nil

func renderIcon(size: Int) -> Data? {
    let s = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // 1. Standard macOS squircle (84% of canvas, centered) with soft drop shadow
    let innerSize = s * 0.84
    let inset = (s - innerSize) * 0.5
    let cardRect = CGRect(x: inset, y: inset, width: innerSize, height: innerSize)
    let cardRadius = innerSize * 0.225
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.014),
        blur: s * 0.028,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.22)
    )
    ctx.addPath(cardPath)
    ctx.setFillColor(CGColor(red: 0.28, green: 0.22, blue: 0.72, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // 2. Luminous Apple-style Violet -> Indigo -> Rose-Violet gradient background
    ctx.saveGState()
    ctx.addPath(cardPath)
    ctx.clip()

    let bgColors = [
        CGColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 1.0), // #A855F7 vibrant violet top-left
        CGColor(red: 0.39, green: 0.35, blue: 0.95, alpha: 1.0), // #6359F2 electric indigo center
        CGColor(red: 0.22, green: 0.25, blue: 0.85, alpha: 1.0)  // #3840D9 deep royal blue-indigo bottom-right
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.52, 1.0]) {
        ctx.drawLinearGradient(
            bgGrad,
            start: CGPoint(x: cardRect.minX, y: cardRect.maxY),
            end: CGPoint(x: cardRect.maxX, y: cardRect.minY),
            options: []
        )
    }

    // Soft top-left specular radial glow (matches Pliw Click luminous feel)
    let glowColors = [
        CGColor(red: 1.0, green: 0.78, blue: 0.98, alpha: 0.36),
        CGColor(red: 1.0, green: 0.78, blue: 0.98, alpha: 0.0)
    ] as CFArray
    if let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: cardRect.minX + innerSize * 0.22, y: cardRect.maxY - innerSize * 0.16),
            startRadius: 0,
            endCenter: CGPoint(x: cardRect.minX + innerSize * 0.22, y: cardRect.maxY - innerSize * 0.16),
            endRadius: innerSize * 0.68,
            options: []
        )
    }
    ctx.restoreGState()

    // Subtle inner rim highlight on squircle
    ctx.saveGState()
    let rimPath = CGPath(
        roundedRect: cardRect.insetBy(dx: s * 0.005, dy: s * 0.005),
        cornerWidth: cardRadius * 0.98,
        cornerHeight: cardRadius * 0.98,
        transform: nil
    )
    ctx.addPath(rimPath)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.24))
    ctx.setLineWidth(max(1.0, s * 0.008))
    ctx.strokePath()
    ctx.restoreGState()

    // 3. Frosted-glass 3-tile video collage grid (tall hero video tile on left + 2 stacked tiles on right)
    let gridPad = innerSize * 0.165
    let gap = innerSize * 0.06
    let gridX = cardRect.minX + gridPad
    let gridY = cardRect.minY + gridPad
    let gridW = innerSize - gridPad * 2
    let gridH = innerSize - gridPad * 2
    let tileR = innerSize * 0.095

    let leftW = gridW * 0.51 - gap * 0.5
    let rightW = gridW - leftW - gap
    let rightTileH = (gridH - gap) * 0.5

    let heroTile = CGRect(x: gridX, y: gridY, width: leftW, height: gridH)
    let topRightTile = CGRect(x: gridX + leftW + gap, y: gridY + rightTileH + gap, width: rightW, height: rightTileH)
    let botRightTile = CGRect(x: gridX + leftW + gap, y: gridY, width: rightW, height: rightTileH)

    func drawGlassTile(_ rect: CGRect, topAlpha: CGFloat, botAlpha: CGFloat, strokeAlpha: CGFloat, shadowAlpha: CGFloat) {
        let p = CGPath(roundedRect: rect, cornerWidth: tileR, cornerHeight: tileR, transform: nil)

        // Soft elevation shadow
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -s * 0.016),
            blur: s * 0.032,
            color: CGColor(red: 0.08, green: 0.04, blue: 0.28, alpha: shadowAlpha)
        )
        ctx.addPath(p)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: topAlpha * 0.5))
        ctx.fillPath()
        ctx.restoreGState()

        // Frosted white vertical gradient fill
        ctx.saveGState()
        ctx.addPath(p)
        ctx.clip()
        let cols = [
            CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: topAlpha),
            CGColor(red: 0.90, green: 0.93, blue: 1.0, alpha: botAlpha)
        ] as CFArray
        if let g = CGGradient(colorsSpace: colorSpace, colors: cols, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(
                g,
                start: CGPoint(x: rect.midX, y: rect.maxY),
                end: CGPoint(x: rect.midX, y: rect.minY),
                options: []
            )
        }
        ctx.restoreGState()

        // Crisp frosted glass border
        ctx.saveGState()
        ctx.addPath(p)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: strokeAlpha))
        ctx.setLineWidth(max(1.0, s * 0.008))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // Hero left vertical video tile (brightest frosted white)
    drawGlassTile(heroTile, topAlpha: 0.98, botAlpha: 0.88, strokeAlpha: 0.9, shadowAlpha: 0.30)
    // Secondary right tiles (layered translucent frosted glass)
    drawGlassTile(topRightTile, topAlpha: 0.78, botAlpha: 0.62, strokeAlpha: 0.65, shadowAlpha: 0.22)
    drawGlassTile(botRightTile, topAlpha: 0.58, botAlpha: 0.44, strokeAlpha: 0.50, shadowAlpha: 0.18)

    // Rounded Play Triangle inside hero left tile (tinted with icon indigo so it reads like carved glass)
    let playSize = heroTile.width * 0.44
    let px = heroTile.midX + playSize * 0.07
    let py = heroTile.midY
    let p1 = CGPoint(x: px - playSize * 0.44, y: py + playSize * 0.52)
    let p2 = CGPoint(x: px - playSize * 0.44, y: py - playSize * 0.52)
    let p3 = CGPoint(x: px + playSize * 0.54, y: py)

    let playPath = CGMutablePath()
    let cornerR = playSize * 0.14
    playPath.move(to: CGPoint(x: (p1.x + p2.x) * 0.5, y: (p1.y + p2.y) * 0.5))
    playPath.addArc(tangent1End: p1, tangent2End: p3, radius: cornerR)
    playPath.addArc(tangent1End: p3, tangent2End: p2, radius: cornerR)
    playPath.addArc(tangent1End: p2, tangent2End: p1, radius: cornerR)
    playPath.closeSubpath()

    ctx.saveGState()
    ctx.addPath(playPath)
    ctx.clip()
    let playCols = [
        CGColor(red: 0.54, green: 0.27, blue: 0.92, alpha: 1.0),
        CGColor(red: 0.26, green: 0.28, blue: 0.86, alpha: 1.0)
    ] as CFArray
    if let pg = CGGradient(colorsSpace: colorSpace, colors: playCols, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            pg,
            start: CGPoint(x: px, y: py + playSize * 0.55),
            end: CGPoint(x: px, y: py - playSize * 0.55),
            options: []
        )
    }
    ctx.restoreGState()

    // 4. Unified Pliw App ("P.") bottom-right corner badge (26% size, 0.05 inset)
    let badgeSize = s * 0.26
    let badgeInset = s * 0.05
    let badgeRect = CGRect(
        x: s - badgeInset - badgeSize,
        y: badgeInset,
        width: badgeSize,
        height: badgeSize
    )
    let badgeCorner = badgeSize * 0.25
    let borderW = max(2.0, badgeSize * 0.065)

    // White cutout ring + soft shadow
    ctx.saveGState()
    let ringRect = badgeRect.insetBy(dx: -borderW * 0.5, dy: -borderW * 0.5)
    let ringPath = CGPath(
        roundedRect: ringRect,
        cornerWidth: badgeCorner + borderW * 0.35,
        cornerHeight: badgeCorner + borderW * 0.35,
        transform: nil
    )
    ctx.setShadow(
        offset: CGSize(width: 0, height: -badgeSize * 0.045),
        blur: badgeSize * 0.12,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.42)
    )
    ctx.addPath(ringPath)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
    ctx.fillPath()
    ctx.restoreGState()

    // Dark macOS squircle fill
    ctx.saveGState()
    let badgePath = CGPath(roundedRect: badgeRect, cornerWidth: badgeCorner, cornerHeight: badgeCorner, transform: nil)
    ctx.addPath(badgePath)
    ctx.clip()
    let badgeGradCols = [
        CGColor(red: 0x2c / 255.0, green: 0x2c / 255.0, blue: 0x2e / 255.0, alpha: 1.0),
        CGColor(red: 0x14 / 255.0, green: 0x14 / 255.0, blue: 0x16 / 255.0, alpha: 1.0)
    ] as CFArray
    if let bg = CGGradient(colorsSpace: colorSpace, colors: badgeGradCols, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            bg,
            start: CGPoint(x: badgeRect.midX, y: badgeRect.maxY),
            end: CGPoint(x: badgeRect.midX, y: badgeRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Subtle inner rim on badge
    ctx.saveGState()
    let bRim = CGPath(
        roundedRect: badgeRect.insetBy(dx: badgeSize * 0.015, dy: badgeSize * 0.015),
        cornerWidth: badgeCorner * 0.94,
        cornerHeight: badgeCorner * 0.94,
        transform: nil
    )
    ctx.addPath(bRim)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
    ctx.setLineWidth(max(1.0, badgeSize * 0.02))
    ctx.strokePath()
    ctx.restoreGState()

    // Geometric "P." monogram inside badge
    func mapPt(_ svgX: CGFloat, _ svgY: CGFloat) -> CGPoint {
        CGPoint(
            x: badgeRect.minX + (svgX / 64.0) * badgeSize,
            y: badgeRect.minY + (1.0 - svgY / 64.0) * badgeSize
        )
    }
    ctx.saveGState()
    let pPath = CGMutablePath()
    pPath.move(to: mapPt(22.5, 45.0))
    pPath.addLine(to: mapPt(22.5, 19.5))
    pPath.addLine(to: mapPt(34.5, 19.5))
    pPath.addCurve(to: mapPt(44.0, 28.2), control1: mapPt(40.2, 19.5), control2: mapPt(44.0, 23.0))
    pPath.addCurve(to: mapPt(34.5, 36.8), control1: mapPt(44.0, 33.4), control2: mapPt(40.2, 36.8))
    pPath.addLine(to: mapPt(22.5, 36.8))

    ctx.addPath(pPath)
    ctx.setStrokeColor(CGColor(red: 0xf5 / 255.0, green: 0xf5 / 255.0, blue: 0xf7 / 255.0, alpha: 1.0))
    ctx.setLineWidth(max(1.2, badgeSize * (5.2 / 64.0)))
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    if size >= 32 {
        let dotC = mapPt(43.0, 43.2)
        let dotR = badgeSize * (3.0 / 64.0)
        ctx.setFillColor(CGColor(red: 0xa1 / 255.0, green: 0xa1 / 255.0, blue: 0xa6 / 255.0, alpha: 1.0))
        ctx.fillEllipse(in: CGRect(x: dotC.x - dotR, y: dotC.y - dotR, width: dotR * 2, height: dotR * 2))
    }
    ctx.restoreGState()

    guard let cgImg = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImg)
    return rep.representation(using: .png, properties: [:])
}

let tmpIconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("PliwCollage.iconset")
try? FileManager.default.removeItem(at: tmpIconset)
try FileManager.default.createDirectory(at: tmpIconset, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, px) in specs {
    if let png = renderIcon(size: px) {
        try png.write(to: tmpIconset.appendingPathComponent(name))
        if px == 512, let previewPngPath = previewPngPath {
            try png.write(to: URL(fileURLWithPath: previewPngPath))
        }
    }
}

let outURL = URL(fileURLWithPath: outPath)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", tmpIconset.path, "-o", outURL.path]
try proc.run()
proc.waitUntilExit()
try? FileManager.default.removeItem(at: tmpIconset)

if proc.terminationStatus == 0 {
    print("✅ Generated icon at \(outURL.path)")
} else {
    fputs("❌ iconutil failed with status \(proc.terminationStatus)\n", stderr)
    exit(1)
}
