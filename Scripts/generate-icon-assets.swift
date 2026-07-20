#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let appIconDirectory = repositoryRoot
    .appendingPathComponent("PetHalo/Assets.xcassets/AppIcon.appiconset")
let menuIconDirectory = repositoryRoot
    .appendingPathComponent("PetHalo/Assets.xcassets/MenuBarIcon.imageset")

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func png(size: Int, draw: (CGContext, CGFloat) -> Void) throws -> Data {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))
    draw(context, CGFloat(size))
    guard let image = context.makeImage() else {
        throw CocoaError(.fileWriteUnknown)
    }
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return data as Data
}

func drawArc(
    context: CGContext,
    center: CGPoint,
    radius: CGFloat,
    start: CGFloat,
    end: CGFloat,
    width: CGFloat,
    color: CGColor
) {
    context.beginPath()
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setStrokeColor(color)
    context.addArc(
        center: center,
        radius: radius,
        startAngle: start * .pi / 180,
        endAngle: end * .pi / 180,
        clockwise: false
    )
    context.strokePath()
}

func appIcon(size: Int) throws -> Data {
    try png(size: size) { context, dimension in
        let scale = dimension / 1024
        let tileRect = CGRect(
            x: 72 * scale,
            y: 72 * scale,
            width: 880 * scale,
            height: 880 * scale
        )
        let tile = CGPath(
            roundedRect: tileRect,
            cornerWidth: 214 * scale,
            cornerHeight: 214 * scale,
            transform: nil
        )
        context.saveGState()
        context.addPath(tile)
        context.clip()
        let gradient = CGGradient(
            colorsSpace: context.colorSpace,
            colors: [
                color(0.08, 0.09, 0.20),
                color(0.24, 0.20, 0.52),
            ] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 72 * scale),
            end: CGPoint(x: 0, y: 952 * scale),
            options: []
        )
        context.restoreGState()

        let center = CGPoint(x: 512 * scale, y: 502 * scale)
        drawArc(
            context: context,
            center: center,
            radius: 300 * scale,
            start: 38,
            end: 330,
            width: 62 * scale,
            color: color(1, 1, 1, 0.96)
        )
        drawArc(
            context: context,
            center: center,
            radius: 218 * scale,
            start: 70,
            end: 358,
            width: 54 * scale,
            color: color(0, 0.72, 0.85)
        )
        drawArc(
            context: context,
            center: center,
            radius: 144 * scale,
            start: 18,
            end: 304,
            width: 48 * scale,
            color: color(0.66, 0.33, 0.97)
        )
        context.setFillColor(color(1, 1, 1, 0.92))
        context.fillEllipse(in: CGRect(
            x: center.x - 26 * scale,
            y: center.y - 26 * scale,
            width: 52 * scale,
            height: 52 * scale
        ))
    }
}

func menuIcon(size: Int) throws -> Data {
    try png(size: size) { context, dimension in
        let scale = dimension / 18
        let center = CGPoint(x: 9 * scale, y: 9 * scale)
        drawArc(
            context: context,
            center: center,
            radius: 6.6 * scale,
            start: 38,
            end: 330,
            width: 1.8 * scale,
            color: color(0, 0, 0)
        )
        drawArc(
            context: context,
            center: center,
            radius: 3.6 * scale,
            start: 70,
            end: 352,
            width: 1.55 * scale,
            color: color(0, 0, 0)
        )
        context.setFillColor(color(0, 0, 0))
        context.fillEllipse(in: CGRect(
            x: center.x - 0.8 * scale,
            y: center.y - 0.8 * scale,
            width: 1.6 * scale,
            height: 1.6 * scale
        ))
    }
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    try appIcon(size: size).write(
        to: appIconDirectory.appendingPathComponent("app-icon-\(size).png"),
        options: .atomic
    )
}
try menuIcon(size: 18).write(
    to: menuIconDirectory.appendingPathComponent("menu-bar-icon.png"),
    options: .atomic
)
try menuIcon(size: 36).write(
    to: menuIconDirectory.appendingPathComponent("menu-bar-icon-2x.png"),
    options: .atomic
)
