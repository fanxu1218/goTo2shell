import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
var representations: [Int: Data] = [:]
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let rect = NSRect(x: 90, y: 90, width: 844, height: 844)
        NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 190, yRadius: 190).fill()
        NSColor(calibratedRed: 0.38, green: 0.92, blue: 0.67, alpha: 1).setStroke()
        let prompt = NSBezierPath()
        prompt.lineWidth = 64
        prompt.lineCapStyle = .round
        prompt.lineJoinStyle = .round
        prompt.move(to: NSPoint(x: 282, y: 638))
        prompt.line(to: NSPoint(x: 425, y: 512))
        prompt.line(to: NSPoint(x: 282, y: 386))
        prompt.stroke()
        let cursor = NSBezierPath()
        cursor.lineWidth = 64
        cursor.lineCapStyle = .round
        cursor.move(to: NSPoint(x: 522, y: 380))
        cursor.line(to: NSPoint(x: 733, y: 380))
        cursor.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        let png = bitmap.representation(using: .png, properties: [:])!
        representations[pixels] = png
        try png.write(to: destination.appendingPathComponent(name))
    }
}

// Modern ICNS stores PNG representations directly. No image conversion service needed.
func lengthData(_ value: Int) -> Data {
    var value = UInt32(value).bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var chunks = Data()
for (size, type) in [(128, "ic07"), (256, "ic08"), (512, "ic09"), (1024, "ic10")] {
    let png = representations[size]!
    chunks.append(Data(type.utf8))
    chunks.append(lengthData(png.count + 8))
    chunks.append(png)
}
var icon = Data("icns".utf8)
icon.append(lengthData(chunks.count + 8))
icon.append(chunks)
try icon.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
