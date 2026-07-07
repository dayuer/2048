import AppKit

// 用显式 1024×1024 像素的位图渲染，避免 Retina 屏幕 2x 缩放。
let pixels = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("bitmap rep failed") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSColor(red: 0xED / 255.0, green: 0xC2 / 255.0, blue: 0x2E / 255.0, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 300, weight: .heavy),
    .foregroundColor: NSColor(red: 0xF9 / 255.0, green: 0xF6 / 255.0, blue: 0xF2 / 255.0, alpha: 1),
    .paragraphStyle: paragraph,
]
let text = NSAttributedString(string: "2048", attributes: attributes)
let textSize = text.size()
text.draw(in: NSRect(x: 0, y: (CGFloat(pixels) - textSize.height) / 2, width: CGFloat(pixels), height: textSize.height))

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png encode failed") }
let output = URL(fileURLWithPath: "Sources/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
try png.write(to: output)
print("icon written to \(output.path)")
