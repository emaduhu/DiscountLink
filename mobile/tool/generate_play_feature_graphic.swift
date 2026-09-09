import AppKit

struct FeatureSource {
    let path: String
    let frame: NSRect
    let radius: CGFloat
    let shadow: CGFloat
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = root.appendingPathComponent("store_assets/actual/v1.0.36/play_store/feature_graphic/feature_graphic_1024x500.jpg")
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

func image(_ relativePath: String) -> NSImage {
    let url = root.appendingPathComponent(relativePath)
    guard let image = NSImage(contentsOf: url) else {
        fatalError("Missing image: \(relativePath)")
    }
    return image
}

func drawAspectFill(_ image: NSImage, in rect: NSRect) {
    let sourceSize = image.size
    let scale = max(rect.width / sourceSize.width, rect.height / sourceSize.height)
    let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    let drawRect = NSRect(
        x: rect.midX - drawSize.width / 2,
        y: rect.midY - drawSize.height / 2,
        width: drawSize.width,
        height: drawSize.height
    )
    image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
}

func drawRoundedImage(_ source: FeatureSource) {
    let shadowPath = NSBezierPath(roundedRect: source.frame, xRadius: source.radius, yRadius: source.radius)
    NSColor.black.withAlphaComponent(source.shadow).setFill()
    shadowPath.transform(using: AffineTransform(translationByX: 0, byY: -8))
    shadowPath.fill()

    let clipPath = NSBezierPath(roundedRect: source.frame, xRadius: source.radius, yRadius: source.radius)
    NSGraphicsContext.saveGraphicsState()
    clipPath.addClip()
    drawAspectFill(image(source.path), in: source.frame)
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.84).setStroke()
    clipPath.lineWidth = 2
    clipPath.stroke()
}

func drawText(_ text: String, at point: NSPoint, font: NSFont, color: NSColor, width: CGFloat) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    (text as NSString).draw(
        with: NSRect(x: point.x, y: point.y, width: width, height: 120),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attributes
    )
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 500,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not allocate feature graphic bitmap.")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.imageInterpolation = .high

let rect = NSRect(x: 0, y: 0, width: 1024, height: 500)
NSGradient(colors: [
    NSColor(red: 1.0, green: 0.93, blue: 0.86, alpha: 1),
    NSColor(red: 1.0, green: 0.47, blue: 0.26, alpha: 1),
    NSColor(red: 0.15, green: 0.12, blue: 0.24, alpha: 1),
])?.draw(in: rect, angle: 0)

NSColor.white.withAlphaComponent(0.16).setFill()
NSBezierPath(ovalIn: NSRect(x: -120, y: 245, width: 360, height: 360)).fill()
NSBezierPath(ovalIn: NSRect(x: 690, y: -120, width: 420, height: 420)).fill()

let iconFrame = NSRect(x: 58, y: 348, width: 70, height: 70)
let iconPath = NSBezierPath(roundedRect: iconFrame, xRadius: 18, yRadius: 18)
NSGraphicsContext.saveGraphicsState()
iconPath.addClip()
drawAspectFill(image("assets/images/app_icon.png"), in: iconFrame)
NSGraphicsContext.restoreGraphicsState()

drawText(
    "Discount Link",
    at: NSPoint(x: 146, y: 302),
    font: NSFont.systemFont(ofSize: 48, weight: .heavy),
    color: NSColor(red: 0.12, green: 0.10, blue: 0.18, alpha: 1),
    width: 350
)
drawText(
    "Sellers can now shop deals too, with product alerts, secure chat, and tracked delivery.",
    at: NSPoint(x: 62, y: 220),
    font: NSFont.systemFont(ofSize: 23, weight: .semibold),
    color: NSColor(red: 0.25, green: 0.21, blue: 0.30, alpha: 1),
    width: 410
)

drawText(
    "Seller marketplace access",
    at: NSPoint(x: 62, y: 130),
    font: NSFont.systemFont(ofSize: 18, weight: .bold),
    color: NSColor(red: 1.0, green: 0.39, blue: 0.21, alpha: 1),
    width: 280
)

drawRoundedImage(
    FeatureSource(
        path: "store_assets/actual/v1.0.36/play_store/phone/screenshots/01_seller_marketplace.png",
        frame: NSRect(x: 512, y: 54, width: 170, height: 340),
        radius: 26,
        shadow: 0.20
    )
)
drawRoundedImage(
    FeatureSource(
        path: "store_assets/actual/v1.0.36/play_store/phone/screenshots/02_seller_discount_amount.png",
        frame: NSRect(x: 654, y: 96, width: 170, height: 340),
        radius: 26,
        shadow: 0.22
    )
)
drawRoundedImage(
    FeatureSource(
        path: "store_assets/actual/v1.0.36/play_store/phone/screenshots/04_delivery_tracking.png",
        frame: NSRect(x: 792, y: 45, width: 170, height: 340),
        radius: 26,
        shadow: 0.20
    )
)

NSGraphicsContext.restoreGraphicsState()

guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
    fatalError("Could not render feature graphic.")
}

try data.write(to: outputURL, options: .atomic)
print(outputURL.path)
