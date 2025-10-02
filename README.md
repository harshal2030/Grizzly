# ZipViewer

A modern macOS application for viewing and extracting ZIP archives, built with SwiftUI.

## Features

- **Hierarchical File Browser**: Navigate through zip contents with a Finder-like tree view
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

## Building from Source

1. Clone the repository
2. Navigate to the ZipViewer directory
3. Open the project in Xcode or build with Swift Package Manager:

```bash
cd ZipViewer
swift build
```

## Usage

### Opening a Zip File

1. **Drag & Drop**: Drag a .zip file onto the application window
2. **File Menu**: Use Cmd+O or File → Open to select a zip file
3. **Double-click**: Associate .zip files with ZipViewer (coming soon)

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

## License

Copyright © 2025. All rights reserved.
