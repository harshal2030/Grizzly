#!/bin/bash

# Build script to create a macOS .app bundle for Grizzly

set -e

echo "🔨 Building Grizzly.app..."

# Navigate to the project directory
cd "$(dirname "$0")"

# Build the release binary
swift build -c release

# Create app bundle structure
APP_NAME="Grizzly"
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
cp "$BUILD_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Copy icon if it exists
if [ -f "AppIcon.icns" ]; then
    echo "📎 Adding app icon..."
    cp "AppIcon.icns" "$APP_DIR/Contents/Resources/"
fi

# Copy entitlements if they exist
if [ -f "Grizzly.entitlements" ]; then
    echo "📋 Found entitlements file..."
    ENTITLEMENTS_PATH="Grizzly.entitlements"
fi

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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
            <string>Editor</string>
            <key>CFBundleTypeIconFile</key>
            <string>AppIcon</string>
            <key>LSHandlerRank</key>
            <string>Default</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.zip-archive</string>
                <string>com.pkware.zip-archive</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>zip</string>
            </array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>public.zip-archive</string>
            <key>UTTypeReferenceURL</key>
            <string>https://en.wikipedia.org/wiki/ZIP_(file_format)</string>
            <key>UTTypeDescription</key>
            <string>ZIP Archive</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
                <string>public.archive</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>zip</string>
                </array>
                <key>public.mime-type</key>
                <array>
                    <string>application/zip</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF

# Code signing
if [ -n "$CODESIGN_IDENTITY" ]; then
    echo "🔏 Signing app with identity: $CODESIGN_IDENTITY"

    # Sign the executable first
    if [ -n "$ENTITLEMENTS_PATH" ]; then
        codesign --force --sign "$CODESIGN_IDENTITY" \
            --entitlements "$ENTITLEMENTS_PATH" \
            --options runtime \
            --timestamp \
            "$APP_DIR/Contents/MacOS/$APP_NAME"
    else
        codesign --force --sign "$CODESIGN_IDENTITY" \
            --options runtime \
            --timestamp \
            "$APP_DIR/Contents/MacOS/$APP_NAME"
    fi

    # Sign the entire app bundle
    if [ -n "$ENTITLEMENTS_PATH" ]; then
        codesign --force --sign "$CODESIGN_IDENTITY" \
            --entitlements "$ENTITLEMENTS_PATH" \
            --options runtime \
            --timestamp \
            --deep \
            "$APP_DIR"
    else
        codesign --force --sign "$CODESIGN_IDENTITY" \
            --options runtime \
            --timestamp \
            --deep \
            "$APP_DIR"
    fi

    # Verify the signature
    echo "🔍 Verifying code signature..."
    codesign --verify --verbose "$APP_DIR"

    echo "✅ Code signing complete!"
else
    echo "⚠️  Warning: CODESIGN_IDENTITY not set. App will not be signed."
    echo "   To sign the app, set CODESIGN_IDENTITY environment variable:"
    echo "   export CODESIGN_IDENTITY=\"Developer ID Application: Your Name (TEAM_ID)\""
    echo ""
    echo "   For ad-hoc signing (local use only):"
    echo "   export CODESIGN_IDENTITY=\"-\""
fi

echo "✅ Build complete!"
echo ""
echo "App bundle created at: $APP_DIR"
echo ""
echo "To run the app:"
echo "  open $APP_DIR"
echo ""
echo "To copy to Applications:"
echo "  cp -r $APP_DIR /Applications/"
