# Grizzly

A modern macOS application for viewing and extracting ZIP archives, built with SwiftUI.

## Features

- **Hierarchical File Browser**: Navigate through zip contents with a Finder-like view
- **File & Folder Selection**: Select single or multiple items for extraction
- **Quick Look Preview**: Press spacebar to preview files without extracting (text, images, PDFs, etc.)
- **Search & Filter**: Quickly find files and folders within the archive
- **Flexible Extraction**: Extract individual files, folders, or the entire archive
- **Drag & Drop Support**: Simply drag a zip file into the app to open it
- **File Picker**: Use the traditional file picker dialog to open zip files
- **User-Controlled Extraction**: Choose the destination folder for each extraction
- **Progress Tracking**: Visual feedback during extraction operations

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building from source)
- Swift 5.9 or later

## Installation

### Download Pre-built App (Recommended)

1. Go to the [Releases](../../releases) page
2. Download the latest `Grizzly-X.X.X.dmg`
3. Open the DMG file
4. Drag `Grizzly.app` to the Applications folder
5. Right-click the app and select "Open" the first time to bypass Gatekeeper

### Build from Source

## Building from Source

### Quick Build (Swift Package Manager)

```bash
git clone https://github.com/YOUR_USERNAME/Grizzly.git
cd Grizzly
swift build
swift run
```

### Build macOS App Bundle

```bash
./build-app.sh
```

This creates a full `.app` bundle at `.build/release/Grizzly.app` with:
- Custom app icon
- File associations for .zip files
- Proper bundle structure for distribution

To install:
```bash
open .build/release/Grizzly.app  # Run the app
# or
cp -r .build/release/Grizzly.app /Applications/  # Install to Applications
```

### Build with Xcode

```bash
open Package.swift
# Then press Cmd+R to run
```

## Usage

### Opening a Zip File

1. **Drag & Drop**: Drag a .zip file onto the application window
2. **File Menu**: Use Cmd+O or File → Open to select a zip file
3. **Double-click**: Associate .zip files with Grizzly and open them directly

### Navigating Contents

- **Double-click folders** to navigate into them
- **Double-click files** to extract and open them with default application
- **Back button** or breadcrumb navigation to go up directories
- Single-click to select a file or folder
- Cmd+Click to select multiple items
- Shift+Click to select a range of items

### Previewing & Opening Files

- **Double-click a file** to extract and open it with the default application
- **Press Spacebar** to Quick Look preview without extracting
- Preview supports: images, PDFs, text files, code files, and more

### Extracting Files

1. Select the files/folders you want to extract
2. Click the "Extract" button in the toolbar or right-click and select "Extract..."
3. Choose the destination folder
4. Click "Extract" to confirm

### Searching

Use the search bar at the top of the sidebar to filter files and folders by name.

## Architecture

The app is built using modern SwiftUI patterns:

- **Models**: `ZipEntry` for representing archive contents, `ZipArchiveManager` for archive operations
- **ViewModels**: `AppState` for managing application state
- **Views**: SwiftUI components for the user interface

## Dependencies

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation): Robust zip archive handling

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Releasing

To create a new release:

1. Tag your commit with a version number:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. GitHub Actions will automatically:
   - Build the app
   - Create a DMG installer
   - Publish a new release with the DMG attached

3. The release will appear on the [Releases](../../releases) page

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have suggestions, please [open an issue](../../issues) on GitHub.
