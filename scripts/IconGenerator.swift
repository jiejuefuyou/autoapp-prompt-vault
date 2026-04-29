// PromptVault App Icon — 1024x1024 PNG via CoreGraphics.
// Visual: deep blue → purple gradient with a bold white "{{ }}" pair
// (the universal placeholder syntax) and a sparkle in the gap, evoking
// "save your AI prompts where the variables go".
//
// macOS-only. Run: `swift scripts/IconGenerator.swift <output-path>`

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

// 1) Diagonal deep-blue → purple gradient. Distinct from days-until's rose→violet.
let bgColors: CFArray = [
    CGColor(red: 0.10, green: 0.16, blue: 0.45, alpha: 1.0),   // deep indigo
    CGColor(red: 0.42, green: 0.20, blue: 0.78, alpha: 1.0)    // royal purple
] as CFArray
let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(bgGrad, start: .zero, end: CGPoint(x: dim, y: dim), options: [])

let center = CGPoint(x: dim / 2, y: dim / 2)

// 2) Two large white "{ }" braces.
// Drawing a stylized brace via two cubic Bezier curves stacked vertically.
let braceColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.97)
ctx.setStrokeColor(braceColor)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.setLineWidth(48)

func drawBrace(at center: CGPoint, height: CGFloat, opening: Bool) {
    // opening=true → '{'   opening=false → '}'
    let dir: CGFloat = opening ? -1 : 1
    let h = height
    let halfH = h / 2
    let bend: CGFloat = 60       // how far the brace bends out
    let tipBend: CGFloat = 90    // sharper bend at the middle "tip"

    let topY    = center.y + halfH
    let upperMid = center.y + halfH * 0.55
    let middle  = center.y
    let lowerMid = center.y - halfH * 0.55
    let botY    = center.y - halfH

    let xBase = center.x

    ctx.move(to: CGPoint(x: xBase, y: topY))
    ctx.addCurve(
        to: CGPoint(x: xBase, y: upperMid),
        control1: CGPoint(x: xBase + dir * bend, y: topY - 60),
        control2: CGPoint(x: xBase + dir * bend, y: upperMid + 40)
    )
    ctx.addCurve(
        to: CGPoint(x: xBase - dir * tipBend, y: middle),
        control1: CGPoint(x: xBase, y: upperMid - 40),
        control2: CGPoint(x: xBase - dir * tipBend, y: middle + 30)
    )
    ctx.addCurve(
        to: CGPoint(x: xBase, y: lowerMid),
        control1: CGPoint(x: xBase - dir * tipBend, y: middle - 30),
        control2: CGPoint(x: xBase, y: lowerMid + 40)
    )
    ctx.addCurve(
        to: CGPoint(x: xBase, y: botY),
        control1: CGPoint(x: xBase + dir * bend, y: lowerMid - 40),
        control2: CGPoint(x: xBase + dir * bend, y: botY + 60)
    )
    ctx.strokePath()
}

// Left and right braces, with a gap in the middle for the sparkle.
let braceHeight: CGFloat = 560
let braceGap: CGFloat = 240
drawBrace(at: CGPoint(x: center.x - braceGap, y: center.y), height: braceHeight, opening: true)
drawBrace(at: CGPoint(x: center.x + braceGap, y: center.y), height: braceHeight, opening: false)

// 3) Center sparkle (4-point star) — represents the AI-prompt content.
func drawSparkle(at c: CGPoint, radius outer: CGFloat) {
    let inner = outer * 0.32
    let points = 8  // 4-point star = 8 vertices alternating outer/inner
    var path = CGMutablePath()
    for i in 0..<points {
        let r: CGFloat = (i % 2 == 0) ? outer : inner
        let angle = CGFloat(i) * (.pi / CGFloat(points / 2)) - (.pi / 2)
        let p = CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
        if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
    }
    path.closeSubpath()
    ctx.addPath(path)

    // White fill with subtle yellow inner glow.
    ctx.setFillColor(CGColor(red: 1.0, green: 0.96, blue: 0.78, alpha: 1.0))
    ctx.fillPath()
}
drawSparkle(at: center, radius: 130)

// 4) Two smaller satellite sparkles for visual interest.
ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85))
func drawDot(at c: CGPoint, r: CGFloat) {
    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
}
drawDot(at: CGPoint(x: center.x - 80, y: center.y + 180), r: 14)
drawDot(at: CGPoint(x: center.x + 90, y: center.y - 200), r: 18)

// Save as PNG.
guard let img = ctx.makeImage() else { fatalError("makeImage failed") }
let url = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("CGImageDestination failed")
}
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Finalize failed") }
print("wrote \(url.path)")
