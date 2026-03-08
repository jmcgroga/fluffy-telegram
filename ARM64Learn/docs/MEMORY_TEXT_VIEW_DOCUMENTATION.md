# Text Memory View Implementation

## Overview

The text memory view provides a text-focused representation of memory contents, making it easier to read string data and identify text patterns in memory. This is particularly useful for debugging programs that work with strings, file I/O, or text processing.

## Components

### 1. **MemoryTextView.swift**
The main text-focused memory view with the following features:

#### Features:
- **Text-First Display**: Shows memory as readable ASCII/UTF-8 text with line-by-line formatting
- **Non-Printable Character Handling**: Special glyphs for control characters (NULL, TAB, LF, CR, etc.)
- **Search Functionality**: Real-time text search with highlighting
- **Configurable Line Length**: Adjustable bytes per line (32, 64, 80, 128)
- **Toggle Non-Printable**: Show/hide special character glyphs
- **Live Memory Support**: Works with all memory segments (Stack, Heap, Data, Text)

#### Key Components:
- `MemoryTextView`: Main view container
- `MemoryTextViewHeader`: Header with controls and search
- `MemoryTextContent`: Text content renderer
- `MemoryTextLine`: Individual line with address and text
- `EmptyMemoryTextView`: Empty state placeholder

### 2. **MemorySplitView.swift**
A side-by-side comparison view showing both hex dump and text representation:

#### Features:
- **Split Pane Layout**: Hex dump on left, text view on right
- **Adjustable Split Ratio**: Drag divider to resize panes (20%-80% range)
- **Synchronized Content**: Both views show the same memory data
- **Visual Feedback**: Divider highlights on drag

#### Use Cases:
- Analyzing mixed binary/text data
- Comparing hex and text representations
- Understanding data encoding and byte layouts

### 3. **Enhanced MemoryHexDumpView.swift**
Improvements to the existing hex dump view:

#### New Components:
- `HexDumpRow`: Generic hex dump row with 16 bytes per line
  - Address column (11 hex digits)
  - Hex bytes with spacing every 8 bytes
  - ASCII representation column
  - Proper padding for incomplete rows
  
- `HexDumpContent`: Empty state view for segments without data

## Display Formats

### Text View Format
```
Address      | Text Content
-------------+--------------------------------------------------
0x16fdff000: | Hello, World!␊This is ARM64 assembly.␊
0x16fdff040: | Welcome to the debugger!␀␀␀
```

### Hex Dump Format
```
Address      | Hex Bytes                                        | ASCII
-------------+--------------------------------------------------+------------------
0x16fdff000: | 48 65 6c 6c 6f 2c 20 57  6f 72 6c 64 21 0a 00 00 | Hello, World!...
0x16fdff010: | 54 68 69 73 20 69 73 20  41 52 4d 36 34 00 00 00 | This is ARM64...
```

### Split View
```
┌──────────────────────────┬──────────────────────────┐
│     Hex Dump             │      Text View           │
├──────────────────────────┼──────────────────────────┤
│ 0x100: 48 65 6c 6c 6f    │ 0x100: Hello, World!     │
│ 0x105: 2c 20 57 6f 72    │ 0x105: , World!␊         │
└──────────────────────────┴──────────────────────────┘
```

## Special Character Glyphs

The text view uses Unicode control picture characters for non-printable bytes:

| Byte | Glyph | Name  |
|------|-------|-------|
| 0x00 | ␀     | NULL  |
| 0x09 | ␉     | TAB   |
| 0x0A | ␊     | LF    |
| 0x0D | ␍     | CR    |
| 0x20 | ␠     | SPACE |
| 0x7F | ␡     | DEL   |
| Other| ·     | Other |

## Integration

### Using MemoryTextView

```swift
// In your view
MemoryTextView(segmentName: "STACK")
    .environmentObject(appState)
```

### Using MemorySplitView

```swift
// In your view
MemorySplitView(segmentName: "__DATA")
    .environmentObject(appState)
```

### Adding to Bottom Panel Tabs

To add a text view tab to the bottom panel:

1. Add a new tab case to `BottomPanelTab` enum in AppState.swift:
```swift
enum BottomPanelTab: String, CaseIterable, Identifiable {
    // ... existing cases
    case textView = "Text View"
    
    var systemImage: String {
        switch self {
        // ... existing cases
        case .textView: return "doc.plaintext"
        }
    }
}
```

2. Add the view to the tab content switch in BottomPanelView.swift:
```swift
switch appState.activeBottomTab {
    // ... existing cases
    case .textView:
        MemoryTextView(segmentName: "__DATA")
}
```

## Search Functionality

The text view includes real-time search with highlighting:

- **Case-insensitive**: Searches ignore case
- **Highlight matches**: Matched text is highlighted with accent color background
- **Line highlighting**: Entire matching lines get a subtle background tint
- **Clear button**: X button to quickly clear search

## Performance Considerations

### LazyVStack
Both views use `LazyVStack` for efficient rendering of large memory regions:
- Only visible lines are rendered
- Smooth scrolling even with thousands of lines
- Minimal memory footprint

### Data Conversion
- Stack/Data entries: Converted from quadwords to byte arrays on-demand
- Heap/Text segments: Already in byte array format
- Conversion happens once per data update

## Customization

### Bytes Per Line
The text view supports multiple line widths:
- **32 bytes**: Compact view for smaller screens
- **64 bytes**: Default, good balance
- **80 bytes**: Classic terminal width
- **128 bytes**: Wide view for large displays

### Split Ratio
The split view allows adjusting the ratio:
- Drag the center divider left/right
- Ratio clamped between 20% and 80%
- Visual feedback during drag

## Examples

### Viewing C Strings
Perfect for debugging programs with string literals:
```c
.data
message:
    .asciz "Hello, World!"
name:
    .asciz "ARM64 Assembly"
```

### Analyzing Binary Data
Use split view to see both hex and text:
- Left side: Raw bytes in hex format
- Right side: Text interpretation
- Identify string boundaries and patterns

### Searching for Text Patterns
Use search to find specific strings in memory:
- Type search term in header
- Matching lines are highlighted
- Scroll through results

## Future Enhancements

Potential improvements for future versions:

1. **Encoding Selection**: Support UTF-8, UTF-16, ASCII encoding options
2. **Copy Text**: Copy selected text/lines to clipboard
3. **Export**: Export memory contents as text file
4. **Annotations**: Add user notes to specific memory addresses
5. **Diff View**: Compare memory snapshots over time
6. **String Detection**: Automatically highlight NULL-terminated strings
7. **Regex Search**: Support regular expression patterns
8. **Multi-byte Characters**: Better handling of Unicode multi-byte sequences

## Testing

All components include SwiftUI previews:

- `#Preview("Memory Text View - Stack")`: Text view with stack data
- `#Preview("Memory Text View - Data Segment")`: Data segment with strings
- `#Preview("Memory Split View - Data Segment")`: Split view example
- `#Preview("Hex Dump Row - Full")`: Individual row testing

Run previews in Xcode to test each component independently.
