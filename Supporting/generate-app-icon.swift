import AppKit
import ImageIO
import UniformTypeIdentifiers

// Original opaque Hermes monogram. iOS applies the icon corner mask.
let destination = CommandLine.arguments.dropFirst().first ?? "Supporting/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0x22 / 255.0, green: 0x9E / 255.0, blue: 0xD9 / 255.0, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
for rect in [CGRect(x: 258, y: 248, width: 120, height: 528),
             CGRect(x: 646, y: 248, width: 120, height: 528),
             CGRect(x: 358, y: 452, width: 308, height: 120)] {
    context.addPath(CGPath(roundedRect: rect, cornerWidth: 24, cornerHeight: 24, transform: nil))
    context.fillPath()
}
let url = URL(fileURLWithPath: destination)
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(output, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(output), "PNG encoding failed")
print("Generated opaque RGB \(size)x\(size) icon: \(destination)")
