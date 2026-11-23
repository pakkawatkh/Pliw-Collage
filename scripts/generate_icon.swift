#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

// Generates a crisp macOS AppIcon.icns for ClipCollage in Resources/AppIcon.icns
let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "Resources/AppIcon.icns"

func renderIcon(size: Int) -> Data? {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }

    let inset = s * 0.08
    let cardRect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cardRadius = s * 0.22

    // Rounded background with vibrant TikTok/IG inspired gradient
    let cardPath = CGPath(roundedRect: cardRect, cornerWidth: cardRadius, cornerHeight: cardRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(cardPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.11, green: 0.09, blue: 0.22, alpha: 1.0),
        CGColor(red: 0.22, green: 0.12, blue: 0.36, alpha: 1.0),
        CGColor(red: 0.07, green: 0.16, blue: 0.28, alpha: 1.0)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.55, 1.0]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: cardRect.minX, y: cardRect.maxY),
            end: CGPoint(x: cardRect.maxX, y: cardRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Draw 3-tile collage motif (1 wide top + 2 bottom tiles)
    let pad = s * 0.20
    let gap = s * 0.045
    let innerW = s - pad * 2
    let innerH = s - pad * 2
    let tileR = s * 0.065

    let topRect = CGRect(x: pad, y: pad + innerH * 0.5 + gap * 0.5, width: innerW, height: innerH * 0.5 - gap * 0.5)
    let botLeft = CGRect(x: pad, y: pad, width: innerW * 0.5 - gap * 0.5, height: innerH * 0.5 - gap * 0.5)
    let botRight = CGRect(x: pad + innerW * 0.5 + gap * 0.5, y: pad, width: innerW * 0.5 - gap * 0.5, height: innerH * 0.5 - gap * 0.5)

    func fillTile(_ rect: CGRect, c1: CGColor, c2: CGColor) {
        let p = CGPath(roundedRect: rect, cornerWidth: tileR, cornerHeight: tileR, transform: nil)
        ctx.saveGState()
        ctx.addPath(p)
        ctx.clip()
        if let g = CGGradient(colorsSpace: colorSpace, colors: [c1, c2] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
        }
        ctx.restoreGState()
    }

    fillTile(
        topRect,
        c1: CGColor(red: 1.0, green: 0.24, blue: 0.45, alpha: 1.0),
        c2: CGColor(red: 1.0, green: 0.52, blue: 0.25, alpha: 1.0)
    )
    fillTile(
        botLeft,
        c1: CGColor(red: 0.14, green: 0.82, blue: 0.94, alpha: 1.0),
        c2: CGColor(red: 0.22, green: 0.48, blue: 0.98, alpha: 1.0)
    )
    fillTile(
        botRight,
        c1: CGColor(red: 0.62, green: 0.34, blue: 0.98, alpha: 1.0),
        c2: CGColor(red: 0.95, green: 0.28, blue: 0.72, alpha: 1.0)
    )

    // White play triangle in the top tile
    let triSize = topRect.height * 0.42
    let cx = topRect.midX + triSize * 0.08
    let cy = topRect.midY
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx - triSize * 0.45, y: cy - triSize * 0.52))
    ctx.addLine(to: CGPoint(x: cx - triSize * 0.45, y: cy + triSize * 0.52))
    ctx.addLine(to: CGPoint(x: cx + triSize * 0.55, y: cy))
    ctx.closePath()
    ctx.fillPath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let tmpIconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ClipCollage.iconset")
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
