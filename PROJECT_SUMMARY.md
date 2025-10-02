# ZipViewer Project Summary

## Overview
ZipViewer is a modern macOS application built with SwiftUI for viewing and extracting ZIP archives. It provides a Finder-like experience with advanced features like Quick Look preview, search, and multiple file selection.

## Project Structure

```
ZipViewer/
├── Package.swift                      # Swift Package Manager configuration
├── Sources/
│   └── ZipViewer/
│       ├── ZipViewerApp.swift        # Main app entry point
│       ├── Models/
│       │   ├── ZipEntry.swift        # Data model for zip entries
│       │   └── ZipArchiveManager.swift # Zip operations manager
│       ├── ViewModels/
│       │   └── AppState.swift        # Observable app state
│       └── Views/
│           ├── ContentView.swift     # Main app UI
│           └── ZipTreeView.swift     # Hierarchical tree view
├── README.md                          # Project overview
├── SETUP.md                           # Detailed setup instructions
├── QUICKSTART.md                      # Quick start guide
└── build.sh                           # Build script

```

## Technical Stack

- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Platform**: macOS 14.0+ (Sonoma)
- **Dependencies**:
  - [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) 0.9.0+ - Zip archive handling
- **Build System**: Swift Package Manager

## Key Features Implemented

### ✅ Core Functionality
- [x] Open zip files via file picker
- [x] Drag & drop support for zip files
- [x] Hierarchical tree view (Finder-like)
- [x] File and folder icons with appropriate SF Symbols
- [x] Extract individual files
- [x] Extract folders
- [x] Extract entire archive
- [x] User-selected extraction destination

### ✅ Advanced Features
- [x] Quick Look preview on spacebar press
- [x] Search and filter functionality
- [x] Multiple selection (Cmd+Click, Shift+Click)
- [x] Context menu (right-click) support
- [x] Progress tracking during extraction
- [x] File metadata display (size, compression ratio, date)
- [x] Empty state with helpful instructions
- [x] Error handling with user-friendly messages

### ✅ User Experience
- [x] Finder-like navigation
- [x] Disclosure triangles for folders
- [x] File type detection and appropriate icons
- [x] Formatted file sizes
- [x] Compression statistics
- [x] Keyboard shortcuts (Cmd+O, Spacebar)
- [x] Visual feedback during operations

## Architecture

### Models
- **ZipEntry**: Represents a file or folder within the archive
  - Properties: path, name, size, compressed size, type, children
  - Methods: icon selection, size formatting, type detection

- **ZipArchiveManager**: Handles all zip operations
  - Open and read archives
  - Build hierarchical structure
  - Extract files/folders
  - Preview file data
  - Progress tracking

### ViewModels
- **AppState**: Central state management (ObservableObject)
  - Manages zip entries
  - Handles selection
  - Coordinates extraction
  - Search filtering
  - Error state

### Views
- **ContentView**: Main application window
  - NavigationSplitView layout
  - Sidebar with tree view
  - Detail panel for selected items
  - File picker integration
  - Extraction UI

- **ZipTreeView**: Hierarchical file browser
  - Recursive folder structure
  - Selection handling
  - Context menus
  - Quick Look integration
  - Keyboard event handling

## Building and Running

### Quick Build
```bash
cd ZipViewer
swift build
swift run
```

### Xcode
```bash
open Package.swift
# Then press Cmd+R to run
```

## Known Limitations

1. **Progress Tracking**: Basic progress indication (percentage based on file count, not actual byte progress)
2. **Preview**: Limited to file types supported by macOS Quick Look
3. **Large Archives**: No streaming extraction - entire archive loaded into memory
4. **Password Protection**: No support for encrypted/password-protected zips
5. **Multi-Archive**: Can only view one zip at a time

## Future Enhancement Ideas

- [ ] Support for password-protected archives
- [ ] Better progress tracking (byte-level)
- [ ] Multiple archive windows
- [ ] Archive creation (zip files)
- [ ] Archive modification (add/remove files)
- [ ] Support for other archive formats (.rar, .7z, .tar.gz)
- [ ] File associations (open .zip files with double-click)
- [ ] Dark/Light mode optimization
- [ ] Keyboard navigation improvements
- [ ] Batch extraction queue
- [ ] Archive integrity checking
- [ ] Custom extraction options (overwrite policies)

## Dependencies Management

Dependencies are managed via Swift Package Manager. To update:

```bash
swift package update
```

Current dependencies:
- **ZIPFoundation**: Provides robust zip archive handling with modern Swift API

## Testing

No automated tests are currently implemented. Manual testing covers:
- Opening various zip archives
- Navigating folder structures
- Extracting files and folders
- Search functionality
- Quick Look preview
- Multi-selection

## Performance Considerations

- Archives are loaded into memory entirely
- Hierarchical structure built on load
- Search filters in-memory (no indexing)
- Suitable for archives up to several hundred MB
- For very large archives (GB+), consider streaming approaches

## License

Copyright © 2025. All rights reserved.

## Credits

Built with:
- SwiftUI by Apple
- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) by Thomas Zoechling
- SF Symbols by Apple
