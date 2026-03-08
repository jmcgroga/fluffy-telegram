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

## Adding Tutorials

1. Create a new `.md` file in `ARM64Learn/Resources/Tutorials/` following the `NN_slug.md` naming convention.
2. Add the file to the Xcode project under the `Resources/Tutorials` group so it is bundled.
3. Follow the existing frontmatter/format conventions used by `TutorialLoader`.

## See Also

- `docs/DESIGN.md` — high-level design and structure
- `docs/IMPLEMENTATION.md` — implementation details
- `docs/REFERENCE.md` — external references
- `docs/CHANGELOG.md` — history of changes
