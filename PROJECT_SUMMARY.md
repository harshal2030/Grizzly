# Grizzly Project Summary

## Overview
Grizzly is a modern macOS application built with SwiftUI for viewing and extracting ZIP archives. It provides a Finder-like experience with advanced features like Quick Look preview, search, and multiple file selection.

## Project Structure

```
ZipViewer/
├── Package.swift                      # Swift Package Manager configuration
├── Sources/
│   └── Grizzly/
│       ├── GrizzlyApp.swift          # Main app entry point with AppDelegate
│       ├── Models/
│       │   ├── ZipEntry.swift        # Data model for zip entries
│       │   └── ZipArchiveManager.swift # Zip operations manager
│       ├── ViewModels/
│       │   └── AppState.swift        # Observable app state
│       └── Views/
│           ├── ContentView.swift     # Main app UI with file picker
│           └── ZipTreeView.swift     # Hierarchical tree view with keyboard shortcuts
├── README.md                          # Project overview
├── SETUP.md                           # Detailed setup instructions
├── QUICKSTART.md                      # Quick start guide
├── PROJECT_SUMMARY.md                 # This file - technical overview
├── build-app.sh                       # macOS app bundle build script
├── create-dmg.sh                      # DMG installer creation script
├── AppIcon.icns                       # Custom app icon
└── .github/workflows/                 # GitHub Actions CI/CD
    └── build.yml                      # Automated build and release

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
- [x] Search and filter functionality with recursive tree filtering
- [x] Multiple selection (Cmd+Click, Shift+Click)
- [x] Context menu (right-click) support
- [x] Progress tracking during extraction and loading
- [x] File metadata display (size, compression ratio, date, type)
- [x] Empty state with helpful instructions
- [x] Error handling with user-friendly messages
- [x] Breadcrumb navigation for folder hierarchy
- [x] Comprehensive keyboard shortcuts

### ✅ User Experience
- [x] Finder-like navigation with breadcrumb trail
- [x] File type detection and appropriate SF Symbols icons
- [x] Formatted file sizes with compression statistics
- [x] Comprehensive keyboard shortcuts (see below)
- [x] Visual feedback during operations with progress overlays
- [x] Drag & drop support for opening zip files
- [x] File association support (open .zip files with double-click from Finder)
- [x] Detail panel showing file information for selected items
- [x] Multi-item selection with aggregate statistics

## Architecture

### Models
- **ZipEntry**: Represents a file or folder within the archive
  - Properties: path, name, size, compressed size, type, children, modification date
  - Computed properties: icon, formattedSize, compressionRatio, fileType, totalUncompressedSize
  - Methods: size formatting, type detection with UTType support
  - Implements Identifiable and Hashable for SwiftUI

- **ZipArchiveManager**: Handles all zip operations using ZIPFoundation
  - **Archive Opening**: Reads zip central directory (metadata only, not entire archive)
  - **Hierarchy Building**: Constructs tree structure with chunked processing (1000 entries/chunk)
  - **Extraction**: Supports single file, multiple files, and full archive extraction with streaming
  - **Preview**: On-demand file data extraction for Quick Look
  - **Progress Tracking**: Callbacks for loading and extraction progress
  - **Memory Efficient**: Uses streaming for extraction, only loads individual files when needed

### ViewModels
- **AppState**: Central state management (@MainActor ObservableObject)
  - Manages zip entries and hierarchical structure
  - Selection handling (single, multiple, range selection)
  - Coordinates extraction operations with progress tracking
  - Recursive search filtering across tree structure
  - Error state management
  - Focused entry tracking for keyboard navigation
  - Async/await integration for file operations

### Views
- **ContentView**: Main application window
  - Split layout with file tree and detail panel
  - Detail panel shows with slide animation when items selected
  - File picker integration with UTType.zip
  - Custom destination picker dialog
  - Progress overlays for loading and extraction
  - Drag & drop handling for .zip files
  - NotificationCenter integration for open events
  - Toolbar with Open and Extract buttons

- **ZipTreeView**: Hierarchical file browser with full keyboard navigation
  - Breadcrumb navigation with back button
  - Nested folder navigation (single-pane view)
  - Selection handling (Cmd+Click, Shift+Click)
  - Context menus for files and folders
  - Quick Look integration with temporary files
  - Comprehensive keyboard shortcuts (see below)
  - Keyboard navigation with arrow keys
  - Double-click to open files or navigate folders

- **FileDetailView**: Information panel for selected items
  - File icon and type display
  - Size, compression ratio, modification date
  - Full path with text selection enabled

## Keyboard Shortcuts

### Navigation
- `↑/↓` - Navigate between items
- `Shift+↑/↓` - Extend selection (range select)
- `Cmd+↑` - Navigate up to parent folder
- `Cmd+↓` - Navigate into selected folder
- `Return` - Open file or enter folder
- `Delete/Backspace` - Clear selection or go up

### Selection
- `Cmd+Click` - Toggle selection (multi-select)
- `Shift+Click` - Range selection
- `Cmd+A` - Select all in current view
- `Escape` - Clear selection
- `Cmd+C` - Copy selected file paths to clipboard

### File Operations
- `Cmd+O` - Open zip file / Open selected files
- `Spacebar` - Quick Look preview
- `Cmd+E` - Extract selected items
- `Cmd+Shift+E` - Extract all
- `Cmd+F` - Focus search field

## Building and Running

### Quick Build
```bash
cd ZipViewer
swift build
swift run
```

### Build macOS App Bundle
```bash
./build-app.sh
open .build/release/Grizzly.app
```

This creates a complete `.app` bundle with:
- Custom app icon
- File associations for .zip files
- Proper bundle structure

### Xcode
```bash
open Package.swift
# Then press Cmd+R to run
```

## Known Limitations

1. **Progress Tracking**: Basic progress indication (percentage based on file count, not actual byte progress)
2. **Preview**: Limited to file types supported by macOS Quick Look
3. **Preview Memory Usage**: Quick Look preview loads the entire previewed file into memory (but not the entire archive)
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

- **Efficient Memory Usage**: Only the zip central directory (metadata) is loaded into memory, not the entire archive
- **Streaming Extraction**: Files are extracted using streaming, allowing efficient handling of large archives
- **Hierarchical Structure**: Built from metadata during initial load with chunked processing (1000 entries per chunk)
- **Search**: Filters in-memory with recursive tree traversal
- **Preview**: Individual files are loaded into memory only when previewed or opened
- **Scalability**: Can handle large archives (GB+) efficiently for browsing; memory usage is proportional to number of entries and individual file operations, not total archive size
