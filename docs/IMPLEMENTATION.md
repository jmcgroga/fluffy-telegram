# Implementation

## Project Structure

```
ARM64Learn/
├── ARM64Learn.xcodeproj/        # Xcode project — no SPM
├── ARM64Learn/                  # Main app target
│   ├── ARM64LearnApp.swift      # @main entry point; injects AppState environmentObject
│   ├── AppState.swift           # @MainActor ObservableObject; all state + actions
│   └── ContentView.swift        # Root NavigationSplitView
├── Models/
│   ├── Tutorial.swift           # Tutorial, TutorialCategory, Difficulty
│   └── MemoryState.swift        # MemoryState, MemorySegment, Register, StackFrame
├── Views/
│   ├── Workspace/
│   │   ├── MainWorkspaceView.swift    # HSplitView layout + BottomPanelView
│   │   ├── WorkspaceToolbar.swift     # Toolbar: language picker, build buttons, panel toggles
│   │   ├── SidebarView.swift          # Tutorial list / NavigationSplitView sidebar
│   │   ├── TutorialContentView.swift  # Markdown rendered via AttributedString
│   │   ├── CodeEditorView.swift       # NSViewRepresentable wrapping LineNumberTextView
│   │   └── WorkspaceView.swift        # ContentView workspace wrapper
│   ├── Registers/
│   │   └── RegisterPanelView.swift    # RegisterListView, RegisterRowView, FlagBitsView
│   └── BottomPanel/
│       ├── BottomPanelView.swift      # Tab bar + tab content switcher
│       ├── BuildOutputView.swift      # Scrollable build/run output
│       ├── LLDBDebuggerView.swift     # DebuggerControlBar, register-change chip, console
│       ├── ConsoleOutputView.swift    # Shared scrollable monospaced text view
│       ├── TerminalPanelView.swift    # Terminal session output + input
│       ├── MemoryHexDumpView.swift    # MemoryHexDumpHeader, LiveStackDumpContent
│       └── HexDumpComponents.swift    # HexDumpContent, HexDumpHeader, HexDumpRow
├── Services/
│   ├── ProcessRunner.swift      # Compiler invocation, binary execution, LLDBSession, TerminalSession
│   ├── LLDBController.swift     # Prompt correlator, step commands, auto-refresh, LLDBOutputParser
│   ├── TutorialLoader.swift     # Bundle Markdown parsing → TutorialCategory/Tutorial
│   └── SyntaxHighlighter.swift  # SyntaxHighlightingStorage (NSTextStorage subclass)
└── Resources/
    └── Tutorials/               # 01_intro.md … 10_c_interop.md
```

## AppState (`ARM64Learn/AppState.swift`)

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
| `activeBreakpoints` | `Set<Int>` | 1-based line numbers with active breakpoints |

### `applyRegisterUpdate(_ values: [String: UInt64])`
Diffs incoming register values against `memoryState.registers`, sets `isChanged` flags, and rebuilds `lastRegisterChangeSummary`.

### `applyFrameUpdate(_ frame: ParsedFrame)`
Sets `currentExecutionLine` and `currentExecutionFile` from the parsed backtrace frame, and updates `memoryState.stackFrames`.

### `toggleBreakpoint(line:)`
Adds/removes from `activeBreakpoints` and issues `breakpoint set --line N --file F` or `breakpoint clear --line N --file F` to `LLDBController.sendRawCommand`.

## ProcessRunner (`Services/ProcessRunner.swift`)

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

## LLDBSession (`Services/ProcessRunner.swift`)

Owns the `lldb <binaryPath>` subprocess. Two output handlers:
- `outputHandler` — forwarded to `AppState.lldbOutput` on the main queue (display)
- `controllerOutputHandler` — forwarded to `LLDBController.receiveOutput` synchronously (parsing)

`send(_ text: String)` writes to the subprocess stdin pipe.

## LLDBController (`Services/LLDBController.swift`)

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

### `refreshState()` — three phases after every stop
1. `register read` → `LLDBOutputParser.parseRegisters` → `onRegistersUpdated`
2. `bt 1` → `LLDBOutputParser.parseBacktrace` → `onFrameUpdated`
3. `memory read $sp --count 16 --size 8` → `LLDBOutputParser.parseMemoryRead` → `onMemoryUpdated`

### `LLDBOutputParser`
Static enum with regex-based parsers:

| Method | Input | Output |
|--------|-------|--------|
| `parseRegisters(from:)` | `register read` output | `[String: UInt64]` |
| `parseBacktrace(from:stopReason:)` | `bt 1` output | `ParsedFrame?` |
| `parseStopReason(from:)` | stop block | `String?` |
| `parseMemoryRead(from:)` | `memory read` output | `[(address: UInt64, value: UInt64)]` |
| `detectProcessExit(in:)` | buffered output | `Int32?` exit code |

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

## MemoryHexDumpView (`Views/BottomPanel/MemoryHexDumpView.swift`)

Shows an xxd-style hex dump. When `segmentName == "STACK"` and `appState.liveStackEntries` is non-empty, renders `LiveStackDumpContent` instead of `HexDumpContent`.

### `LiveStackDumpContent`
Converts each `(address: UInt64, value: UInt64)` entry to 8 bytes (little-endian) and passes them to standard `HexDumpRow` components. Shows a green "Live stack — N quadwords from $sp" banner as the sticky section header.

### `HexDumpContent`
Renders simulated data via `generateSampleData()` for non-live tabs (Heap, \_\_DATA, \_\_TEXT) and as the fallback for Stack when no debug session is active.

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
`output`, `terminal`, `lldb`, `stack`, `heap`, `data`, `text`. Each has a `systemImage` for the tab bar icon.

### `DebuggerSessionState`
See [LLDBController section](#lldbcontroller-serviceslldbcontrollerswift) above.
