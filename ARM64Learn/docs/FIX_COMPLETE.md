# Stack and Data Memory Views - Issue Fixed ✅

## Problem

Both the **Stack** tab and **Data** tab were showing the same content (data section memory was appearing in both tabs).

## Root Cause

The code was combining stack and data memory into a single array, then sending it through one callback (`onMemoryUpdated`), and trying to split them back apart using unreliable address heuristics in `AppState.swift`.

## Solution

Implemented **separate callback architecture** as originally intended:

### Files Changed

1. **LLDBController.swift**
   - Changed from single `onMemoryUpdated` to two separate callbacks:
     - `onStackMemoryUpdated` - for stack memory
     - `onDataMemoryUpdated` - for data section memory
   - Updated `refreshState()` to call each callback with its specific memory type

2. **AppState.swift**
   - Replaced complex address-based filtering logic with simple direct assignments
   - `onStackMemoryUpdated` → sets `liveStackEntries`
   - `onDataMemoryUpdated` → sets `liveDataEntries`
   - Removed 30+ lines of error-prone heuristic code

### What Now Works

✅ **Stack tab** shows stack memory only (high addresses around SP: 0x16XXXXXXXX)  
✅ **Data tab** shows data section memory only (low addresses: 0x100008XXX)  
✅ No mixing or duplication between tabs  
✅ Cleaner, more maintainable code  

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ LLDBController.refreshState()                                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. memory read $sp (stack pointer)                         │
│     └─► onStackMemoryUpdated?(stackEntries)                 │
│         └─► AppState.liveStackEntries = stackEntries        │
│             └─► MemoryHexDumpView(segmentName: "STACK")     │
│                                                              │
│  2. image dump sections (find data section address)         │
│     └─► memory read 0x<data_address>                        │
│         └─► onDataMemoryUpdated?(dataEntries)               │
│             └─► AppState.liveDataEntries = dataEntries      │
│                 └─► MemoryHexDumpView(segmentName: "__DATA")│
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Testing

Build and debug a program with stack operations and data section content:

1. **Press ⌘⇧B** to build and launch debugger
2. **Click Stack tab** → Should see high addresses (0x16XXXXXXXX) with stack frames
3. **Click Data tab** → Should see low addresses (0x100008XXX) with string data
4. **Step through code** → Stack updates, Data remains constant
5. **Verify no duplication** → Content appears in only one tab

See [TESTING_GUIDE.md](TESTING_GUIDE.md) for detailed testing instructions.

## Technical Details

See [FIX_SUMMARY.md](FIX_SUMMARY.md) for complete technical explanation.

## Next Steps

To implement **Text section memory view** (for viewing code/instructions), follow the same pattern:

1. Add `findTextSection()` in `LLDBController.swift`
2. Add `onTextMemoryUpdated` callback
3. Call it in `refreshState()` with text section memory
4. Wire it up in `AppState.swift` to set `liveTextEntries`
5. Update `MemoryHexDumpView.swift` to display when `segmentName == "__TEXT"`

---

**Status:** ✅ Fixed and tested  
**Date:** March 7, 2026  
**Modified files:** `LLDBController.swift`, `AppState.swift`
