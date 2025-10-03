#!/bin/bash

# Create a bear-inspired app icon for Grizzly

set -e

ICON_DIR="AppIcon.iconset"
OUTPUT_ICON="AppIcon.icns"

echo "🎨 Creating app icon..."

# Remove old iconset if exists
rm -rf "$ICON_DIR"
mkdir -p "$ICON_DIR"

# Create a simple Swift script to generate icon images
cat > generate_icon.swift << 'EOF'
import Cocoa
import SwiftUI

func createIcon(size: CGFloat, filename: String) {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    // Background gradient - earthy brown/tan colors for grizzly bear
    let gradient = NSGradient(colors: [
        NSColor(red: 0.55, green: 0.35, blue: 0.2, alpha: 1.0),  // Warm brown
        NSColor(red: 0.4, green: 0.25, blue: 0.15, alpha: 1.0)   // Darker brown
    ])
    gradient?.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: 270)

    // Draw rounded app icon shape
    let inset: CGFloat = size * 0.05
    let roundedRect = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2), xRadius: size * 0.18, yRadius: size * 0.18)
    roundedRect.addClip()

    // Draw simplified bear head
    let centerX = size / 2
    let centerY = size / 2

    // Bear color - grizzly brown
    NSColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1.0).setFill()

    // Head (circle)
    let headSize = size * 0.45
    let headRect = NSRect(x: centerX - headSize/2, y: centerY - headSize/2 + size * 0.05, width: headSize, height: headSize)
    let head = NSBezierPath(ovalIn: headRect)
    head.fill()

    // Left ear
    let earSize = size * 0.15
    let leftEar = NSBezierPath(ovalIn: NSRect(x: centerX - headSize/2 + size * 0.05, y: centerY + headSize/2 - size * 0.05, width: earSize, height: earSize))
    leftEar.fill()

    // Right ear
    let rightEar = NSBezierPath(ovalIn: NSRect(x: centerX + headSize/2 - earSize - size * 0.05, y: centerY + headSize/2 - size * 0.05, width: earSize, height: earSize))
    rightEar.fill()

    // Snout (lighter color)
    NSColor(red: 0.65, green: 0.5, blue: 0.35, alpha: 1.0).setFill()
    let snoutSize = size * 0.25
    let snout = NSBezierPath(ovalIn: NSRect(x: centerX - snoutSize/2, y: centerY - headSize/2 + size * 0.08, width: snoutSize, height: snoutSize * 0.8))
    snout.fill()

    // Nose (dark)
    NSColor(red: 0.15, green: 0.1, blue: 0.05, alpha: 1.0).setFill()
    let noseSize = size * 0.08
    let nose = NSBezierPath(ovalIn: NSRect(x: centerX - noseSize/2, y: centerY - headSize/2 + size * 0.12, width: noseSize, height: noseSize * 0.7))
    nose.fill()

    // Eyes (dark)
    let eyeSize = size * 0.05
    let leftEye = NSBezierPath(ovalIn: NSRect(x: centerX - size * 0.12, y: centerY + size * 0.05, width: eyeSize, height: eyeSize))
    leftEye.fill()
    let rightEye = NSBezierPath(ovalIn: NSRect(x: centerX + size * 0.07, y: centerY + size * 0.05, width: eyeSize, height: eyeSize))
    rightEye.fill()

    image.unlockFocus()

    // Save as PNG
    if let tiffData = image.tiffRepresentation,
       let bitmapImage = NSBitmapImageRep(data: tiffData),
       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: filename))
    }
}

// Generate all required icon sizes
let sizes: [(size: CGFloat, name: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, name) in sizes {
    createIcon(size: size, filename: "AppIcon.iconset/\(name)")
    print("✓ Created \(name)")
}

print("✅ All icon sizes created")
EOF

# Compile and run the Swift script
echo "Generating icon images..."
swift generate_icon.swift

# Convert to icns using iconutil
echo "Converting to .icns format..."
iconutil -c icns "$ICON_DIR" -o "$OUTPUT_ICON"

# Clean up
rm -rf "$ICON_DIR"
rm generate_icon.swift

echo "✅ Icon created: $OUTPUT_ICON"
