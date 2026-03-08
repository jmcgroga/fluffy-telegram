# Fix Summary: Separate Stack and Data Memory Callbacks

## Problem Identified

Both the Stack and Data memory tabs were showing the same content (Data section memory was appearing in both tabs).

## Root Cause

The previous implementation had a **mismatch between intention and execution**:

1. **LLDBController.swift** was combining both stack and data section memory into a single array and calling a single `onMemoryUpdated` callback
2. **AppState.swift** was then trying to split them back apart using address range heuristics
3. This heuristic-based splitting was error-prone and caused both memory types to end up in the wrong tabs

### The Bug Location

In `LLDBController.swift` (lines 328-345), the code was doing:
```swift
let stackEntries = LLDBOutputParser.parseMemoryRead(from: memOut)

// 5. Data section contents
var allMemoryEntries = stackEntries  // ❌ Combining them
if let dataSection = await findDataSection(), dataSection.size > 0 {
    let dataEntries = LLDBOutputParser.parseMemoryRead(from: dataMemOut)
    allMemoryEntries.append(contentsOf: dataEntries)  // ❌ Still combining
}

if !allMemoryEntries.isEmpty {
    await MainActor.run {
        self.onMemoryUpdated?(allMemoryEntries)  // ❌ Single callback with mixed data
    }
}
```

Then in `AppState.swift`, it tried to split them using address ranges, which wasn't working correctly.

## Solution Implemented

Implemented the **separate callbacks architecture** as originally intended in the conversation summary:

### 1. LLDBController.swift Changes

**Changed callbacks from:**
```swift
var onMemoryUpdated: (( [(address: UInt64, value: UInt64)] ) -> Void)?
```

**To separate callbacks:**
```swift
var onStackMemoryUpdated: (( [(address: UInt64, value: UInt64)] ) -> Void)?
var onDataMemoryUpdated: (( [(address: UInt64, value: UInt64)] ) -> Void)?
```

**Updated `refreshState()` method to call them separately:**
```swift
// 4. Live stack contents (16 quadwords starting at $sp)
let memOut = await sendAndAwait("memory read --format uint8_t[] --size 8 --count 16 $sp")
let stackEntries = LLDBOutputParser.parseMemoryRead(from: memOut)

if !stackEntries.isEmpty {
    await MainActor.run {
        self.onStackMemoryUpdated?(stackEntries)  // ✅ Separate callback
    }
}

// 5. Data section contents (find dynamically and read)
if let dataSection = await findDataSection(), dataSection.size > 0 {
    let count = (dataSection.size + 7) / 8
    let dataMemOut = await sendAndAwait("memory read --format uint8_t[] --size 8 --count \(count) 0x\(String(dataSection.address, radix: 16))")
    let dataEntries = LLDBOutputParser.parseMemoryRead(from: dataMemOut)
    
    if !dataEntries.isEmpty {
        await MainActor.run {
            self.onDataMemoryUpdated?(dataEntries)  // ✅ Separate callback
        }
    }
}
```

### 2. AppState.swift Changes

**Replaced the complex `onMemoryUpdated` callback with simple, direct assignments:**

```swift
controller.onStackMemoryUpdated = { [weak self] entries in
    self?.liveStackEntries = entries  // ✅ Stack goes to stack
}
controller.onDataMemoryUpdated = { [weak self] entries in
    self?.liveDataEntries = entries  // ✅ Data goes to data
}
```

**Removed all the error-prone address range heuristics** (30+ lines of code deleted).

## Benefits of This Approach

1. ✅ **Clear separation of concerns** - Stack memory and data memory are handled independently
2. ✅ **No address heuristics needed** - We know which is which based on the LLDB command that fetched it
3. ✅ **More reliable** - No risk of misclassifying memory based on address ranges
4. ✅ **Simpler code** - Removed complex filtering logic
5. ✅ **Easier to extend** - Adding text section memory will follow the same pattern

## Current State

- ✅ Stack tab shows stack memory (from `memory read $sp`)
- ✅ Data tab shows data section memory (from `memory read 0x<data_address>`)
- ✅ Each memory type has its own dedicated callback pipeline
- ✅ No mixing or misclassification of memory contents

## Architecture Pattern

This follows the **command-response correlation** pattern:
- Each LLDB command (`memory read $sp`, `memory read 0x100008000`) has a clear purpose
- Each response is routed through a dedicated callback
- No need to "guess" what type of memory we received based on addresses

## Next Steps

To implement **Text section memory view**, follow the same pattern:
1. Add `findTextSection()` method in `LLDBController.swift`
2. Add `onTextMemoryUpdated` callback
3. Read text section in `refreshState()` and call the callback
4. Wire it up in `AppState.swift` to set `liveTextEntries`
5. Update `MemoryHexDumpView.swift` to display text entries when `segmentName == "__TEXT"`
