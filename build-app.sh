#!/bin/bash

# Build a macOS .app bundle for Grizzly, including the embedded Quick Look
# preview extension.
#
# This uses the XcodeGen project (project.yml) via xcodebuild, because the
# Quick Look extension is an app extension that Swift Package Manager cannot
# build or embed. The resulting universal (arm64 + x86_64) .app is written to
# the same location the previous SwiftPM flow used, so create-dmg.sh keeps
# working unchanged. The app's Info.plist and document-type registration now
# come solely from project.yml.

set -e

echo "🔨 Building Grizzly.app (with Quick Look extension)..."

cd "$(dirname "$0")"

APP_NAME="Grizzly"
# VERSION is supplied by CI from the git tag; default to 1.0 for local builds.
VERSION="${VERSION:-1.0}"
DERIVED_DIR=".build/xcode"
OUTPUT_DIR=".build/apple/Products/Release"
BUILT_APP="$DERIVED_DIR/Build/Products/Release/$APP_NAME.app"
APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
APPEX_REL="Contents/PlugIns/GrizzlyQuickLook.appex"

# Regenerate the Xcode project from project.yml so the build always matches the
# declarative spec. Requires XcodeGen (brew install xcodegen).
if command -v xcodegen >/dev/null 2>&1; then
    echo "⚙️  Generating Xcode project from project.yml..."
    xcodegen generate
else
    echo "⚠️  xcodegen not found; using the committed Grizzly.xcodeproj as-is."
    echo "   Install it with: brew install xcodegen"
fi

# Build a universal Release build. Signing is handled below so we can apply
# per-target entitlements to the app and the extension.
echo "📦 Building universal Release (arm64 + x86_64)..."
xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME-macOS" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DIR" \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$VERSION" \
    CODE_SIGNING_ALLOWED=NO \
    build

# Stage the built app at the location create-dmg.sh expects.
echo "🚚 Staging app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$OUTPUT_DIR"
cp -R "$BUILT_APP" "$APP_DIR"

# Code signing. The extension (inside PlugIns) must be signed before the app so
# the app's signature seals it.
sign() {
    local target="$1" entitlements="$2"
    if [ -n "$CODESIGN_IDENTITY" ] && [ "$CODESIGN_IDENTITY" != "auto" ]; then
        codesign --force --options runtime --timestamp \
            --sign "$CODESIGN_IDENTITY" --entitlements "$entitlements" "$target"
    else
        # Ad-hoc: no hardened runtime / timestamp (can't be notarized anyway).
        codesign --force --sign "-" --entitlements "$entitlements" "$target"
    fi
}

if [ -n "$CODESIGN_IDENTITY" ] && [ "$CODESIGN_IDENTITY" != "auto" ]; then
    echo "🔏 Signing with identity: $CODESIGN_IDENTITY"
else
    echo "🔏 Applying ad-hoc signature (allows 'Open Anyway' in System Settings)..."
fi

sign "$APP_DIR/$APPEX_REL" "GrizzlyQuickLook.entitlements"
sign "$APP_DIR" "Grizzly.entitlements"

echo "🔍 Verifying signatures..."
codesign --verify --deep --verbose=2 "$APP_DIR"

echo "✅ Build complete!"
echo ""
echo "App bundle created at: $APP_DIR"
echo "  (Quick Look extension embedded at $APPEX_REL)"
echo ""
echo "To run the app:  open $APP_DIR"
echo "To install:      cp -r $APP_DIR /Applications/"
if [ -z "$CODESIGN_IDENTITY" ] || [ "$CODESIGN_IDENTITY" = "auto" ]; then
    echo ""
    echo "ℹ️  Ad-hoc signed. Users open via System Settings → Privacy & Security → Open Anyway."
    echo "   For distribution without warnings, set CODESIGN_IDENTITY to a Developer ID."
fi
