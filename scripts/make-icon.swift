#!/usr/bin/env swift
// Renders the app icon (pearl + champagne squircle, isometric Magic Mouse with two gold fingers)
// into an .iconset and converts it to Resources/AppIcon.icns.
//
//   swift scripts/make-icon.swift

import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)

    // Squircle background (macOS icon grid: 824pt body, 100pt inset).
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0x5C410A, 0.30).cgColor)
    color(0xFFFFFF).setFill(); squircle.fill()
    ctx.restoreGState()
    squircle.addClip()
    NSGradient(colors: [color(0xFFFDF8), color(0xF7EBCB), color(0xEDC777)])!.draw(in: body, angle: -70)
    NSGradient(colors: [color(0xFFFFFF, 0.65), color(0xFFFFFF, 0)])!
        .draw(in: NSRect(x: 100, y: 560, width: 824, height: 364), angle: -90)

    // Isometric mouse: extrusion slices stacked straight down in screen space, then the top.
    let shell = NSRect(x: -170, y: -295, width: 340, height: 590)
    func isoSpace(drop: CGFloat) {
        ctx.translateBy(x: 512, y: 500 - drop)
        ctx.scaleBy(x: 1, y: 0.58)
        ctx.rotate(by: 38 * .pi / 180)
    }
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -30), blur: 50, color: color(0x5C410A, 0.35).cgColor)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    for i in stride(from: 14, through: 1, by: -1) {
        ctx.saveGState()
        isoSpace(drop: CGFloat(i) * 4.5)
        NSGradient(colors: [color(0xDDD7CA), color(0xA39C8E)])!
            .draw(in: NSBezierPath(roundedRect: shell, xRadius: 165, yRadius: 165), angle: -90)
        ctx.restoreGState()
    }
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    ctx.saveGState()
    isoSpace(drop: 0)
    let top = NSBezierPath(roundedRect: shell, xRadius: 165, yRadius: 165)
    NSGradient(colors: [color(0xFFFFFF), color(0xF6F3EC), color(0xE2DCCF)])!.draw(in: top, angle: -90)
    color(0xFFFFFF).setStroke(); top.lineWidth = 4; top.stroke()

    for p in [CGPoint(x: -70, y: 110), CGPoint(x: 70, y: 126)] {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 40, color: color(0xE7B04A, 0.9).cgColor)
        color(0xE7B04A, 0.25).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - 52, y: p.y - 52, width: 104, height: 104)).fill()
        ctx.restoreGState()
        NSGradient(colors: [color(0xFFF4D6), color(0xE7B04A)])!
            .draw(in: NSBezierPath(ovalIn: NSRect(x: p.x - 36, y: p.y - 36, width: 72, height: 72)),
                  relativeCenterPosition: NSPoint(x: -0.3, y: 0.3))
    }
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}

let out = root.appendingPathComponent("Resources/AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try task.run()
task.waitUntilExit()
try render(1024).write(to: root.appendingPathComponent("docs/icon.png"))
print(task.terminationStatus == 0 ? "Wrote \(out.path)" : "iconutil failed")
