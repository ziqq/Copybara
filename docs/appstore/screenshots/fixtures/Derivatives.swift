// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.
import AppKit
import ImageIO
let root = URL(fileURLWithPath: CommandLine.arguments[1])
func context(_ width: Int, _ height: Int) -> CGContext {
 CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
}
func save(_ image: CGImage, to url: URL, jpeg: Bool = false) throws {
 let rep = NSBitmapImageRep(cgImage: image)
 try rep.representation(using: jpeg ? .jpeg : .png, properties: jpeg ? [.compressionFactor: 0.85] : [:])!.write(to: url)
}
let sheet = context(1440, 600)
for (row, locale) in ["en", "ru"].enumerated() {
 for (column, name) in ["01-history", "02-pins", "03-settings"].enumerated() {
  let sourceURL = root.appendingPathComponent("\(locale)/\(name).png")
  let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)!
  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
  let opaque = context(2880, 1800)
  opaque.draw(image, in: CGRect(x: 0, y: 0, width: 2880, height: 1800))
  try save(opaque.makeImage()!, to: sourceURL)
  let target = context(1440, 900)
  target.interpolationQuality = .high
  target.draw(image, in: CGRect(x: 0, y: 0, width: 1440, height: 900))
  let directory = root.appendingPathComponent("web/\(locale)")
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  try save(target.makeImage()!, to: directory.appendingPathComponent("\(name).jpg"), jpeg: true)
  sheet.draw(image, in: CGRect(x: column * 480, y: (1-row) * 300, width: 480, height: 300))
 }
}
try save(sheet.makeImage()!, to: root.appendingPathComponent("contact-sheet.png"))
