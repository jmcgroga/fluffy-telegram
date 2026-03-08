# Implementation

## Project Structure

```
(repo root)/
├── ARM64Learn.xcodeproj/        # Xcode project — no SPM; single synchronized root group
├── ARM64Learn/                  # Main app target (one PBXFileSystemSynchronizedRootGroup)
│   ├── App/
│   │   ├── ARM64LearnApp.swift  # @main entry point; menu commands; AppDelegate
│   │   └── ContentView.swift    # AppRootView, SidebarToggle environment key
│   ├── ViewModels/
│   │   └── AppState.swift       # @MainActor ObservableObject; all state + actions
│   ├── Models/
│   │   ├── Tutorial.swift       # Tutorial, TutorialCategory, Difficulty
│   │   └── MemoryState.swift    # MemoryState, MemorySegment, Register, StackFrame
│   ├── Views/
│   │   ├── Workspace/
│   │   │   ├── MainWorkspaceView.swift    # Nested split layout: Tutorial | (Editor+Segments / Console) / MemoryStrip
│   │   │   ├── WorkspaceView.swift        # Same nested split layout as MainWorkspaceView
│   │   │   ├── WorkspaceToolbar.swift     # Toolbar: language picker, build buttons, tutorial toggle
│   │   │   ├── SidebarView.swift          # Tutorial list / NavigationSplitView sidebar
│   │   │   ├── TutorialContentView.swift  # Markdown rendered via AttributedString
│   │   │   └── CodeEditorView.swift       # NSViewRepresentable wrapping LineNumberTextView
│   │   ├── Registers/
│   │   │   └── RegisterPanelView.swift    # RegisterListView, RegisterRowView, FlagBitsView, FPSRFlagsView
│   │   └── BottomPanel/
│   │       ├── BottomPanelView.swift      # Tabbed console (Build/Terminal/LLDB) + tab bar
│   │       ├── SegmentPanelView.swift     # VSplitView: __DATA (top) + __TEXT (bottom)
│   │       ├── MemoryStripView.swift      # HSplitView: Registers + Stack + Heap (all visible)
│   │       ├── BuildOutputView.swift      # Scrollable build/run output
│   │       ├── LLDBDebuggerView.swift     # DebuggerControlBar, console, command input
│   │       ├── ConsoleOutputView.swift    # Shared scrollable monospaced text view
│   │       ├── TerminalPanelView.swift    # Terminal session output + input
│   │       ├── MemoryHexDumpView.swift    # MemoryHexDumpHeader, LiveStackDumpContent
│   │       └── HexDumpComponents.swift    # HexDumpContent, HexDumpHeader, HexDumpRow
│   ├── Services/
│   │   ├── ProcessRunner.swift      # Compiler invocation, binary execution, LLDBSession, TerminalSession
│   │   ├── LLDBController.swift     # Prompt correlator, step commands, auto-refresh, LLDBOutputParser
│   │   ├── TutorialLoader.swift     # Bundle Markdown parsing → TutorialCategory/Tutorial
│   │   └── SyntaxHighlighter.swift  # SyntaxHighlightingStorage (NSTextStorage subclass)
│   └── Resources/
│       ├── Assets.xcassets/         # App icon, accent color
│       └── Tutorials/               # 01_intro.md … 10_c_interop.md
├── ARM64LearnTests/             # Unit tests
├── ARM64LearnUITests/           # UI / integration tests
├── .github/                     # GitHub Actions workflows, PR/issue templates
├── docs/                        # DESIGN.md, IMPLEMENTATION.md, REFERENCE.md, CHANGELOG.md
├── CLAUDE.md                    # AI assistant instructions and documentation rules
└── README.md                    # User guide
```

The Xcode project uses a single `PBXFileSystemSynchronizedRootGroup` for `ARM64Learn/` — Xcode auto-discovers all Swift files and resources in the directory tree. No manual `PBXFileReference` or `PBXBuildFile` entries are needed for source files.

## AppState (`ARM64Learn/ViewModels/AppState.swift`)

`AppState` is the single `@MainActor` `ObservableObject`. All views receive it via `@EnvironmentObject`.

### Key published properties

| Property | Type | Description |
|----------|------|-------------|
| `currentCode` | `String` | Text in the code editor (two-way binding) |
| `codeLanguage` | `CodeLanguage` | `.arm64` or `.c` |
| `tutorialCategories` | `[TutorialCategory]` | Loaded at init from bundle |
| `selectedTutorial` | `Tutorial?` | Drives tutorial panel content and code reset |
| `buildOutput` | `String` | Streamed compiler + program output |
| `lldbOutput` | `String` | Streamed raw LLDB console text |
| `terminalOutput` | `String` | Streamed shell output |
| `lldbController` | `LLDBController` | Published so views can read `sessionState` and `lastStopReason` |
| `currentExecutionLine` | `Int?` | 1-based line number; drives gutter arrow and syntax storage |
| `lastChangedRegisters` | `Set<String>` | Register names that changed on last step |
| `lastRegisterChangeSummary` | `String` | Human-readable chip text, e.g. `"x0: 0x2A  ·  sp: 0x16F…"` |
| `liveStackEntries` | `[(address: UInt64, value: UInt64)]` | 16 quadwords from `memory read $sp` |
| `liveDataEntries` | `[(address: UInt64, value: UInt64)]` | Data section contents from `memory read` |
| `liveTextEntries` | `[(address: UInt64, value: UInt64)]` | Text section contents from `memory read` |
| `activeBreakpoints` | `Set<Int>` | 1-based line numbers with active breakpoints |

### `applyRegisterUpdate(_ values: [String: UInt64])`
Diffs incoming register values against `memoryState.registers`, sets `isChanged` flags, and rebuilds `lastRegisterChangeSummary`.

### `applyFrameUpdate(_ frame: ParsedFrame)`
Sets `currentExecutionLine` and `currentExecutionFile` from the parsed backtrace frame, and updates `memoryState.stackFrames`.

### `toggleBreakpoint(line:)`
Adds/removes from `activeBreakpoints` and issues `breakpoint set --line N --file F` or `breakpoint clear --line N --file F` to `LLDBController.sendRawCommand`.

## ProcessRunner (`ARM64Learn/Services/ProcessRunner.swift`)

Manages compilation and execution via `Process`.

- **Temp directory**: `NSTemporaryDirectory()/ARM64Learn/` — created on first use
- **Source filenames**: `source.s` / `source.c` (run) and `source_debug.s` / `source_debug.c` (debug)
- **Compiler location**: resolved once via `xcrun --find clang`; falls back to `/usr/bin/clang`
- **ARM64 assembly**: `clang -arch arm64 -x assembler <source> -o <output>`
- **C**: `clang -arch arm64 <source> -o <output>`
- **Debug symbols**: appends `-g` flag
- **Output**: stdout and stderr combined into one string
- `compile()` returns a formatted string with build result + program output
- `compileWithDebugSymbols()` returns `(success, binaryPath?, outputString)`

## LLDBSession (`ARM64Learn/Services/ProcessRunner.swift`)

Owns the `lldb <binaryPath>` subprocess. Two output handlers:
- `outputHandler` — forwarded to `AppState.lldbOutput` on the main queue (display)
- `controllerOutputHandler` — forwarded to `LLDBController.receiveOutput` synchronously (parsing)

`send(_ text: String)` writes to the subprocess stdin pipe.

## LLDBController (`ARM64Learn/Services/LLDBController.swift`)

Prompt-delimited command/response correlator sitting on top of `LLDBSession`.

### Session state machine (`DebuggerSessionState`)

```
idle → launching → ready ↔ running
                 ↘ waitingResponse ↗
                 → terminated / error
```

- `launching`: LLDB process spawned; waiting for first `(lldb) ` prompt
- `ready`: at a breakpoint/step; user can issue commands
- `running`: inferior executing; `sendProgramInput` routes stdin to it
- `waitingResponse`: sent a command; buffering until next prompt (5 s timeout)

### `sendAndAwait(_ command: String) async -> String`
Tier-1 send: sets state to `.waitingResponse`, sends the command, races `awaitPrompt()` against a 5-second timeout. Used for all internal queries (register read, bt, memory read) and `sendRawCommand`.

### `awaitPrompt() async -> String`
No-timeout await for the next `(lldb) ` prompt. Used for `run` and `process continue` where execution time is unbounded.

### `refreshState()` — six phases after every stop
1. `register read` → `LLDBOutputParser.parseRegisters` → `onRegistersUpdated`
2. `register read fpsr` → parse FPSR register explicitly
3. `bt 1` → `LLDBOutputParser.parseBacktrace` → `onFrameUpdated`
4. `memory read $sp --count 16 --size 8` → `LLDBOutputParser.parseMemoryRead` → `onStackMemoryUpdated`
5. `image dump sections` → `LLDBOutputParser.parseDataSection` → `memory read` (combined range of all `__DATA` subsections) → `onDataMemoryUpdated`
6. `image dump sections` → `LLDBOutputParser.parseTextSection` → `memory read` (combined range of all `__TEXT` subsections) → `onTextMemoryUpdated`

**Note**: Both `parseDataSection()` and `parseTextSection()` find all subsections within the segment and calculate the combined range from the first subsection to the last. This avoids reading large unused regions in the container that are filled with zeros.

**TEXT subsections matched**: `code` (e.g., `__text`, `__stubs`), `compact_unwind`, `literal_pointers`, `cstring_literals`, `symbols`, `unwind_info`

**DATA subsections matched**: `data` (e.g., `__data`), `zero_fill` (e.g., `__bss`), `common` (e.g., `__common`)

**Example**: If TEXT container is `0x100000000-0x100004000` but only `__text` at `0x100000458-0x100000478` and `__stubs` at `0x100000478-0x100000484` exist, the parser returns `0x100000458-0x100000484` (44 bytes) instead of the full 16 KB container.

### `LLDBOutputParser`
Static enum with regex-based parsers:

| Method | Input | Output |
|--------|-------|--------|
| `parseRegisters(from:)` | `register read` output | `[String: UInt64]` |
| `parseBacktrace(from:stopReason:)` | `bt 1` output | `ParsedFrame?` |
| `parseStopReason(from:)` | stop block | `String?` |
| `parseMemoryRead(from:)` | `memory read` output | `[(address: UInt64, value: UInt64)]` |
| `detectProcessExit(in:)` | buffered output | `Int32?` exit code |
| `parseDataSection(from:)` | `image dump sections` output | `(address: UInt64, size: UInt64)?` |
| `parseTextSection(from:)` | `image dump sections` output | `(address: UInt64, size: UInt64)?` |

## CodeEditorView (`Views/Workspace/CodeEditorView.swift`)

`SyntaxTextEditor` is an `NSViewRepresentable` wrapping `LineNumberTextView` inside an `NSScrollView`.

### `SyntaxHighlightingStorage`
`NSTextStorage` subclass. Holds a backing `NSMutableAttributedString` and applies syntax highlighting in `processEditing()` after every edit. Maintains `executionLine: Int?`; calls `applyExecutionLineBackground()` after each highlight pass so the green execution-line highlight is never overwritten.

### `LineNumberTextView`
`NSTextView` subclass. `textContainerInset` shifts content right by `gutterWidth` (44 pt) to leave room for the gutter. All drawing is done in `draw(_:)`:

1. Fill gutter with dark gray (`NSColor(white: 0.12, alpha: 1)`)
2. Fill text area with editor background
3. Call `super.draw(dirtyRect)` with `drawsBackground = false` to avoid overdrawing
4. Draw 0.5 pt separator line
5. Call `drawLineNumbers(in:)` to overlay gutter decorations

**Gutter decorations per line:**
- Execution line: green gutter background + green `▶` arrow + green line number
- Breakpoint: red `●` dot + red line number
- Normal: gray line number

**Click handling:** `mouseDown(with:)` intercepts clicks where `point.x < gutterWidth`, converts the y-coordinate to a 1-based line number via `lineNumber(at:)`, and calls `onBreakpointToggle`.

## RegisterPanelView (`Views/Registers/RegisterPanelView.swift`)

`RegisterListView` groups `memoryState.registers` by `Register.Category` and renders collapsible sections. Each `RegisterRowView` shows:
- Register name (monospaced, 80 pt fixed width)
- Alias if present (e.g. `fp` for `x29`)
- Value: `FlagBitsView` for `nzcv`; hex/decimal toggle button for all others
- Yellow background (animated) when `register.isChanged`

### `FlagBitsView`
Decodes PSTATE NZCV bits from a `UInt64`:
- N = bit 31 (negative)
- Z = bit 30 (zero)
- C = bit 29 (carry)
- V = bit 28 (overflow)

Renders each as a small badge: filled with accent color when set, dimmed when clear. Animated via `.animation(.easeOut(duration: 0.3), value: set)`.

## ConsoleOutputView (`Views/BottomPanel/ConsoleOutputView.swift`)

Shared `NSViewRepresentable` component for displaying scrollable, monospaced console output with horizontal scrolling.

- **No line wrapping**: `textContainer.widthTracksTextView = false` allows text to extend horizontally
- **Text container size**: `CGFloat.greatestFiniteMagnitude` for both width and height
- **Scrolling**: Both horizontal and vertical scrollbars enabled, auto-hiding
- **Auto-scroll**: Automatically scrolls to bottom on new content if already at bottom
- **Styling**: 11pt monospaced system font, 12pt horizontal / 8pt vertical inset

Used by `BuildOutputView`, `LLDBDebuggerView`, and `TerminalPanelView`.

## MemoryHexDumpView (`Views/BottomPanel/MemoryHexDumpView.swift`)

Shows an xxd-style hex dump. When `segmentName` matches `"STACK"`, `"__DATA"`, or `"__TEXT"` and the corresponding `liveStackEntries`, `liveDataEntries`, or `liveTextEntries` is non-empty, renders `LiveStackDumpContent` instead of `HexDumpContent`.

### `LiveStackDumpContent`
Converts each `(address: UInt64, value: UInt64)` entry to 8 bytes (little-endian) and passes them to `StackQuadwordRow` components. Shows a green "Live [segment] — N quadwords" banner as the sticky section header. The segment name is determined by address range:
- Text section: addresses in range `0x100000000...0x100010000`
- Data section: addresses in range `0x1_0000_0000...0x2_0000_0000`
- Stack: all other addresses

Each row displays:
- **Address**: 16 hex digits without `0x` prefix (e.g., `0000000100008000:`), format `%016llX`
- **Hex bytes**: 8 bytes in little-endian order, space-separated
- **ASCII**: printable characters or `.` for non-printable bytes

### `HexDumpContent`
Renders simulated data via `generateSampleData()` for non-live tabs (Heap) and as the fallback for Stack, Data, and Text when no debug session is active.

## SegmentPanelView (`Views/BottomPanel/SegmentPanelView.swift`)

A `VSplitView` containing two `MemoryHexDumpView` instances stacked vertically. Placed in the top-right area of the workspace:
- **Top**: `MemoryHexDumpView(segmentName: "__DATA")` — live data segment hex dump
- **Bottom**: `MemoryHexDumpView(segmentName: "__TEXT")` — live text segment hex dump

Both halves have `minHeight: 80` and can be resized by dragging the split divider.

## MemoryStripView (`Views/BottomPanel/MemoryStripView.swift`)

An `HSplitView` displaying three views side-by-side in the bottom-right area. All three are always visible simultaneously:
- **Left**: `RegisterPanelView()` — register list with collapsible categories
- **Center**: `MemoryHexDumpView(segmentName: "STACK")` — live stack hex dump
- **Right**: `MemoryHexDumpView(segmentName: "HEAP")` — heap hex dump

Each column has `minWidth: 200` and can be resized by dragging the split dividers.

## TutorialLoader (`Services/TutorialLoader.swift`)

Scans the app bundle for `.md` files in `Resources/Tutorials/`. Files named `NN_slug.md` are parsed for a YAML-style frontmatter block that can contain:
- `language:` (`arm64` or `c`)
- `sampleCode:` (fenced code block or inline)
- `memoryHighlights:` (segment names)

Tutorials are grouped into `TutorialCategory` objects based on their numeric prefix.

## Enums

### `CodeLanguage`
`.arm64` (file extension `s`) and `.c` (extension `c`). Drives editor mode, compiler flags, and default sample code.

### `BottomPanelTab`
`output`, `terminal`, `lldb`. Each has a `systemImage` for the tab bar icon. The memory views (Stack, Heap, \_\_DATA, \_\_TEXT) are no longer tabs — they are always-visible panels in the new layout.

### `DebuggerSessionState`
See [LLDBController section](#lldbcontroller-serviceslldbcontrollerswift) above.
