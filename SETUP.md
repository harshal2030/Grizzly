# Grizzly Setup Guide

## System Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Option 1: Build with Swift Package Manager (Recommended for Quick Testing)

1. Navigate to the project directory:
```bash
cd ZipViewer
```

2. Build the project:
```bash
swift build
```

3. Run the app:
```bash
swift run
```

## Option 2: Open in Xcode (Recommended for Development)

Since this is a Swift Package, you can open it directly in Xcode:

1. Navigate to the project directory:
```bash
cd ZipViewer
```

2. Open the Package.swift in Xcode:
```bash
open Package.swift
```

3. Xcode will automatically load the package

4. Select the Grizzly scheme and click Run (Cmd+R)

## Option 3: Generate Xcode Project (Legacy)

**Note**: `swift package generate-xcodeproj` is deprecated. Use Option 2 instead.

1. Navigate to the project directory:
```bash
cd ZipViewer
```

2. Generate the Xcode project (deprecated):
```bash
swift package generate-xcodeproj
```

3. Open the generated project:
```bash
open Grizzly.xcodeproj
```

4. Build and run (Cmd+R)

## Creating a Proper macOS App Bundle

### Option A: Use the Build Script (Recommended)

The project includes a build script that creates a complete `.app` bundle:

```bash
./build-app.sh
```

This will:
- Build the release binary
- Create the app bundle structure at `.build/release/Grizzly.app`
- Include the custom app icon (AppIcon.icns)
- Configure file associations for .zip files
- Set up proper Info.plist with bundle identifier `com.grizzly.ZipViewer`

To run the app:
```bash
open .build/release/Grizzly.app
```

To install to Applications:
```bash
cp -r .build/release/Grizzly.app /Applications/
```

### Option B: Build DMG Installer

To create a distributable DMG installer:

```bash
./create-dmg.sh
```

This will:
- Build the release app bundle
- Create a DMG installer at `.build/release/Grizzly-{version}.dmg`
- Include a customized DMG with installation instructions

**Note**: For distribution outside the Mac App Store, you'll need to code sign the app with your Apple Developer certificate.

### Option C: Manual Xcode Target (Advanced)

For a distributable app with code signing, you can create it through Xcode:

1. Open Package.swift in Xcode
2. Go to File → New → Target
3. Select "macOS" → "App"
4. Configure:
   - Product Name: Grizzly
   - Team: Your development team
   - Organization Identifier: com.yourcompany
   - Interface: SwiftUI
   - Language: Swift
5. Copy all Swift files from Grizzly folder to the new target
6. Add ZIPFoundation dependency to the new target
7. Build and Archive (Product → Archive)

## Troubleshooting

### "Cannot find ZIPFoundation in scope"

Make sure you've run `swift build` at least once to download dependencies:
```bash
swift package resolve
swift build
```

### SwiftUI Preview Issues

SwiftUI previews might not work correctly with Swift Package Manager. Use Xcode's app target for better preview support.

## Continuous Integration

The project includes GitHub Actions CI/CD that automatically:
- Builds the app on every push
- Creates DMG installers for tagged releases
- Publishes releases with downloadable DMG files

To create a release:
```bash
git tag v1.0.0
git push origin v1.0.0
```

## Running Tests

Currently, no tests are implemented. To add tests:
1. Create a Tests directory with `GrizzlyTests` target
2. Add test files
3. Run: `swift test`
