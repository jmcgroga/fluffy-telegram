# Testing Guide: Stack and Data Memory Views

## What Was Fixed

The Stack and Data tabs were both showing Data section content. They now correctly show their respective memory contents.

## How to Test

### 1. Build and Debug a Program

Use this sample ARM64 assembly code that has both stack operations and data section content:

```assembly
.global _main
.align  2
.text

_main:
    // Prologue: save frame pointer and link register
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // Load address of message string and print it
    adrp    x0, hello_msg@PAGE
    add     x0, x0, hello_msg@PAGEOFF
    bl      _puts

    // Return 0 (success)
    mov     x0, #0

    // Epilogue: restore frame pointer and link register
    ldp     x29, x30, [sp], #16
    ret

.data
hello_msg:
    .asciz  "Hello, ARM64 World!"
```

### 2. Launch Debugger

1. Press **⌘⇧B** to build with debug symbols and launch LLDB
2. The debugger should stop at `_main`

### 3. Check Stack Tab

1. Click on the **Stack** tab in the bottom panel
2. You should see:
   - **High addresses** (0x16XXXXXXXX range)
   - **Saved frame pointer** and **link register** values
   - **Stack pointer** contents
   - Example addresses: `0x16fdff000`, `0x16fdff008`, etc.

**Expected content:**
```
Live stack — 16 quadwords
0x16fdff000: 10 f0 df 6f 01 00 00 00  (saved FP)
0x16fdff008: 80 3f 00 00 01 00 00 00  (saved LR)
0x16fdff010: 00 00 00 00 00 00 00 00  (local data)
...
```

### 4. Check Data Tab

1. Click on the **Data** tab in the bottom panel
2. You should see:
   - **Low addresses** (0x100008XXX range)
   - **String data**: "Hello, ARM64 World!"
   - **ASCII representation** on the right showing readable text
   - Example addresses: `0x100008000`, `0x100008008`, etc.

**Expected content:**
```
Live data section — 3 quadwords
0x100008000: 48 65 6c 6c 6f 2c 20 41  Hello, A
0x100008008: 52 4d 36 34 20 57 6f 72  RM64 Wor
0x100008010: 6c 64 21 00 00 00 00 00  ld!.....
```

### 5. Step Through and Verify Updates

1. Press **stepi** button or **⌘;** to step one instruction
2. Switch between **Stack** and **Data** tabs
3. Verify:
   - **Stack tab** updates when stack changes (e.g., during prologue/epilogue)
   - **Data tab** remains constant (data section doesn't change during execution)
   - Content **does NOT appear in both tabs**

## What Each Tab Should Show

| Tab | Content | Address Range | Updates During Execution |
|-----|---------|---------------|-------------------------|
| **Stack** | Stack frames, saved registers, local variables | 0x16XXXXXXXX | Yes - changes with push/pop/function calls |
| **Data** | Global variables, string literals, static data | 0x100008XXX | No - fixed at load time |
| **Heap** | Empty (not yet implemented) | N/A | N/A |
| **Text** | Empty (not yet implemented) | N/A | N/A |

## Common Issues (Now Fixed)

❌ **Before fix:** Both Stack and Data tabs showed the same data section content  
✅ **After fix:** Each tab shows its own memory region

❌ **Before fix:** Address heuristics in `AppState.swift` incorrectly classified memory  
✅ **After fix:** Separate callbacks ensure correct routing

## Technical Details

### Data Flow (Fixed)

```
LLDBController.refreshState()
  ├─ memory read $sp → Stack entries
  │   └─ onStackMemoryUpdated?(stackEntries)
  │       └─ AppState.liveStackEntries = stackEntries
  │           └─ MemoryHexDumpView(segmentName: "STACK") displays them
  │
  └─ memory read 0x<data_addr> → Data entries
      └─ onDataMemoryUpdated?(dataEntries)
          └─ AppState.liveDataEntries = dataEntries
              └─ MemoryHexDumpView(segmentName: "__DATA") displays them
```

### Key Points

1. **Separate LLDB commands** for each memory type
2. **Separate callbacks** to route memory to the right destination
3. **No address heuristics** needed - we know the source from the command
4. **Clean separation** between stack and data pipelines

## If Something Goes Wrong

### Stack tab is empty
- Check that SP (stack pointer) register is non-zero
- Verify debugger is paused (not running)
- Check LLDB output for `memory read $sp` command

### Data tab is empty
- Check that the program has a `.data` section with content
- Verify `image dump sections` finds `__DATA.__data`
- Check LLDB output for `memory read 0x<address>` command

### Both tabs show the same thing
- This should no longer happen with the fix
- If it does, check that `onStackMemoryUpdated` and `onDataMemoryUpdated` are both wired up in `AppState.swift`
