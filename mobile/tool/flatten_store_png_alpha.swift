import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let assetsRoot = root.appendingPathComponent("store_assets/actual/v1.0.36")

guard fileManager.fileExists(atPath: assetsRoot.path) else {
  fatalError("Missing store assets directory: \(assetsRoot.path)")
}

func flattenPNG(at url: URL) throws {
  guard
    let source = CGImageSourceCreateWithURL(url as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
  else {
    throw NSError(
      domain: "FlattenStorePNG",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Could not read \(url.path)"]
    )
  }

  let width = image.width
  let height = image.height
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let bitmapInfo =
    CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

  guard
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: colorSpace,
      bitmapInfo: bitmapInfo
    )
  else {
    throw NSError(
      domain: "FlattenStorePNG",
      code: 2,
      userInfo: [
        NSLocalizedDescriptionKey: "Could not create bitmap for \(url.path)"
      ]
    )
  }

  let rect = CGRect(x: 0, y: 0, width: width, height: height)
  context.interpolationQuality = .high
  context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
  context.fill(rect)
  context.draw(image, in: rect)

  guard let flattened = context.makeImage() else {
    throw NSError(
      domain: "FlattenStorePNG",
      code: 3,
      userInfo: [
        NSLocalizedDescriptionKey: "Could not flatten image for \(url.path)"
      ]
    )
  }

  let tempURL = url.deletingLastPathComponent()
    .appendingPathComponent(".\(url.lastPathComponent).flattened")
  guard
    let destination = CGImageDestinationCreateWithURL(
      tempURL as CFURL,
      UTType.png.identifier as CFString,
      1,
      nil
    )
  else {
    throw NSError(
      domain: "FlattenStorePNG",
      code: 4,
      userInfo: [
        NSLocalizedDescriptionKey: "Could not create PNG writer for \(url.path)"
      ]
    )
  }

  CGImageDestinationAddImage(destination, flattened, nil)
  guard CGImageDestinationFinalize(destination) else {
    throw NSError(
      domain: "FlattenStorePNG",
      code: 5,
      userInfo: [NSLocalizedDescriptionKey: "Could not write \(url.path)"]
    )
  }

  let data = try Data(contentsOf: tempURL)
  try data.write(to: url, options: [.atomic])
  try fileManager.removeItem(at: tempURL)
}

let enumerator = fileManager.enumerator(
  at: assetsRoot,
  includingPropertiesForKeys: nil
)

var flattenedCount = 0
while let item = enumerator?.nextObject() as? URL {
  guard item.pathExtension.lowercased() == "png" else { continue }
  try flattenPNG(at: item)
  flattenedCount += 1
}

print("Flattened \(flattenedCount) PNG store assets.")
