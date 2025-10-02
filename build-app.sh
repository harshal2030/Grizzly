#!/bin/bash

# Build script to create a macOS .app bundle for ZipViewer

set -e

echo "🔨 Building ZipViewer.app..."

# Navigate to the project directory
cd "$(dirname "$0")"

# Build the release binary
swift build -c release

# Create app bundle structure
APP_NAME="ZipViewer"
APP_BUNDLE="$APP_NAME.app"
BUILD_DIR=".build/release"
APP_DIR="$BUILD_DIR/$APP_BUNDLE"

echo "📦 Creating app bundle structure..."

# Remove old app bundle if it exists
rm -rf "$APP_DIR"

# Create the bundle structure
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy the executable
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/"

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.grizzly.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025. All rights reserved.</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>ZIP Archive</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.zip-archive</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "✅ Build complete!"
echo ""
echo "App bundle created at: $APP_DIR"
echo ""
echo "To run the app:"
echo "  open $APP_DIR"
echo ""
echo "To copy to Applications:"
echo "  cp -r $APP_DIR /Applications/"
