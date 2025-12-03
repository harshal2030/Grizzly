#!/bin/bash

# Create a DMG installer for Grizzly

set -e

APP_NAME="Grizzly"
VERSION="${VERSION:-1.0.0}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
APP_PATH=".build/release/${APP_NAME}.app"
DMG_TMP="dmg_tmp"
VOLUME_NAME="${APP_NAME}"

echo "📦 Creating DMG installer for ${APP_NAME} v${VERSION}..."

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: ${APP_PATH} not found. Please run build-app.sh first."
    exit 1
fi

# Create temporary directory
rm -rf "$DMG_TMP"
mkdir -p "$DMG_TMP"

# Copy app to temporary directory
echo "Copying ${APP_NAME}.app..."
cp -R "$APP_PATH" "$DMG_TMP/"

# Create Applications symlink
echo "Creating Applications symlink..."
ln -s /Applications "$DMG_TMP/Applications"

# Create a temporary DMG
echo "Creating temporary DMG..."
TEMP_DMG="temp.dmg"
rm -f "$TEMP_DMG"

hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_TMP" \
    -ov -format UDRW \
    "$TEMP_DMG"

# Mount the temporary DMG
echo "Mounting temporary DMG..."
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG")
MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep -E '^/dev/' | sed 1q | awk '{print $NF}')
DEVICE=$(echo "$MOUNT_OUTPUT" | grep -E '^/dev/' | sed 1q | awk '{print $1}')

# Wait for mount
sleep 2

# Set DMG window properties and icon positions (skip on CI)
if [ -z "$CI" ]; then
    echo "Configuring DMG layout..."
    echo '
       tell application "Finder"
         tell disk "'${VOLUME_NAME}'"
               open
               set current view of container window to icon view
               set toolbar visible of container window to false
               set statusbar visible of container window to false
               set the bounds of container window to {400, 100, 900, 500}
               set viewOptions to the icon view options of container window
               set arrangement of viewOptions to not arranged
               set icon size of viewOptions to 128
               set position of item "'${APP_NAME}'.app" of container window to {125, 150}
               set position of item "Applications" of container window to {375, 150}
               set background picture of viewOptions to file ".background:background.png"
               update without registering applications
               delay 2
         end tell
       end tell
    ' | osascript || true
else
    echo "Skipping DMG layout configuration (running in CI)..."
fi

# Unmount the temporary DMG
echo "Unmounting temporary DMG..."
if [ -n "$DEVICE" ]; then
    hdiutil detach "$DEVICE" -force || true
elif [ -n "$MOUNT_DIR" ]; then
    hdiutil detach "$MOUNT_DIR" -force || true
else
    hdiutil detach "/Volumes/$VOLUME_NAME" -force || true
fi

sleep 3

# Double-check nothing is still mounted
hdiutil info | grep -q "$TEMP_DMG" && {
    hdiutil detach -all -force || true
    sleep 2
}

# Convert to final compressed DMG
echo "Creating final compressed DMG..."
rm -f "$DMG_NAME"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME"

# Clean up
rm -f "$TEMP_DMG"
rm -rf "$DMG_TMP"

# Sign the DMG if CODESIGN_IDENTITY is set
if [ -n "$CODESIGN_IDENTITY" ] && [ "$CODESIGN_IDENTITY" != "-" ]; then
    echo "🔏 Signing DMG..."
    codesign --sign "$CODESIGN_IDENTITY" --timestamp "$DMG_NAME"
    echo "✅ DMG signed!"

    # Notarize if credentials are provided
    if [ -n "$NOTARIZE_APPLE_ID" ] && [ -n "$NOTARIZE_PASSWORD" ] && [ -n "$NOTARIZE_TEAM_ID" ]; then
        echo "📮 Submitting DMG for notarization..."
        echo "This may take a few minutes..."

        xcrun notarytool submit "$DMG_NAME" \
            --apple-id "$NOTARIZE_APPLE_ID" \
            --password "$NOTARIZE_PASSWORD" \
            --team-id "$NOTARIZE_TEAM_ID" \
            --wait

        echo "📎 Stapling notarization ticket to DMG..."
        xcrun stapler staple "$DMG_NAME"

        echo "✅ DMG notarized and stapled!"
    else
        echo "⚠️  Notarization skipped. Set NOTARIZE_APPLE_ID, NOTARIZE_PASSWORD, and NOTARIZE_TEAM_ID to notarize."
    fi
elif [ "$CODESIGN_IDENTITY" = "-" ]; then
    echo "⚠️  DMG not signed (ad-hoc signing detected)"
else
    echo "⚠️  DMG not signed. Set CODESIGN_IDENTITY to sign the DMG."
fi

echo "✅ DMG created successfully: $DMG_NAME"
echo ""
echo "You can now:"
echo "  - Test it: open $DMG_NAME"
echo "  - Upload it to GitHub releases"
