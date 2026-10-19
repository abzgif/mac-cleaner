import Cocoa

let width: CGFloat = 600
let height: CGFloat = 380
let scale: CGFloat = 2.0 // Retina @2x

let pixelWidth = Int(width * scale)
let pixelHeight = Int(height * scale)

guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
    fatalError("Failed to create color space")
}

guard let context = CGContext(
    data: nil,
    width: pixelWidth,
    height: pixelHeight,
    bitsPerComponent: 8,
    bytesPerRow: pixelWidth * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create CGContext")
}

let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = graphicsContext

context.scaleBy(x: scale, y: scale)

// 1. Background fill: Modern subtle dark tone matching macOS dark aesthetic
let rect = CGRect(x: 0, y: 0, width: width, height: height)
let bgPath = NSBezierPath(rect: rect)
NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 1.0).setFill()
bgPath.fill()

// 2. Subtle decorative target areas (subtle rounded outlines where icons sit)
let leftTarget = CGRect(x: 75, y: 110, width: 130, height: 130)
let rightTarget = CGRect(x: 395, y: 110, width: 130, height: 130)

let targetPathLeft = NSBezierPath(roundedRect: leftTarget, xRadius: 18, yRadius: 18)
NSColor.white.withAlphaComponent(0.04).setFill()
targetPathLeft.fill()
NSColor.white.withAlphaComponent(0.08).setStroke()
targetPathLeft.lineWidth = 1.0
targetPathLeft.stroke()

let targetPathRight = NSBezierPath(roundedRect: rightTarget, xRadius: 18, yRadius: 18)
NSColor.white.withAlphaComponent(0.04).setFill()
targetPathRight.fill()
NSColor.white.withAlphaComponent(0.08).setStroke()
targetPathRight.lineWidth = 1.0
targetPathRight.stroke()

// 3. Central Arrow (drawn with sleek vector path)
let arrowColor = NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.95, alpha: 0.75)
let arrowPath = NSBezierPath()

// Arrow shaft
let shaftY: CGFloat = 175.0
let startX: CGFloat = 265.0
let endX: CGFloat = 330.0

arrowPath.move(to: NSPoint(x: startX, y: shaftY))
arrowPath.line(to: NSPoint(x: endX, y: shaftY))
arrowPath.lineWidth = 3.5
arrowPath.lineCapStyle = .round
arrowColor.setStroke()
arrowPath.stroke()

// Arrow head
let headPath = NSBezierPath()
headPath.move(to: NSPoint(x: endX - 10, y: shaftY + 8))
headPath.line(to: NSPoint(x: endX + 4, y: shaftY))
headPath.line(to: NSPoint(x: endX - 10, y: shaftY - 8))
headPath.lineWidth = 3.5
headPath.lineCapStyle = .round
headPath.lineJoinStyle = .round
arrowColor.setStroke()
headPath.stroke()

// 4. Instructional Label at the bottom
let text = "Drag CleanMac to Applications to install"
let font = NSFont.systemFont(ofSize: 13, weight: .medium)
let textColor = NSColor.white.withAlphaComponent(0.65)

let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: textColor
]

let str = NSAttributedString(string: text, attributes: attributes)
let textSize = str.size()
let textPoint = NSPoint(x: (width - textSize.width) / 2.0, y: 38.0)
str.draw(at: textPoint)

// Export to PNG
guard let cgImage = context.makeImage() else {
    fatalError("Failed to make CGImage")
}

let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
bitmapRep.size = NSSize(width: width, height: height)

guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to convert to PNG")
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "background.png"
let outputURL = URL(fileURLWithPath: outputPath)

try! pngData.write(to: outputURL)
print("✅ Background image generated at: \(outputPath)")
