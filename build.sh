#!/bin/bash

# Build script for ZipViewer macOS app

set -e

echo "🔨 Building ZipViewer..."

# Navigate to the project directory
cd "$(dirname "$0")"

# Build the app
swift build -c release

echo "✅ Build complete!"
echo ""
echo "To run the app:"
echo "  swift run"
echo ""
echo "Or build a standalone app bundle with Xcode:"
echo "  1. Open the project in Xcode"
echo "  2. Select Product > Archive"
echo "  3. Distribute the app"
