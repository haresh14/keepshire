// Builds App Store marketing images from the raw captures in release/screenshots.
//
// Usage: swift release/tools/marketing-assets.swift <repo root>
//
// Writes, all opaque PNG (App Store rejects alpha):
//   release/assets/screenshots/iphone-6.9/*.png   1320 x 2868
//   release/assets/screenshots/ipad-13/*.png      2064 x 2752
//   release/assets/product-page-header.png        3840 x 1646 (21:9)
//   release/assets/search-results.png             3840 x 2560 (3:2)

import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let raw = root.appendingPathComponent("release/screenshots")
let out = root.appendingPathComponent("release/assets")

// Brand gradient sampled from the app icon (teal → green).
let teal = NSColor(srgbRed: 0.02, green: 0.58, blue: 0.66, alpha: 1)
let green = NSColor(srgbRed: 0.50, green: 0.86, blue: 0.35, alpha: 1)
let ink = NSColor(srgbRed: 0.03, green: 0.20, blue: 0.24, alpha: 1)

struct Caption {
    let source: String
    let title: String
    let subtitle: String
}

// Lead with the strongest idea; keep overlay text short.
let iphoneCaptions = [
    Caption(source: "iphone-02-gallery", title: "Your private photo vault", subtitle: "Encrypted on your iPhone. No account, no cloud."),
    Caption(source: "iphone-01-lock", title: "Locked when you leave", subtitle: "Passcode or password, with optional Face ID."),
    Caption(source: "iphone-04-folders", title: "Organize with folders", subtitle: "Photos, videos, audio and documents."),
    Caption(source: "iphone-03-viewer", title: "View without leaving", subtitle: "Zoom, swipe and play right inside the vault."),
    Caption(source: "iphone-05-categories", title: "Find anything fast", subtitle: "Browse by type, favorites and more."),
    Caption(source: "iphone-06-web-upload", title: "Add files over Wi-Fi", subtitle: "Upload from a computer on your network."),
]

let ipadCaptions = [
    Caption(source: "ipad-02-gallery", title: "Your private photo vault", subtitle: "Encrypted on your iPad. No account, no cloud."),
    Caption(source: "ipad-01-lock", title: "Locked when you leave", subtitle: "Passcode or password, with optional Face ID."),
    Caption(source: "ipad-04-folders", title: "Organize with folders", subtitle: "Photos, videos, audio and documents."),
    Caption(source: "ipad-05-categories", title: "Find anything fast", subtitle: "Browse by type, favorites and more."),
    Caption(source: "ipad-06-web-upload", title: "Add files over Wi-Fi", subtitle: "Upload from a computer on your network."),
]

func load(_ name: String) -> NSImage {
    let url = raw.appendingPathComponent(name.hasPrefix("ipad") ? "ipad-13" : "iphone-6.9")
        .appendingPathComponent("\(name).png")
    guard let image = NSImage(contentsOf: url) else { fatalError("Missing \(url.path)") }
    return image
}

let icon = NSImage(contentsOf: root.appendingPathComponent("Keepshire/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png"))!

/// Draws into an opaque sRGB bitmap of exact pixel size (no Retina scaling).
func render(width: Int, height: Int, to url: URL, draw: (CGRect) -> Void) {
    // noneSkipLast keeps the bitmap opaque, so the PNG has no alpha channel.
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    draw(CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
}

func drawBackground(_ rect: CGRect) {
    NSGradient(starting: teal, ending: green)!.draw(in: rect, angle: 20)
    // Soft light from the top so headlines sit on the brightest area.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
        .draw(in: rect, angle: -90)
}

func drawText(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, in rect: CGRect, align: NSTextAlignment = .center) {
    let style = NSMutableParagraphStyle()
    style.alignment = align
    style.lineBreakMode = .byWordWrapping
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.04)
    shadow.shadowBlurRadius = size * 0.12
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style,
        .shadow: shadow,
    ]
    NSString(string: text).draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attributes)
}

/// A screen with rounded corners, a thin bezel and a drop shadow.
func drawScreen(_ image: NSImage, in rect: CGRect, cornerRadius: CGFloat) {
    let bezel = rect.insetBy(dx: -rect.width * 0.022, dy: -rect.width * 0.022)
    let bezelRadius = cornerRadius + rect.width * 0.022
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -rect.width * 0.02)
    shadow.shadowBlurRadius = rect.width * 0.08
    shadow.set()
    ink.setFill()
    NSBezierPath(roundedRect: bezel, xRadius: bezelRadius, yRadius: bezelRadius).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).addClip()
    image.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

func captioned(_ caption: Caption, width: Int, height: Int, screenWidthRatio: CGFloat, cornerRatio: CGFloat, folder: String, index: Int) {
    let url = out.appendingPathComponent("screenshots/\(folder)/\(String(format: "%02d", index + 1))-\(caption.source.split(separator: "-").dropFirst(2).joined(separator: "-")).png")
    render(width: width, height: height, to: url) { canvas in
        drawBackground(canvas)
        let w = canvas.width, h = canvas.height
        let titleSize = w * 0.075
        drawText(caption.title, size: titleSize, weight: .heavy, color: .white,
                 in: CGRect(x: w * 0.06, y: h - h * 0.045 - titleSize * 2.4, width: w * 0.88, height: titleSize * 2.4))
        let subtitleSize = w * 0.036
        drawText(caption.subtitle, size: subtitleSize, weight: .semibold, color: NSColor.white.withAlphaComponent(0.92),
                 in: CGRect(x: w * 0.08, y: h - h * 0.045 - titleSize * 1.3 - subtitleSize * 2.9, width: w * 0.84, height: subtitleSize * 2.6))

        let image = load(caption.source)
        let screenW = w * screenWidthRatio
        let screenH = screenW * image.size.height / image.size.width
        let top = h - h * 0.045 - titleSize * 1.3 - subtitleSize * 3.4
        // The device bleeds off the bottom edge; the important top of the UI stays visible.
        let rect = CGRect(x: (w - screenW) / 2, y: top - screenH, width: screenW, height: screenH)
        drawScreen(image, in: rect, cornerRadius: screenW * cornerRatio)
    }
}

for (index, caption) in iphoneCaptions.enumerated() {
    captioned(caption, width: 1320, height: 2868, screenWidthRatio: 0.80, cornerRatio: 0.12, folder: "iphone-6.9", index: index)
}
for (index, caption) in ipadCaptions.enumerated() {
    captioned(caption, width: 2064, height: 2752, screenWidthRatio: 0.82, cornerRatio: 0.035, folder: "ipad-13", index: index)
}

/// Three phones fanned around the center, with the app name and tagline.
func keyArt(width: Int, height: Int, name: String, phoneHeightRatio: CGFloat, textAbove: Bool) {
    render(width: width, height: height, to: out.appendingPathComponent(name)) { canvas in
        drawBackground(canvas)
        let w = canvas.width, h = canvas.height
        let screens = ["iphone-04-folders", "iphone-02-gallery", "iphone-01-lock"].map(load)
        let phoneH = h * phoneHeightRatio
        let phoneW = phoneH * screens[0].size.width / screens[0].size.height
        let gap = phoneW * 0.18
        let textBlock = textAbove ? h * 0.22 : 0
        let centerY = (h - textBlock) / 2
        let offsets: [CGFloat] = [-(phoneW + gap), 0, phoneW + gap]
        let lifts: [CGFloat] = [-h * 0.03, h * 0.02, -h * 0.03]
        // Side phones first so the center one overlaps them.
        for i in [0, 2, 1] {
            let scale: CGFloat = i == 1 ? 1.0 : 0.9
            let pw = phoneW * scale, ph = phoneH * scale
            let rect = CGRect(x: w / 2 + offsets[i] - pw / 2, y: centerY - ph / 2 + lifts[i], width: pw, height: ph)
            drawScreen(screens[i], in: rect, cornerRadius: pw * 0.12)
        }
        if textAbove {
            let iconSize = h * 0.09
            let titleSize = h * 0.075
            let title = "Keepshire"
            let font = NSFont.systemFont(ofSize: titleSize, weight: .heavy)
            let titleWidth = NSString(string: title).size(withAttributes: [.font: font]).width
            let rowWidth = iconSize + iconSize * 0.35 + titleWidth
            let rowY = h - h * 0.05 - iconSize
            NSGraphicsContext.saveGraphicsState()
            let iconRect = CGRect(x: (w - rowWidth) / 2, y: rowY, width: iconSize, height: iconSize)
            NSBezierPath(roundedRect: iconRect, xRadius: iconSize * 0.225, yRadius: iconSize * 0.225).addClip()
            icon.draw(in: iconRect)
            NSGraphicsContext.restoreGraphicsState()
            drawText(title, size: titleSize, weight: .heavy, color: .white,
                     in: CGRect(x: iconRect.maxX + iconSize * 0.35, y: rowY + (iconSize - titleSize * 1.2) / 2, width: titleWidth + 10, height: titleSize * 1.3),
                     align: .left)
            let taglineSize = h * 0.032
            drawText("Hide photos, videos and files. Encrypted on your device.", size: taglineSize, weight: .semibold,
                     color: NSColor.white.withAlphaComponent(0.92),
                     in: CGRect(x: w * 0.1, y: rowY - taglineSize * 2.2, width: w * 0.8, height: taglineSize * 1.5))
        }
    }
}

// Header: wide 21:9; keep key art centered (Apple's safe area is central).
keyArt(width: 3840, height: 1646, name: "product-page-header.png", phoneHeightRatio: 0.80, textAbove: false)
// Search results: 3:2 with the name and purpose stated up front.
keyArt(width: 3840, height: 2560, name: "search-results.png", phoneHeightRatio: 0.66, textAbove: true)

print("Wrote assets to \(out.path)")
