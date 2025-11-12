# Building Grizzly for iOS/iPadOS

Grizzly now supports both macOS and iOS/iPadOS! The app has been made cross-platform with conditional compilation for platform-specific features.

## Prerequisites

- macOS with Xcode 15.0 or later
- iOS 17.0+ device or simulator
- Apple Developer account (for device deployment)

## Building for iOS/iPadOS

### Option 1: Using Xcode (Recommended)

1. Open the project in Xcode:
   ```bash
   open Package.swift
   ```

2. In Xcode:
   - Select the `Grizzly` scheme
   - Choose an iOS destination (simulator or device) from the destination picker
   - Press `Cmd+R` to build and run

### Option 2: Using xcodebuild

To build for iOS simulator:
```bash
xcodebuild -scheme Grizzly \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch),OS=latest' \
  -derivedDataPath .build
```

To build for iOS device:
```bash
xcodebuild -scheme Grizzly \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build
```

## Platform Differences

### macOS Features
- Multiple windows support
- Drag & drop zip files
- Native file picker with folder selection
- Quick Look preview with spacebar
- "Show in Finder" context menu option
- Extract to any folder location

### iOS/iPadOS Features
- Single window interface
- Document picker for opening zip files
- Quick Look preview
- Automatic extraction to Documents folder
- Optimized touch interface
- Share extracted files

## Architecture

The cross-platform implementation uses:

- **Conditional Compilation**: `#if os(macOS)` and `#if os(iOS)` directives
- **PlatformUtils.swift**: Abstraction layer for platform-specific APIs
- **Cross-platform UI**: SwiftUI views that adapt to each platform
- **Unified Business Logic**: Core ZIP handling works identically on both platforms

### Key Platform-Specific Components

1. **File Picking**
   - macOS: `NSOpenPanel` for folder selection
   - iOS: `UIDocumentPicker` for file/folder selection

2. **File Operations**
   - macOS: `NSWorkspace` for opening files and showing in Finder
   - iOS: Quick Look and share sheets for file handling

3. **Clipboard**
   - macOS: `NSPasteboard`
   - iOS: `UIPasteboard`

4. **Window Management**
   - macOS: Multi-window support with `WindowGroup(for: URL.self)`
   - iOS: Single-window `NavigationView` interface

## Known Limitations on iOS

1. **File System Access**: iOS apps are sandboxed. Extracted files go to the app's Documents directory.
2. **No Multiple Windows**: iOS uses a single-window interface (though iPad supports multiple instances).
3. **No Drag & Drop**: Currently not implemented for iOS (could be added in future).
4. **Limited File Sharing**: Files must be shared through the iOS share sheet.

## Future Enhancements

Potential iOS-specific features to add:
- iCloud Drive integration
- Files app integration for better file management
- Drag & drop support on iPad
- Share extension for opening zips from other apps
- Custom file destination picker
- Split View support on iPad
