# Memory View Examples - Real World Scenarios

## Example 1: C String in .data Section

### Source Code (ARM64 Assembly)
```assembly
.data
greeting:
    .asciz "Hello, ARM64 World!"
prompt:
    .asciz "Enter your name: "
```

### Hex Dump View
```
Address      | Hex Bytes                                        | ASCII
0x100008000: | 48 65 6c 6c 6f 2c 20 41  52 4d 36 34 20 57 6f 72 | Hello, ARM64 Wor
0x100008010: | 6c 64 21 00 45 6e 74 65  72 20 79 6f 75 72 20 6e | ld!.Enter your n
0x100008020: | 61 6d 65 3a 20 00                                | ame: .
```

### Text View
```
Address      | Text Content
0x100008000: | Hello, ARM64 World!␀Enter your name: ␀
```

### Analysis
- **Hex Dump**: Shows exact byte layout including NULL terminators (00)
- **Text View**: Displays strings naturally with ␀ glyphs marking boundaries
- **Best Choice**: Text View for quick reading, Hex Dump for precise byte positions

---

## Example 2: Stack Frame with Mixed Data

### Source Code (C)
```c
int main(void) {
    char buffer[16] = "Test";
    int value = 42;
    return value;
}
```

### Hex Dump View
```
Address      | Hex Bytes                                        | ASCII
0x16fdff000: | 10 f0 df 6f 01 00 00 00  80 3f 00 00 01 00 00 00 | ...o.....?......
0x16fdff010: | 54 65 73 74 00 00 00 00  00 00 00 00 00 00 00 00 | Test............
0x16fdff020: | 2a 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00 | *...............
```

### Text View (with non-printable shown)
```
Address      | Text Content
0x16fdff000: | ··o·····?·······
0x16fdff010: | Test············
0x16fdff020: | *···············
```

### Split View Analysis
```
Left (Hex)                        Right (Text)
0x16fdff000: 10 f0 df 6f...     | ··o·····  ← Saved frame pointer
0x16fdff008: 80 3f 00 00...     | ··?·····  ← Saved return address
0x16fdff010: 54 65 73 74...     | Test····  ← String "Test" + padding
0x16fdff020: 2a 00 00 00...     | *·······  ← Integer 42 (0x2A)
```

### Analysis
- **Mixed Data**: Addresses, strings, and integers
- **Best Choice**: Split View to correlate hex values with their meanings
- **Text View Limitation**: Binary data shows as dots
- **Hex Dump Strength**: Precise byte-level inspection

---

## Example 3: ARM64 Machine Code in .text Section

### Disassembly
```assembly
0x100003f80:  stp x29, x30, [sp, #-16]!   ; Save FP and LR
0x100003f84:  mov x29, sp                 ; Set up frame pointer
0x100003f88:  bl  _printf                 ; Call printf
0x100003f8c:  mov w0, #0                  ; Return 0
0x100003f90:  ldp x29, x30, [sp], #16     ; Restore FP and LR
0x100003f94:  ret                         ; Return
```

### Hex Dump View
```
Address      | Hex Bytes                                        | ASCII
0x100003f80: | fd 7b bf a9 fd 03 00 91  00 00 00 94 00 00 80 52 | .{..............
0x100003f90: | fd 7b c1 a8 c0 03 5f d6  00 00 00 00 00 00 00 00 | .{...._.........
```

### Text View
```
Address      | Text Content
0x100003f80: | ·{······················
0x100003f90: | ·{···_··········
```

### Analysis
- **Machine Code**: All binary data, no text
- **Best Choice**: Hex Dump - Text View shows only dots
- **Alternative**: Use a disassembly view (not implemented)

---

## Example 4: Searching for Text

### Data Section Contents
```
.data
error1: .asciz "File not found"
error2: .asciz "Permission denied"
error3: .asciz "Invalid file format"
```

### Text View with Search: "file"
```
Address      | Text Content                          | Match
0x100008000: | File not found␀                       | ✓ (highlighted)
0x100008010: | Permission denied␀                    |
0x100008022: | Invalid file format␀                  | ✓ (highlighted)
```

### Visual in Text View
```
┌─────────────────────────────────────────────────────┐
│ [🔍 file                                       [X]] │
├─────────────────────────────────────────────────────┤
│ 0x100008000: ▓▓▓▓ not found␀                       │ ← Highlighted
│ 0x100008010: Permission denied␀                     │
│ 0x100008022: Invalid ▓▓▓▓ format␀                  │ ← Highlighted
└─────────────────────────────────────────────────────┘
```

### Analysis
- **Search**: Case-insensitive matches "File" and "file"
- **Highlighting**: Both the matched text and entire line
- **Use Case**: Quickly locate error messages, debug strings

---

## Example 5: String with Special Characters

### Source Code
```c
char *message = "Line 1\nLine 2\tTabbed\0\0\0";
```

### Hex Dump View
```
Address      | Hex Bytes                                        | ASCII
0x100008000: | 4c 69 6e 65 20 31 0a 4c  69 6e 65 20 32 09 54 61 | Line 1.Line 2.Ta
0x100008010: | 62 62 65 64 00 00 00                             | bbed...
```

### Text View (with non-printable ON)
```
Address      | Text Content
0x100008000: | Line 1␊Line 2␉Tabbed␀␀␀
```

### Text View (with non-printable OFF)
```
Address      | Text Content
0x100008000: | Line 1·Line 2·Tabbed···
```

### Analysis
- **Special Characters**: LF (␊), TAB (␉), NULL (␀) clearly visible
- **Toggle Benefit**: Clean view vs. detailed view
- **Best for**: Understanding whitespace and control characters

---

## Example 6: Split View for Mixed Binary/Text

### Real Data: Mach-O Header + String
```
Data contains: Mach-O magic number followed by a string
```

### Split View
```
┌──────────────────────────────┬──────────────────────────────┐
│ Hex Dump                     │ Text View                    │
├──────────────────────────────┼──────────────────────────────┤
│ 0x100000000:                 │ 0x100000000:                 │
│ cf fa ed fe 07 00 00 01      │ ········                     │
│ 03 00 00 00 02 00 00 00      │ ········                     │
│                              │                              │
│ 0x100000010:                 │ 0x100000010:                 │
│ 48 65 6c 6c 6f 00 00 00      │ Hello␀␀␀                     │
└──────────────────────────────┴──────────────────────────────┘
                    ↑
              Drag to resize
```

### Analysis
- **First 16 bytes**: Mach-O magic (0xFEEDFACF) - binary
- **Next 8 bytes**: String "Hello" - text
- **Split View**: Left shows exact bytes, right shows text interpretation
- **Learning**: Understand file format structure

---

## Example 7: Adjusting Bytes Per Line

### Same Data, Different Line Widths

#### 32 Bytes Per Line (Compact)
```
0x100008000: | Hello, ARM64 World! This is
0x100008020: | a test of different line wi
0x100008040: | dths in the text view mode.
```

#### 64 Bytes Per Line (Default)
```
0x100008000: | Hello, ARM64 World! This is a test of different line width
0x100008040: | s in the text view mode.
```

#### 128 Bytes Per Line (Wide)
```
0x100008000: | Hello, ARM64 World! This is a test of different line widths in the text view mode.
```

### Use Cases
- **32**: Mobile/small screens, dense data
- **64**: General use, good balance
- **80**: Traditional terminal width
- **128**: Large monitors, sparse data

---

## Example 8: Stack Trace with Addresses

### Stack Frame
```
Function: main() at 0x100003f80
Called from: _start() at 0x100003fa0
```

### Hex Dump View
```
Address      | Hex Bytes                                        | ASCII
0x16fdff000: | 10 f0 df 6f 01 00 00 00  a0 3f 00 00 01 00 00 00 | ...o.....?......
               ↑                          ↑
          Saved FP: 0x16fdff010      Saved LR: 0x100003fa0
```

### Analysis in Context
```
Saved Frame Pointer:  0x000000016fdff010  (points to caller's frame)
Saved Link Register:  0x0000000100003fa0  (return address in _start)
```

### Best Choice
- **Hex Dump**: See exact 64-bit values
- **Need to**: Parse 8 bytes as little-endian UInt64

---

## Summary: Which View When?

| Scenario | Best View | Why |
|----------|-----------|-----|
| String literals | Text View | Natural reading, search |
| Binary data | Hex Dump | Byte-level precision |
| Mixed data | Split View | Compare both formats |
| Machine code | Hex Dump | Instruction bytes |
| Error messages | Text View | Search and locate |
| File formats | Split View | Understand structure |
| Stack frames | Hex Dump | 64-bit addresses |
| ASCII art | Text View | Visual patterns |
| Debugging encoding | Split View | See byte→char mapping |

## Tips from Examples

1. **Use Search**: Quickly find strings across memory
2. **Toggle Non-Printable**: Clean vs. detailed view
3. **Adjust Line Width**: Match your screen and data density
4. **Try Split View**: When unsure, see both representations
5. **Check Addresses**: Know which segment you're viewing
6. **Look for Patterns**: NULL bytes often mark boundaries

## Integration Tips

### For Your ARM64 Debugger

1. **Default Views per Segment**:
   - STACK → Hex Dump (binary addresses)
   - HEAP → Split View (mixed data)
   - __DATA → Text View (strings)
   - __TEXT → Hex Dump (machine code)

2. **Tab Organization**:
   ```
   [Stack] [Heap] [Data] [Text] [Search]
      ↓       ↓      ↓      ↓       ↓
    Hex    Split   Text   Hex   Text+Search
   ```

3. **Keyboard Shortcuts**:
   - ⌘F: Focus search in current view
   - ⌘T: Toggle text/hex for current segment
   - ⌘S: Switch to split view

These examples demonstrate real-world usage patterns and help users choose the right view for their debugging task!
