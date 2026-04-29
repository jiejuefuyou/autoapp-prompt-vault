// PromptVault App Icon — 1024x1024 PNG via CoreGraphics.
// Visual: rose → violet gradient with a bold white calendar grid, the front
// page peeled to reveal a large day number ("14") in white-on-violet.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit
import CoreText

let outPath = CommandLine.arguments.dropFirst().first ?? "icon.png"
let dim = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!

guard let ctx = CGContext(
    data: nil,
    width: dim, height: dim,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
) else {
    fatalError("Failed to create CGContext")
}

// 1) Diagonal rose → violet gradient.
let bgColors: CFArray = [
    CGColor(red: 0.90, green: 0.22, blue: 0.27, alpha: 1.0), // rose
    CGColor(red: 0.45, green: 0.04, blue: 0.72, alpha: 1.0)  // violet
] as CFArray
let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(bgGrad, start: .zero, end: CGPoint(x: dim, y: dim), options: [])

// 2) White calendar card (rounded rectangle).
let card = CGRect(x: 192, y: 200, width: 640, height: 640)
let cardPath = CGPath(roundedRect: card, cornerWidth: 64, cornerHeight: 64, transform: nil)
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.97))
ctx.addPath(cardPath)
ctx.fillPath()

// 3) Top header band (dark violet) inside the card.
let header = CGRect(x: 192, y: 720, width: 640, height: 120)
ctx.saveGState()
ctx.addPath(cardPath)
ctx.clip()
ctx.setFillColor(CGColor(red: 0.45, green: 0.04, blue: 0.72, alpha: 1.0))
ctx.fill(header)
ctx.restoreGState()

// 4) Two binding rings on top of the header.
ctx.setFillColor(CGColor(red: 0.7, green: 0.7, blue: 0.78, alpha: 1.0))
ctx.fillEllipse(in: CGRect(x: 304, y: 820, width: 50, height: 80))
ctx.fillEllipse(in: CGRect(x: 670, y: 820, width: 50, height: 80))
ctx.setFillColor(CGColor(red: 0.92, green: 0.92, blue: 0.96, alpha: 1.0))
ctx.fillEllipse(in: CGRect(x: 314, y: 830, width: 30, height: 60))
ctx.fillEllipse(in: CGRect(x: 680, y: 830, width: 30, height: 60))

// 5) Big day number "14" in violet, centered on the white area.
let numberFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 360, nil)
let numAttrs: [NSAttributedString.Key: Any] = [
    .font: numberFont,
    .foregroundColor: NSColor(srgbRed: 0.45, green: 0.04, blue: 0.72, alpha: 1.0)
]
let numStr = NSAttributedString(string: "14", attributes: numAttrs)
let numLine = CTLineCreateWithAttributedString(numStr as CFAttributedString)
let numBounds = CTLineGetBoundsWithOptions(numLine, .useOpticalBounds)
let numX = (CGFloat(dim) - numBounds.width) / 2 - numBounds.minX
let numY = card.minY + (card.height - 120) / 2 - numBounds.height / 2 - numBounds.minY - 40
ctx.textPosition = CGPoint(x: numX, y: numY)
CTLineDraw(numLine, ctx)

// 6) Save PNG.
guard let img = ctx.makeImage() else { fatalError("makeImage failed") }
let url = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("CGImageDestination failed")
}
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Finalize failed") }
print("wrote \(url.path)")
