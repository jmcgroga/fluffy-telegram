# CLAUDE.md

## Project Overview

**ARM64Learn** is a macOS SwiftUI application that provides an interactive IDE-like environment for learning ARM64 assembly language. Users read structured tutorials, write/edit code in a live editor, compile and run it, debug with LLDB, and visualize memory layout — all within a single app.

## Repository Structure

```
arm64-tutorial-ide/
├── ARM64Learn/
│   ├── ARM64Learn.xcodeproj/   # Xcode project file
│   ├── ARM64Learn/             # Main app target
│   │   ├── ARM64LearnApp.swift # App entry point
│   │   ├── AppState.swift      # Central @MainActor ObservableObject (state + actions)
│   │   └── ContentView.swift   # Root NavigationSplitView
│   ├── Models/
│   │   ├── Tutorial.swift      # Tutorial, TutorialCategory, Difficulty models
│   │   └── MemoryState.swift   # Memory segment visualization model
│   ├── Views/
│   │   ├── MainWorkspaceView.swift   # Three-panel HSplitView + toolbar
│   │   ├── SidebarView.swift         # Tutorial list/navigation
│   │   ├── TutorialContentView.swift # Markdown-rendered tutorial panel
│   │   ├── CodeEditorView.swift      # Editable code panel with syntax highlighting
│   │   ├── MemoryLayoutView.swift    # Memory segment visualization
│   │   └── BottomPanelView.swift     # Build Output / Terminal / LLDB panel
│   ├── Services/
│   │   ├── ProcessRunner.swift    # clang compilation, binary execution, LLDBSession, TerminalSession
│   │   ├── TutorialLoader.swift   # Loads .md tutorials from bundle Resources/Tutorials/
│   │   └── SyntaxHighlighter.swift # ARM64/C syntax highlighting (NSAttributedString)
│   └── Resources/
│       └── Tutorials/             # 10 Markdown tutorial files (01–10)
├── ARM64LearnTests/
├── ARM64LearnUITests/
└── README.md
```

## Build & Run

Open in Xcode:
```
open ARM64Learn/ARM64Learn.xcodeproj
```

Select the **ARM64Learn** scheme, choose **My Mac** as the destination, and press **⌘R**.

**Requirements:**
- macOS 13+ (Ventura or later)
- Xcode 15+
- Xcode Command Line Tools (for `clang` and `lldb` via `xcrun`)

There is no Swift Package Manager; this is a pure Xcode project.

## Architecture

### State Management
`AppState` (`ARM64Learn/AppState.swift`) is the single source of truth, passed via `@EnvironmentObject`. It owns:
- Selected tutorial and tutorial categories
- Current code string and language (`.arm64` / `.c`)
- Bottom panel visibility, height, and active tab
- Build output, LLDB session and output, terminal session and output
- `compileCode()` and `compileAndDebug()` async methods

### Compilation Pipeline (`ProcessRunner`)
- Writes user code to a temp file in `NSTemporaryDirectory()/ARM64Learn/`
- Invokes `clang -arch arm64` (located via `xcrun --find clang`)
- Streams combined stdout+stderr back to the UI
- `LLDBSession`: spawns `lldb <binary>` as a subprocess; stdin/stdout pipes enable interactive commands
- `TerminalSession`: spawns the user's login shell (`$SHELL -l`)

### Tutorial System
- `TutorialLoader` reads `.md` files from the app bundle at `Resources/Tutorials/`
- Files are prefixed `01_`–`10_` and parsed into `TutorialCategory`/`Tutorial` model objects
- Each tutorial can specify a `language`, `sampleCode`, and `memoryHighlights` (via frontmatter or conventions in the loader)

### Keyboard Shortcuts
- `⌘B` — Build & Run
- `⌘⇧B` — Build with debug symbols and launch LLDB

## Conventions

- **SwiftUI**: All views use `@EnvironmentObject var appState: AppState`
- **Async/await**: Compilation is async; UI updates happen on `@MainActor`
- **No external dependencies**: No SPM packages; uses only Apple frameworks
- **Target**: macOS only (not iOS/iPadOS)
- **Language picker**: Segmented control in the toolbar switches between ARM64 and C modes

## Adding Tutorials

1. Create a new `.md` file in `ARM64Learn/Resources/Tutorials/` following the `NN_slug.md` naming convention.
2. Add the file to the Xcode project under the `Resources/Tutorials` group so it is bundled.
3. Follow the existing frontmatter/format conventions used by `TutorialLoader`.
