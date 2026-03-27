#!/usr/bin/env swift
import AppKit

let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

func drawIcon(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let scale = size / 256.0

        // Background: rounded green pill
        let bg = NSBezierPath(roundedRect: rect.insetBy(dx: 8 * scale, dy: 40 * scale), xRadius: 50 * scale, yRadius: 50 * scale)
        NSColor(red: 0.65, green: 0.78, blue: 0.55, alpha: 1.0).setFill()
        bg.fill()
        NSColor(red: 0.55, green: 0.68, blue: 0.45, alpha: 1.0).setStroke()
        bg.lineWidth = 3 * scale
        bg.stroke()

        // D-pad cross
        let dpadX = 60 * scale
        let dpadY = size / 2
        let armW = 16 * scale
        let armL = 28 * scale
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: dpadX - armW/2, y: dpadY - armL, width: armW, height: armL * 2), xRadius: 3 * scale, yRadius: 3 * scale).fill()
        NSBezierPath(roundedRect: NSRect(x: dpadX - armL, y: dpadY - armW/2, width: armL * 2, height: armW), xRadius: 3 * scale, yRadius: 3 * scale).fill()

        // Face buttons
        let btnR = 12 * scale
        let cx = 196 * scale
        let cy = size / 2
        let spread = 22 * scale

        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - btnR, y: cy + spread - btnR, width: btnR * 2, height: btnR * 2)).fill()
        NSBezierPath(ovalIn: NSRect(x: cx - btnR, y: cy - spread - btnR, width: btnR * 2, height: btnR * 2)).fill()
        NSBezierPath(ovalIn: NSRect(x: cx - spread - btnR, y: cy - btnR, width: btnR * 2, height: btnR * 2)).fill()
        NSBezierPath(ovalIn: NSRect(x: cx + spread - btnR, y: cy - btnR, width: btnR * 2, height: btnR * 2)).fill()

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11 * scale),
            .foregroundColor: NSColor(red: 0.55, green: 0.68, blue: 0.45, alpha: 1.0),
        ]
        "Y".draw(at: NSPoint(x: cx - 4 * scale, y: cy + spread - 8 * scale), withAttributes: labelAttrs)
        "A".draw(at: NSPoint(x: cx - 4 * scale, y: cy - spread - 8 * scale), withAttributes: labelAttrs)
        "X".draw(at: NSPoint(x: cx - spread - 4 * scale, y: cy - 8 * scale), withAttributes: labelAttrs)
        "B".draw(at: NSPoint(x: cx + spread - 4 * scale, y: cy - 8 * scale), withAttributes: labelAttrs)

        return true
    }
}

// Generate iconset
let iconsetPath = "AppIcon.iconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let image = drawIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
}

print("Generated \(iconsetPath). Run: iconutil -c icns \(iconsetPath)")
