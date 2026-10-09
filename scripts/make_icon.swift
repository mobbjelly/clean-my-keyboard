import Foundation
import AppKit

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) {
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.045
    let backgroundRect = bounds.insetBy(dx: inset, dy: inset)
    let cornerRadius = size * 0.22

    let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: cornerRadius, yRadius: cornerRadius)
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.18, green: 0.45, blue: 0.96, alpha: 1),
        NSColor(srgbRed: 0.15, green: 0.75, blue: 0.70, alpha: 1)
    ])
    gradient?.draw(in: backgroundPath, angle: -55)

    guard let symbol = NSImage(systemSymbolName: "keyboard.fill", accessibilityDescription: nil),
          let configured = symbol.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size * 0.3, weight: .medium)),
          let tinted = configured.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [NSColor.white]))
    else { return }

    let naturalSize = tinted.size
    guard naturalSize.width > 0, naturalSize.height > 0 else { return }
    let scale = (size * 0.62) / naturalSize.width
    let targetSize = NSSize(width: naturalSize.width * scale, height: naturalSize.height * scale)
    let origin = NSPoint(x: bounds.midX - targetSize.width / 2, y: bounds.midY - targetSize.height / 2)
    tinted.draw(in: NSRect(x: origin.x, y: origin.y, width: targetSize.width, height: targetSize.height))
}

func writeIcon(pixels: Int, fileName: String) {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: representation) else { return }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    drawIcon(size: CGFloat(pixels))
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = representation.representation(using: .png, properties: [:]) else { return }
    let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(fileName)
    try? data.write(to: url)
}

let variants: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for variant in variants {
    writeIcon(pixels: variant.0, fileName: variant.1)
}

print("iconset: " + outputDirectory)
