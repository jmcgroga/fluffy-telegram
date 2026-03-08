# Memory View Modes - Quick Reference

## Overview

Your ARM64 debugger now supports three different ways to view memory contents, each optimized for different use cases.

## View Modes Comparison

| Feature | Hex Dump | Text View | Split View |
|---------|----------|-----------|------------|
| **Format** | Hex bytes + ASCII | Text-focused | Both side-by-side |
| **Bytes/Row** | 16 (fixed) | 32/64/80/128 (configurable) | Varies by pane |
| **Best For** | Binary data, byte-level inspection | String data, text analysis | Mixed binary/text |
| **Search** | ❌ | ✅ | ✅ (text pane) |
| **Non-Printable** | Dots (.) | Unicode glyphs (␀␉␊␍) | Both |
| **Performance** | Excellent | Excellent | Good |

## 1. Hex Dump View (Classic xxd-style)

### When to Use
- Inspecting binary data byte-by-byte
- Analyzing ARM64 machine code
- Viewing raw memory layout
- Precise byte-level debugging

### Display Format
```
Address      | Hex Bytes                                        | ASCII
0x16fdff000: | 48 65 6c 6c 6f 2c 20 57  6f 72 6c 64 21 0a 00 00 | Hello, World!...
0x16fdff010: | fd 7b bf a9 fd 03 00 91  00 00 00 94 00 00 80 52 | .{..............
```

### Features
- 16 bytes per row (industry standard)
- Extra spacing every 8 bytes for readability
- Address in 11-digit hex format
- ASCII column shows printable characters
- Non-printable shown as dots (.)

### Code Example
```swift
MemoryHexDumpView(segmentName: "STACK")
```

## 2. Text View (Text-Focused)

### When to Use
- Reading string literals and text data
- Debugging programs with lots of strings
- Searching for specific text in memory
- Analyzing text file contents
- Viewing assembly source embedded in binaries

### Display Format
```
Address      | Text Content
0x16fdff000: | Hello, ARM64 World!␊This is a test string with special chars␉␉
0x16fdff040: | Welcome to assembly programming!␀␀␀
```

### Features
- **Configurable Line Width**: 32, 64, 80, or 128 bytes per line
- **Smart Character Display**:
  - Printable (32-126): Shown as-is
  - NULL (0x00): ␀
  - TAB (0x09): ␉
  - LF (0x0A): ␊
  - CR (0x0D): ␍
  - SPACE (0x20): ␠
  - DEL (0x7F): ␡
  - Other: · (middle dot)
- **Search**: Real-time case-insensitive search
- **Highlighting**: Search results highlighted with accent color
- **Toggle**: Show/hide non-printable glyphs

### Controls
```
┌─────────────────────────────────────────────┐
│ [🔍 Search text...]                   [X]   │
│ [Lines: 64] [👁 Show Non-Printable]        │
└─────────────────────────────────────────────┘
```

### Code Example
```swift
MemoryTextView(segmentName: "__DATA")
```

## 3. Split View (Hex + Text)

### When to Use
- Comparing hex and text representations
- Understanding data encoding
- Analyzing mixed binary/text files
- Finding string boundaries in binary data
- Teaching/learning about memory layout

### Display Format
```
┌────────────────────────────┬────────────────────────────┐
│ Hex Dump                   │ Text View                  │
├────────────────────────────┼────────────────────────────┤
│ 0x100: 48 65 6c 6c 6f 00   │ 0x100: Hello␀              │
│ 0x106: 57 6f 72 6c 64 00   │ 0x106: World␀              │
│ 0x10c: fd 7b bf a9 fd 03   │ 0x10c: ·{····              │
└────────────────────────────┴────────────────────────────┘
```

### Features
- **Synchronized Scrolling**: Both panes show same data
- **Adjustable Split**: Drag divider to resize panes
  - Range: 20% to 80%
  - Visual feedback during drag
- **Independent Controls**: Each pane has its own settings
- **Perfect for Learning**: See the relationship between bytes and text

### Code Example
```swift
MemorySplitView(segmentName: "__DATA")
```

## Memory Segment Mapping

Each view can display any memory segment:

| Segment | Icon | Typical Contents | Best View |
|---------|------|------------------|-----------|
| **STACK** | 🔽 | Return addresses, local vars, saved registers | Hex Dump |
| **HEAP** | 💾 | Dynamically allocated data | Split View |
| **__DATA** | 📊 | Global variables, string literals | Text View |
| **__TEXT** | 📄 | Machine code, read-only data | Hex Dump |

## Workflow Examples

### Example 1: Finding a String in Data Section
```
1. Select .data tab
2. Switch to Text View
3. Type string in search box
4. Results highlighted automatically
```

### Example 2: Analyzing Stack Frame
```
1. Select STACK tab
2. Use Hex Dump View
3. Look for saved FP/LR at top of frame
4. Examine local variables below
```

### Example 3: Debugging String Encoding
```
1. Select __DATA tab
2. Use Split View
3. Left pane: See exact byte values
4. Right pane: See text interpretation
```

## Keyboard Shortcuts (Suggested)

While not implemented yet, these would be useful:

| Shortcut | Action |
|----------|--------|
| ⌘F | Focus search box |
| ⌘1 | Switch to Hex Dump |
| ⌘2 | Switch to Text View |
| ⌘3 | Switch to Split View |
| ⌘+ | Increase bytes per line |
| ⌘- | Decrease bytes per line |

## Data Source Integration

All views automatically connect to LLDB data:

```
LLDBController.refreshState()
    ↓
onMemoryUpdated callback
    ↓
AppState.liveStackEntries / liveDataEntries / etc.
    ↓
Memory View (auto-updates via @Published)
```

## Performance Tips

### For Large Memory Regions
- **Use Hex Dump**: Most compact view (16 bytes/row)
- **Adjust Text View**: Increase bytes per line to reduce row count
- **Search Efficiently**: Be specific to reduce matches

### For String-Heavy Programs
- **Start with Text View**: Easier to read
- **Use Search**: Quickly locate strings
- **Toggle Non-Printable**: Hide glyphs if too cluttered

### For Mixed Data
- **Use Split View**: See both representations
- **Adjust Split Ratio**: Give more space to the pane you need

## Copy & Export (Future)

Planned features for future versions:

- **Copy Row**: Right-click to copy address, hex, or text
- **Copy Selection**: Select multiple rows
- **Export**: Save memory dump to file
- **Import**: Load previous dumps for comparison

## Integration Checklist

To integrate these views into your bottom panel:

- [ ] Choose which view to use for each segment
- [ ] Update `BottomPanelView.swift` switch statement
- [ ] Test with live LLDB session
- [ ] Customize colors/styling if needed
- [ ] Add keyboard shortcuts (optional)
- [ ] Create user documentation (optional)

## Tips & Tricks

### Tip 1: Finding NULL-Terminated Strings
In Text View, look for the ␀ glyph to find string boundaries.

### Tip 2: Identifying Binary vs. Text
In Split View, if the text pane shows mostly dots/glyphs, it's binary data.

### Tip 3: Reading Stack Frames
In Hex Dump, the first two quadwords are usually saved FP and LR.

### Tip 4: Search Across Segments
Switch between segment tabs while keeping the same search term.

### Tip 5: Adjust Line Width for Your Screen
- Small screen (laptop): 32 or 64 bytes
- Large screen (desktop): 80 or 128 bytes

## Common Issues & Solutions

### Issue: "No Live Memory Data"
**Solution**: Start debugging session and step through code. Memory is only available when LLDB is running.

### Issue: Search Not Finding Text
**Solution**: Check if the string is in the current segment. Try switching segments.

### Issue: Too Many Non-Printable Characters
**Solution**: Toggle off "Show Non-Printable" to reduce clutter.

### Issue: Split View Too Cramped
**Solution**: Drag the divider to give more space to the pane you're focusing on.

## Summary

Choose the right view for your task:
- 🔍 **Hex Dump**: Binary data, precise byte inspection
- 📝 **Text View**: String data, text search
- ⚖️ **Split View**: Understanding encoding, mixed data

All views are performant, integrate seamlessly with LLDB, and provide SwiftUI previews for testing!
