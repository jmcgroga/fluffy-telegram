# Design

## Overview

ARM64Learn is a multi-window macOS application built with SwiftUI. The main window contains a multi-panel workspace for reading tutorials, writing code, and inspecting registers and memory. A separate output window displays build output, terminal, and LLDB console. The debugger control bar is integrated into the code editor header.

## Layout

### Main Window

The main window is a `NavigationSplitView` wrapping a `MainWorkspaceView`. The content area uses `VSplitView` and `HSplitView` containers. The tutorial content panel can be toggled via toolbar.

```
┌─ Toolbar ─────────────────────────────────────────────────────────────────┐
├───────────────────────────────────────────────────────────────────────────┤
│ TOP HALF (outer VSplitView)                                               │
│ ┌──────────────┬───────────────────────┬──────────────────────┐           │
│ │              │                       │  __DATA / __TEXT      │           │
│ │  Tutorial    │  Code Editor          │  (SegmentPanel)       │           │
│ │  Content     │  [header has debugger │                       │           │
│ │              │   control buttons]    │                       │           │
│ └──────────────┴───────────────────────┴──────────────────────┘           │
├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ (draggable divider) ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
│ BOTTOM HALF                                                               │
│ ┌───────────────────────────────────────────────────────────┐             │
│ │  Registers  │  Stack  │  Heap                              │             │
│ │  (MemoryStrip — full width)                                │             │
│ └───────────────────────────────────────────────────────────┘             │
└───────────────────────────────────────────────────────────────────────────┘
```

### Output Window (separate)

```
┌─ Output ──────────────────────────────────────────┐
│ ┌──────────────────────────────────────────────┐  │
│ │ [Build Output] [Terminal] [LLDB]  ← tab bar  │  │
│ ├──────────────────────────────────────────────┤  │
│ │                                              │  │
│ │  Console content for selected tab            │  │
│ │                                              │  │
│ └──────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────┘
```

The output window opens automatically on build or debug. It can also be opened manually via the toolbar button (`⌘⌥2`).

The tutorial list (sidebar) is controlled by a `NavigationSplitView` toggle. The tutorial content panel can be shown/hidden via a toolbar button or keyboard shortcut (`⌘⌥1`).

## Panels

### Tutorial List (Sidebar)
Displays the 10 tutorials grouped into `TutorialCategory` sections. Selecting a tutorial loads its Markdown content and sample code.

### Tutorial Content Panel (Top-Left)
Renders the selected tutorial's Markdown file. Read-only. Togglable via toolbar.

### Code Editor (Top, Center)
`NSTextView`-based editor with a custom line-number gutter drawn by `LineNumberTextView`. Supports ARM64 assembly (`.s`) and C (`.c`) modes. The header bar contains the language label, debugger control buttons (Run/Pause/Stop/Step), and quick action buttons. The gutter displays:
- Line numbers
- A green `▶` execution arrow on the current LLDB stop line
- A red `●` breakpoint dot for lines in `activeBreakpoints`; clicking a gutter line toggles a breakpoint

### Segment Panel (Top, Right)
A `VSplitView` containing two views stacked vertically:
- **Top**: `MemoryHexDumpView(__DATA)` — live data segment hex dump from LLDB
- **Bottom**: `DisassemblyView` — decoded ARM64 instructions for `_main`, with source-line markers and current-PC highlighting

### Output Window (Separate Window)
A separate macOS window (`Window` scene with id `"output-window"`) displaying the tabbed console. Opens automatically on build or debug actions. Contains a tab bar with three tabs:

| Tab | Content |
|-----|---------|
| Build Output | Compiler stdout/stderr and program output |
| LLDB | Raw LLDB console with command/stdin input |
| Terminal | Embedded login-shell terminal |

### Memory Strip (Bottom, Full Width)
An `HSplitView` spanning the full window width, displaying three views simultaneously side-by-side:
- **Registers**: Scrollable list of ARM64 registers grouped by category (General, Special, Flags) with collapsible sections. The `nzcv` register renders N/Z/C/V as colored badge indicators.
- **Stack**: Live stack hex dump (LLDB `memory read $sp` during debug)
- **Heap**: Heap hex dump

## State Ownership

`AppState` is the single `@MainActor ObservableObject` source of truth. It is created as a `@StateObject` in `ARM64LearnApp` (the `App` struct) and injected via `.environmentObject()` into both the main `WindowGroup` and the output `Window` scene, enabling shared state across windows. All views read it via `@EnvironmentObject`. It owns:

- Tutorial selection and categories
- Current code string and language
- Tutorial panel visibility flag and active console tab
- Build output, LLDB output, terminal output
- Debugger execution state: current line, last changed registers, register change summary, live stack entries, active breakpoints
- References to `LLDBSession`, `LLDBController`, and `TerminalSession`

## Data Flow

```
User edits code
    → AppState.currentCode (Binding)

User clicks Build & Run (⌘B)
    → AppState.compileCode()
    → ProcessRunner.compile() [async, background]
    → AppState.buildOutput (streamed)

User clicks Debug
    → AppState.compileAndDebug()
    → ProcessRunner.compileWithDebugSymbols() [async]
    → LLDBSession.start() — spawns lldb subprocess
    → LLDBController.attach(to:) — wires output handler
    → LLDBController.launchAndBreakAtMain()
    → LLDBController fires callbacks → AppState updates published state
    → Views re-render

User clicks a step button
    → AppState.stepOver() / stepInstruction() / …
    → LLDBController issues LLDB command
    → LLDBController.refreshState() [after stop]:
        1. register read  → onRegistersUpdated → AppState.applyRegisterUpdate()
        2. bt 1           → onFrameUpdated     → AppState.applyFrameUpdate()
        3. memory read $sp → onMemoryUpdated   → AppState.liveStackEntries

User clicks gutter line
    → LineNumberTextView.mouseDown → onBreakpointToggle
    → AppState.toggleBreakpoint(line:) → LLDBController.sendRawCommand()
```

## Subsystems

### Compilation (`ProcessRunner`)
Handles both Build & Run and Build & Debug. Locates `clang` via `xcrun`, writes source to a temp directory, and collects combined stdout/stderr.

### LLDB Integration (`LLDBController` + `LLDBSession`)
`LLDBSession` owns the LLDB subprocess and its stdin/stdout pipes. `LLDBController` is a prompt-delimited command/response correlator sitting on top of `LLDBSession`. After each step it automatically refreshes registers, the current frame, and stack memory.

### Tutorial Loading (`TutorialLoader`)
Reads Markdown files from the app bundle at `ARM64Learn/Resources/Tutorials/` and parses them into `TutorialCategory` / `Tutorial` model objects.

### Syntax Highlighting (`SyntaxHighlighter`)
`SyntaxHighlightingStorage` is an `NSTextStorage` subclass that re-highlights on every edit. Supports ARM64 assembly and C keywords. Also maintains the execution-line background highlight so it survives re-highlighting passes.

## Repository Layout

```
(repo root)/
├── ARM64Learn.xcodeproj/    # Xcode project at root; single sync group covers ARM64Learn/
├── ARM64Learn/              # Main app target (one PBXFileSystemSynchronizedRootGroup)
│   ├── App/                 # @main entry point and root view
│   ├── ViewModels/          # AppState (ObservableObject, @MainActor)
│   ├── Models/              # Data models (Tutorial, MemoryState, Register)
│   ├── Views/               # SwiftUI views, grouped by area
│   │   ├── Workspace/
│   │   ├── Registers/
│   │   └── BottomPanel/
│   ├── Services/            # Compilation, LLDB, terminal, syntax highlighting
│   └── Resources/           # Assets.xcassets + Tutorials/
├── ARM64LearnTests/
├── ARM64LearnUITests/
├── .github/                 # CI workflows, issue/PR templates, CODEOWNERS
├── docs/                    # DESIGN, IMPLEMENTATION, REFERENCE, CHANGELOG
├── .gitignore
├── .editorconfig
├── CLAUDE.md
└── README.md
```
