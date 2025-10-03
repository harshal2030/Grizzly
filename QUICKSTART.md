# Quick Start Guide

## Build and Run

### Option 1: Quick Test (3 steps)

1. **Navigate to project:**
   ```bash
   cd ZipViewer
   ```

2. **Build the app:**
   ```bash
   swift build
   ```

3. **Run the app:**
   ```bash
   swift run
   ```

### Option 2: Build macOS App Bundle (Recommended)

1. **Build the app bundle:**
   ```bash
   ./build-app.sh
   ```

2. **Run the app:**
   ```bash
   open .build/release/Grizzly.app
   ```

3. **Optional - Install to Applications:**
   ```bash
   cp -r .build/release/Grizzly.app /Applications/
   ```

This creates a proper macOS app with:
- Custom app icon
- File associations for .zip files (double-click to open)
- Can be launched from Finder or Spotlight

## Using the App

### Opening a Zip File
- **Drag & Drop**: Drag any .zip file onto the app window
- **File Menu**: Press `Cmd+O` or use File → Open
- The app will display the zip contents in a hierarchical tree view

### Browsing Contents
- **Double-click folders** to navigate into them
- Use the **Back button** or **breadcrumb trail** to navigate up/to specific folder
- Single-click to select a file or folder
- **Arrow keys** (↑/↓) to navigate between items
- **Return** to open file or enter folder
- Use search bar to filter items (works across all folders)

### Opening & Previewing Files

**Open a file (extract and launch):**
- **Double-click** any file to extract it and open with default application

**Preview without extracting:**
- Select a file (not a folder)
- Press **Spacebar** to Quick Look preview
- Works with images, PDFs, text files, code files, and more

### Extracting Files

**Extract Selected Items:**
1. Select one or more files/folders (Cmd+Click for multiple)
2. Click "Extract" button in toolbar
3. Choose destination folder
4. Click "Extract" to confirm

**Extract Everything:**
1. With no items selected, click "Extract" button
2. Choose destination folder
3. Click "Extract"

**Extract via Right-Click:**
- Right-click any item
- Select "Extract..." from context menu
- Choose destination

## Keyboard Shortcuts

### Navigation
- `↑/↓` - Navigate between items
- `Shift+↑/↓` - Extend selection (range select)
- `Cmd+↑` - Navigate up to parent folder
- `Cmd+↓` - Navigate into selected folder
- `Return` - Open file or enter folder
- `Delete` - Clear selection or go up

### Selection
- `Cmd+A` - Select all
- `Escape` - Clear selection
- `Cmd+C` - Copy file paths

### File Operations
- `Cmd+O` - Open zip file / Open selected files
- `Spacebar` - Quick Look preview
- `Cmd+E` - Extract selected items
- `Cmd+Shift+E` - Extract all
- `Cmd+F` - Focus search

## Features Showcase

✅ Finder-like tree navigation with breadcrumb trail
✅ Multiple file selection (Cmd+Click, Shift+Click)
✅ Quick Look preview (Spacebar)
✅ Recursive search and filter
✅ Drag & drop support
✅ Progress tracking during extraction and loading
✅ Context menu support
✅ Full keyboard navigation
✅ Memory-efficient - handles large archives (GB+)
✅ Detail panel with file information

## Tips

- You can select multiple items to extract them all at once
- The search works recursively across all folders
- Preview works for most file types supported by macOS Quick Look
- Extraction preserves the folder structure
- The app shows file sizes and compression ratios in the detail panel
- Use keyboard shortcuts for faster navigation
- The app efficiently handles large archives - only metadata is kept in memory
- Use `Cmd+C` to copy file paths from the archive

## Troubleshooting

**App won't build:**
```bash
# Clean and rebuild
rm -rf .build
swift package clean
swift build
```

**Can't open in Xcode:**
```bash
# Open Package.swift directly
open Package.swift
```

**Preview not working:**
- Make sure you selected a file (not a folder)
- Some file types may not support Quick Look preview
