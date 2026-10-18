import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("Usage: swift generate_squircle_icon.swift <input-image> <output-png>")
    exit(1)
}

let inputPath = args[1]
let outputPath = args[2]

guard let inputImage = NSImage(contentsOfFile: inputPath) else {
    print("Failed to load input image: \(inputPath)")
    exit(1)
}

let canvasSize = NSSize(width: 1024, height: 1024)
let iconSize: CGFloat = 824
let originX: CGFloat = (canvasSize.width - iconSize) / 2.0 // 100
let originY: CGFloat = (canvasSize.height - iconSize) / 2.0 // 100
let iconRect = NSRect(x: originX, y: originY, width: iconSize, height: iconSize)
let cornerRadius: CGFloat = 185.0

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = context
let cgContext = context.cgContext

// Clear canvas with transparency
cgContext.clear(CGRect(origin: .zero, size: canvasSize))

// 1. Draw subtle macOS app icon drop shadow
cgContext.saveGState()
let shadowColor = NSColor.black.withAlphaComponent(0.28).cgColor
cgContext.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: shadowColor)

let squirclePath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
NSColor.black.setFill()
squirclePath.fill()
cgContext.restoreGState()

// 2. Clip to the rounded rect and draw image
cgContext.saveGState()
squirclePath.addClip()
inputImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)

// 3. Subtle inner stroke border to match macOS HIG
let strokePath = NSBezierPath(roundedRect: iconRect.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius - 0.5, yRadius: cornerRadius - 0.5)
strokePath.lineWidth = 1.0
NSColor.white.withAlphaComponent(0.15).setStroke()
strokePath.stroke()

cgContext.restoreGState()

NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: .png, properties: [:]) else {
    print("Failed to encode PNG")
    exit(1)
}

try pngData.write(to: URL(fileURLWithPath: outputPath))
print("✅ Successfully generated macOS squircle icon at \(outputPath)")
