# Memory View Fix - What's Actually Broken

## Root Cause

The memory views aren't working because there's a mismatch between:
1. **What data AppState actually populates** (quadword entries)
2. **What data the views are checking for** (byte arrays that are never populated)

## What AppState Actually Populates

Looking at `AppState.swift` line 238-265, the `onMemoryUpdated` callback populates:

```swift
@Published var liveStackEntries: [(address: UInt64, value: UInt64)] = []
@Published var liveDataEntries: [(address: UInt64, value: UInt64)] = []
@Published var liveTextEntries: [(address: UInt64, value: UInt64)] = []
```

These are populated from LLDB's memory read output.

## What AppState Declares But NEVER Populates

These are declared but NEVER assigned any data:

```swift
@Published var liveHeapData: [UInt8] = []              // ❌ NEVER POPULATED
@Published var liveDataSegmentData: [UInt8] = []      // ❌ NEVER POPULATED  
@Published var liveTextSegmentData: [UInt8] = []      // ❌ NEVER POPULATED
```

## The Bug in MemoryHexDumpView

The view was checking for the byte arrays that are never populated:

```swift
// THIS NEVER SHOWS ANYTHING - liveDataSegmentData is always empty!
else if segmentName == "__DATA", !appState.liveDataSegmentData.isEmpty {
    LiveMemoryDumpContent(
        data: appState.liveDataSegmentData,  // Always empty!
        ...
    )
}
```

And there was a **duplicate check** for `__DATA`:
- Line 25: Check `liveDataEntries` (works)
- Line 34: Check `liveDataSegmentData` (never reached, always empty)

## The Fix

**Option 1: Use Only Quadword Data (Simplest)**

Remove checks for unused byte arrays. Use only the quadword entries that are actually populated:

- ✅ STACK → `liveStackEntries` 
- ✅ __DATA → `liveDataEntries`
- ✅ __TEXT → `liveTextEntries`
- ❌ HEAP → Not implemented in LLDB controller

**Option 2: Convert Data Properly (More Work)**

If you want to use byte arrays, convert the quadword entries to bytes in the view or in AppState.

## What I've Already Fixed

✅ Removed duplicate `__DATA` check from `MemoryHexDumpView.swift`
✅ Removed duplicate component definitions

## What Still Needs Fixing

The views should either:
1. Remove checks for `liveDataSegmentData`, `liveHeapData`, `liveTextSegmentData` (they're never populated)
2. OR convert quadword entries to byte arrays where needed

## Current State

After my fixes:
- ✅ STACK view works (uses `liveStackEntries`)
- ✅ DATA view works (uses `liveDataEntries`)  
- ❓ TEXT view may not work (checks `liveTextSegmentData` which is empty)
- ❓ HEAP view won't work (checks `liveHeapData` which is never populated)

## Recommended Fix

Simply remove the checks for unused data sources and rely on what's actually populated by LLDBController.
