# CLAUDE.md

## Project Overview

**ARM64Learn** is a macOS SwiftUI application that provides an interactive IDE-like environment for learning ARM64 assembly language. Users read structured tutorials, write/edit code in a live editor, compile and run it, debug with LLDB, and visualize memory layout — all within a single app.

## Build & Run

```bash
open ARM64Learn.xcodeproj
```

Select the **ARM64Learn** scheme, choose **My Mac** as the destination, and press **⌘R**.

**Requirements:**
- macOS 13+ (Ventura or later)
- Xcode 15+
- Xcode Command Line Tools (for `clang` and `lldb` via `xcrun`)

There is no Swift Package Manager; this is a pure Xcode project.

## File Organization

**All source files live in subdirectories under `ARM64Learn/`** (relative to the project root where `ARM64Learn.xcodeproj` is located). When creating new Swift files, they must be placed in the appropriate subdirectory following the project structure documented in `docs/IMPLEMENTATION.md`.

The Xcode project uses `PBXFileSystemSynchronizedRootGroup`, which means files are auto-discovered in the directory tree. **New files must be created in their proper location** — do not create files at the project root.

### Source File Locations

From the project root (where `ARM64Learn.xcodeproj` lives):

- **App entry point**: `ARM64Learn/App/`
- **View models**: `ARM64Learn/ViewModels/`
- **Data models**: `ARM64Learn/Models/`
- **Views**: `ARM64Learn/Views/` (with subdirectories: `Workspace/`, `Registers/`, `BottomPanel/`)
- **Services**: `ARM64Learn/Services/`
- **Resources**: `ARM64Learn/Resources/`

### Important: AI File Path Limitations

**Critical limitation**: The AI assistant accesses files using simplified paths (e.g., `/repo/ConsoleOutputView.swift`) but **cannot see or specify the actual directory structure** (`ARM64Learn/Views/BottomPanel/ConsoleOutputView.swift`).

This means:
- When the AI modifies `/repo/ConsoleOutputView.swift`, it's actually modifying `ARM64Learn/Views/BottomPanel/ConsoleOutputView.swift`
- The AI cannot create new files in specific subdirectories — it can only create files at `/repo/` root with mangled names
- The AI cannot reliably tell you where a file is actually located in your project structure

**For file location questions**: Always refer to `docs/IMPLEMENTATION.md` for the authoritative directory structure. The AI's path references are unreliable for determining actual file locations.

**When the AI creates new files**: They will likely be created at the project root with incorrect names. You must manually move them to the correct location as documented in `docs/IMPLEMENTATION.md`.

## Documentation Rules

All documentation lives in one of the following places. Follow these rules exactly — do not create other documentation files and do not put content in the wrong file.

| File | Purpose |
|------|---------|
| `README.md` | **User guide only.** Features, requirements, getting started, keyboard shortcuts, workflow, tutorial list. No implementation details, no architecture, no file paths. |
| `docs/DESIGN.md` | Current design and high-level program structure for reference. Covers layout, panels, state ownership, data flow, and how major subsystems fit together. Updated whenever the design changes. |
| `docs/IMPLEMENTATION.md` | Implementation details for the design. Covers specific classes, methods, data structures, algorithms, and how things are wired together in code. Updated whenever implementation changes. |
| `docs/REFERENCE.md` | External references gathered for the implementation (ARM64 ABI docs, Apple APIs, LLDB docs, relevant articles, etc.). |
| `docs/CHANGELOG.md` | Running list of changes, newest first. One entry per logical change set (PR / feature / fix). |

**When making code changes, always update the relevant docs files** — at minimum `docs/CHANGELOG.md`, and any of `docs/DESIGN.md` / `docs/IMPLEMENTATION.md` whose content is affected by the change.

## Conventions

- **SwiftUI**: All views use `@EnvironmentObject var appState: AppState`
- **Async/await**: Compilation and LLDB commands are async; UI updates happen on `@MainActor`
- **No external dependencies**: No SPM packages; uses only Apple frameworks
- **Target**: macOS only (not iOS/iPadOS)

## Formatting Memory Addresses

**Always use `%016llX` (or `%llX`) when formatting `UInt64` memory addresses with `String(format:)`.**

`%x` and `%X` are 32-bit format specifiers. Passing a `UInt64` to `%x` silently truncates the value to its lower 32 bits, producing wrong output with no compiler warning. For ARM64 macOS addresses like `0x100003f58`, the lower 32 bits are `0x00003f58` — completely wrong.

```swift
// WRONG — truncates UInt64 to lower 32 bits
String(format: "0x%09x", address)   // 0x100003f58 → "0x000003f58"

// CORRECT
String(format: "%016llX", address)  // 0x100003f58 → "0000000100003f58"
```

Convention in this codebase: display addresses as **16 uppercase hex digits, no `0x` prefix** — consistent with `MemoryHexDumpView` and `HexDumpComponents`.

## Adding Tutorials

1. Create a new `.md` file in `ARM64Learn/Resources/Tutorials/` following the `NN_slug.md` naming convention.
2. Add the file to the Xcode project under the `Resources/Tutorials` group so it is bundled.
3. Follow the existing frontmatter/format conventions used by `TutorialLoader`.

## See Also

- `docs/DESIGN.md` — high-level design and structure
- `docs/IMPLEMENTATION.md` — implementation details
- `docs/REFERENCE.md` — external references
- `docs/CHANGELOG.md` — history of changes
