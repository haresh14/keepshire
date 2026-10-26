import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Writes 12 abstract landscape JPEGs (sky gradient, sun, layered hills) into the
// directory given as the first argument. Neutral, license-free screenshot content.
let palettes: [[(CGFloat, CGFloat, CGFloat)]] = [
    [(0.98,0.62,0.38),(0.96,0.40,0.45),(0.35,0.20,0.45),(0.20,0.12,0.30)],
    [(0.55,0.80,0.98),(0.85,0.93,0.99),(0.30,0.60,0.45),(0.15,0.40,0.30)],
    [(0.10,0.15,0.35),(0.35,0.30,0.60),(0.15,0.20,0.40),(0.06,0.08,0.20)],
    [(0.99,0.85,0.55),(0.98,0.70,0.45),(0.75,0.45,0.30),(0.45,0.25,0.20)],
    [(0.70,0.90,0.95),(0.45,0.75,0.85),(0.20,0.50,0.60),(0.08,0.30,0.40)],
    [(0.95,0.75,0.85),(0.80,0.60,0.85),(0.45,0.35,0.65),(0.25,0.20,0.45)],
    [(0.60,0.85,0.70),(0.95,0.95,0.80),(0.45,0.65,0.35),(0.25,0.45,0.25)],
    [(0.20,0.35,0.55),(0.95,0.60,0.30),(0.30,0.25,0.35),(0.12,0.10,0.18)],
    [(0.85,0.92,0.98),(0.65,0.80,0.95),(0.85,0.88,0.92),(0.55,0.62,0.72)],
    [(0.99,0.55,0.30),(0.99,0.80,0.40),(0.55,0.30,0.20),(0.30,0.15,0.12)],
    [(0.40,0.30,0.70),(0.90,0.50,0.60),(0.25,0.20,0.45),(0.10,0.08,0.25)],
    [(0.75,0.95,0.90),(0.40,0.80,0.75),(0.20,0.55,0.50),(0.10,0.35,0.35)],
]
let w = 1600, h = 1200
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
for (i, p) in palettes.enumerated() {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    func c(_ t: (CGFloat, CGFloat, CGFloat)) -> CGColor { CGColor(srgbRed: t.0, green: t.1, blue: t.2, alpha: 1) }
    let g = CGGradient(colorsSpace: cs, colors: [c(p[1]), c(p[0])] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: CGFloat(h)), end: CGPoint(x: 0, y: CGFloat(h) * 0.35), options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
    ctx.setFillColor(CGColor(srgbRed: 1, green: 0.97, blue: 0.88, alpha: 0.85))
    let r = CGFloat(90 + (i * 23) % 70)
    ctx.fillEllipse(in: CGRect(x: CGFloat(300 + (i * 157) % 1000), y: CGFloat(700 + (i * 41) % 250), width: r * 2, height: r * 2))
    for (layer, color) in [p[2], p[3]].enumerated() {
        ctx.setFillColor(c(color))
        ctx.move(to: CGPoint(x: 0, y: 0))
        let base = CGFloat(520 - layer * 200), amp = CGFloat(110 - layer * 30)
        var x: CGFloat = 0
        while x <= CGFloat(w) {
            let y = base + amp * sin(x / CGFloat(170 + i * 13 + layer * 60) + CGFloat(i + layer * 2)) + 40 * sin(x / 61 + CGFloat(i))
            ctx.addLine(to: CGPoint(x: x, y: y)); x += 8
        }
        ctx.addLine(to: CGPoint(x: CGFloat(w), y: 0)); ctx.closePath(); ctx.fillPath()
    }
    let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent(String(format: "IMG_%04d.jpg", 4201 + i))
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
    CGImageDestinationFinalize(dest)
}
