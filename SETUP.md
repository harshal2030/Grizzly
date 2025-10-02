# ZipViewer Setup Guide

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

## Option 2: Create Xcode Project (Recommended for Development)

Since this is a Swift Package, you can create an Xcode project:

1. Navigate to the project directory:
```bash
cd ZipViewer
```

2. Open the Package.swift in Xcode:
```bash
open Package.swift
```

3. Xcode will automatically create a project workspace

4. Select the ZipViewer scheme and click Run (Cmd+R)

## Option 3: Generate Xcode Project Manually

1. Navigate to the project directory:
```bash
cd ZipViewer
```

2. Generate the Xcode project:
```bash
swift package generate-xcodeproj
```

3. Open the generated project:
```bash
open ZipViewer.xcodeproj
```

4. Build and run (Cmd+R)

## Creating a Proper macOS App Bundle

For a distributable app, you'll need to create it through Xcode:

1. Open Package.swift in Xcode
2. Go to File → New → Target
3. Select "macOS" → "App"
4. Configure:
   - Product Name: ZipViewer
   - Team: Your development team
   - Organization Identifier: com.yourcompany
   - Interface: SwiftUI
   - Language: Swift
5. Copy all Swift files from ZipViewer folder to the new target
6. Update Package.swift dependencies in the new target
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

## Running Tests

Currently, no tests are implemented. To add tests:
1. Create a Tests directory
2. Add test files
3. Run: `swift test`
