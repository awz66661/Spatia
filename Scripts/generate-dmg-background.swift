#!/usr/bin/env swift

import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-dmg-background.swift <output-png>\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvasSize = NSSize(width: 660, height: 420)
let image = NSImage(size: canvasSize)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawCenteredText(
    _ text: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    lineHeight: CGFloat? = nil
) {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    if let lineHeight {
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
    }

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle
    ]

    (text as NSString).draw(in: rect, withAttributes: attributes)
}

func drawRoundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

image.lockFocus()

let backgroundRect = NSRect(origin: .zero, size: canvasSize)
let gradient = NSGradient(
    starting: color(248, 249, 247),
    ending: color(231, 237, 236)
)
gradient?.draw(in: backgroundRect, angle: 90)

drawRoundedRect(
    NSRect(x: 38, y: 38, width: 584, height: 344),
    radius: 22,
    fill: color(255, 255, 255, 0.62)
)

let mosaicAlpha: CGFloat = 0.18
let mosaicY: CGFloat = 44
drawRoundedRect(NSRect(x: 54, y: mosaicY, width: 120, height: 30), radius: 8, fill: color(41, 117, 102, mosaicAlpha))
drawRoundedRect(NSRect(x: 184, y: mosaicY, width: 76, height: 30), radius: 8, fill: color(73, 108, 168, mosaicAlpha))
drawRoundedRect(NSRect(x: 270, y: mosaicY, width: 148, height: 30), radius: 8, fill: color(210, 130, 63, mosaicAlpha))
drawRoundedRect(NSRect(x: 428, y: mosaicY, width: 82, height: 30), radius: 8, fill: color(107, 122, 64, mosaicAlpha))
drawRoundedRect(NSRect(x: 520, y: mosaicY, width: 86, height: 30), radius: 8, fill: color(48, 132, 145, mosaicAlpha))

drawCenteredText(
    "Spatia",
    in: NSRect(x: 0, y: 305, width: canvasSize.width, height: 48),
    font: .systemFont(ofSize: 34, weight: .semibold),
    color: color(31, 35, 38)
)

drawCenteredText(
    "Drag Spatia to Applications",
    in: NSRect(x: 0, y: 268, width: canvasSize.width, height: 30),
    font: .systemFont(ofSize: 18, weight: .medium),
    color: color(68, 76, 79)
)

drawCenteredText(
    "Then launch it from your Applications folder.",
    in: NSRect(x: 0, y: 242, width: canvasSize.width, height: 24),
    font: .systemFont(ofSize: 13, weight: .regular),
    color: color(101, 109, 112)
)

let arrowColor = color(37, 116, 102)
arrowColor.setStroke()
let arrow = NSBezierPath()
arrow.lineWidth = 5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 274, y: 184))
arrow.line(to: NSPoint(x: 386, y: 184))
arrow.stroke()

let arrowHead = NSBezierPath()
arrowHead.lineWidth = 5
arrowHead.lineCapStyle = .round
arrowHead.lineJoinStyle = .round
arrowHead.move(to: NSPoint(x: 386, y: 184))
arrowHead.line(to: NSPoint(x: 366, y: 202))
arrowHead.move(to: NSPoint(x: 386, y: 184))
arrowHead.line(to: NSPoint(x: 366, y: 166))
arrowHead.stroke()

drawCenteredText(
    "Copy once. Scan locally.",
    in: NSRect(x: 0, y: 98, width: canvasSize.width, height: 22),
    font: .systemFont(ofSize: 12, weight: .medium),
    color: color(111, 118, 120)
)

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to render DMG background image.\n", stderr)
    exit(1)
}

do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try pngData.write(to: outputURL, options: .atomic)
} catch {
    fputs("Failed to write DMG background image: \(error)\n", stderr)
    exit(1)
}
