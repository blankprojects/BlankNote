import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
        (transform as NSAffineTransform).concat()
        NSColor(calibratedRed: 0.25, green: 0.39, blue: 0.31, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 205, yRadius: 205).fill()
        NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.93, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 245, y: 208, width: 535, height: 636), xRadius: 45, yRadius: 45).fill()
        NSColor(calibratedRed: 0.25, green: 0.39, blue: 0.31, alpha: 1).setStroke()
        for y in [660.0, 505.0] {
            let check = NSBezierPath()
            check.lineWidth = 28
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            check.move(to: NSPoint(x: 324, y: y))
            check.line(to: NSPoint(x: 354, y: y - 30))
            check.line(to: NSPoint(x: 409, y: y + 34))
            check.stroke()
        }
        NSColor(calibratedRed: 0.65, green: 0.69, blue: 0.59, alpha: 1).setFill()
        for y in [650.0, 495.0, 340.0] {
            NSBezierPath(roundedRect: NSRect(x: 470, y: y, width: 214, height: 25), xRadius: 12, yRadius: 12).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let destination = output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
    }
}
