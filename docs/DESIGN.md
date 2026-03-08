# Design

## Overview

ARM64Learn is a single-window macOS application built with SwiftUI. The window contains a multi-panel workspace that lets a user read a tutorial, write and compile code, step through it in a debugger, and inspect registers and memory — without switching applications.

## Layout

The window is a `NavigationSplitView` wrapping a `MainWorkspaceView`. The main content area uses nested `VSplitView` and `HSplitView` containers. The tutorial content panel can be toggled via toolbar.

```
┌─ Toolbar ─────────────────────────────────────────────────────────────────┐
├───────────────────────────────────────────────────────────────────────────┤
│ TOP HALF (outer VSplitView)                                               │
│ ┌──────────────┬────────────────────────────────────────────┐             │
│ │              │  ┌───────────────┬────────────────────────┐│             │
│ │  Tutorial    │  │               │  __DATA / __TEXT        ││             │
│ │  Content     │  │  Code Editor  │  (SegmentPanel)         ││             │
│ │              │  │               │                         ││             │
│ │              │  ├───────────────┴────────────────────────┤│             │
│ │              │  │ Tabbed Console (Build / Term / LLDB)    ││             │
│ │              │  │ [spans editor + segment panel]          ││             │
│ │              │  └────────────────────────────────────────┘│             │
│ └──────────────┴────────────────────────────────────────────┘             │
├ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ (draggable divider) ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤
│ BOTTOM HALF                                                               │
│ ┌───────────────────────────────────────────────────────────┐             │
│ │  Registers  │  Stack  │  Heap                              │             │
│ │  (MemoryStrip — full width)                                │             │
│ └───────────────────────────────────────────────────────────┘             │
└───────────────────────────────────────────────────────────────────────────┘
```

The tutorial list (sidebar) is controlled by a `NavigationSplitView` toggle. The tutorial content panel can be shown/hidden via a toolbar button or keyboard shortcut (`⌘⌥1`).

## Panels

### Tutorial List (Sidebar)
Displays the 10 tutorials grouped into `TutorialCategory` sections. Selecting a tutorial loads its Markdown content and sample code.

### Tutorial Content Panel (Top-Left)
Renders the selected tutorial's Markdown file. Read-only. Togglable via toolbar.

### Code Editor (Top, Center-Left)
`NSTextView`-based editor with a custom line-number gutter drawn by `LineNumberTextView`. Supports ARM64 assembly (`.s`) and C (`.c`) modes. The gutter displays:
- Line numbers
- A green `▶` execution arrow on the current LLDB stop line
- A red `●` breakpoint dot for lines in `activeBreakpoints`; clicking a gutter line toggles a breakpoint

### Segment Panel (Top, Center-Right)
A `VSplitView` containing two `MemoryHexDumpView` instances stacked vertically:
- **Top**: `__DATA` hex dump — live data segment contents from LLDB
- **Bottom**: `__TEXT` hex dump — live text (code) segment contents from LLDB

### Tabbed Console (Below Editor + Segment Panel)
Spans the full width of the editor and segment panel area. A tab bar with three tabs:

| Tab | Content |
|-----|---------|
| Build Output | Compiler stdout/stderr and program output |
| LLDB | Debugger control bar, raw LLDB console, command/stdin input |
| Terminal | Embedded login-shell terminal |

### Memory Strip (Bottom, Full Width)
An `HSplitView` spanning the full window width, displaying three views simultaneously side-by-side:
- **Registers**: Scrollable list of ARM64 registers grouped by category (General, Special, Flags) with collapsible sections. The `nzcv` register renders N/Z/C/V as colored badge indicators.
- **Stack**: Live stack hex dump (LLDB `memory read $sp` during debug)
- **Heap**: Heap hex dump

## State Ownership

`AppState` is the single `@MainActor ObservableObject` source of truth. It is injected at the root via `.environmentObject` and read by all views via `@EnvironmentObject`. It owns:

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
