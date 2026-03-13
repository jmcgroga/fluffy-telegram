# Implementation

## Project Structure

```
(repo root)/
├── ARM64Learn.xcodeproj/        # Xcode project — no SPM; single synchronized root group
├── ARM64Learn/                  # Main app target (one PBXFileSystemSynchronizedRootGroup)
│   ├── App/
│   │   ├── ARM64LearnApp.swift  # @main entry point; owns AppState; main + output window scenes
│   │   └── ContentView.swift    # AppRootView, SidebarToggle environment key
│   ├── ViewModels/
│   │   └── AppState.swift       # @MainActor ObservableObject; all state + actions
│   ├── Models/
│   │   ├── Tutorial.swift       # Tutorial, TutorialCategory, Difficulty
│   │   └── MemoryState.swift    # MemoryState, MemorySegment, Register, StackFrame
│   ├── Views/
│   │   ├── Workspace/
│   │   │   ├── MainWorkspaceView.swift    # Split layout: Tutorial | Editor | SegmentPanel / MemoryStrip
│   │   │   ├── WorkspaceView.swift        # Same split layout as MainWorkspaceView
│   │   │   ├── WorkspaceToolbar.swift     # Toolbar: language picker, build buttons, tutorial toggle, output window
│   │   │   ├── SidebarView.swift          # Tutorial list / NavigationSplitView sidebar
│   │   │   ├── TutorialContentView.swift  # Markdown rendered via AttributedString
│   │   │   └── CodeEditorView.swift       # NSViewRepresentable wrapping LineNumberTextView; header includes DebuggerControlBar
│   │   ├── Registers/
│   │   │   └── RegisterPanelView.swift    # RegisterListView, RegisterRowView, FlagBitsView, FPSRFlagsView
│   │   └── BottomPanel/
│   │       ├── BottomPanelView.swift      # Tabbed console (Build/Terminal/LLDB) + tab bar
│   │       ├── OutputWindowView.swift     # Wrapper for BottomPanelView in output window
│   │       ├── SegmentPanelView.swift     # VSplitView: __DATA (top) + __TEXT (bottom)
│   │       ├── MemoryStripView.swift      # HSplitView: Registers + Stack + Heap (all visible)
│   │       ├── BuildOutputView.swift      # Scrollable build/run output
│   │       ├── LLDBDebuggerView.swift     # LLDB console + debug command panel + command input
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

`AppState` is the single `@MainActor` `ObservableObject`. It is created as a `@StateObject` in `ARM64LearnApp` and injected via `.environmentObject()` into both the main `WindowGroup` and the output `Window` scene for cross-window state sharing. All views receive it via `@EnvironmentObject`.

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
| `lldbController` | `LLDBController` | Published so views can read `sessionState`, `lastStopReason`, `inferiorNeedsInput` |
| `lldbInferiorNeedsInput` | `Bool` (computed) | `true` only when user continued execution and inferior may block on stdin |
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

Owns the `lldb <binaryPath>` subprocess. Output handlers:
- `controllerOutputHandler` — forwarded to `LLDBController.receiveOutput` synchronously (parsing). This is the **only** output path; all display forwarding is managed by `LLDBController` via `forwardToDisplay` so internal refresh commands stay hidden from the user's console.
- `outputHandler` — used only for the termination message (`[LLDB session ended]`).

`send(_ text: String)` writes to the subprocess stdin pipe.

## LLDBController (`ARM64Learn/Services/LLDBController.swift`)

Sentinel-delimited command/response correlator sitting on top of `LLDBSession`.

### Command execution architecture

There is exactly **one** primitive for sending a command and getting its response:

```swift
private func send(_ command: String) async -> String
```

It registers a `CheckedContinuation` in the `promptContinuations` queue, sends the command text **and** a hidden `script print("LLDB_DONE_UUID")` sentinel to LLDB stdin, and awaits the continuation. No timeout, no display, no side effects. Every higher-level method composes on top of `send()`.

Display forwarding is opt-in at each call site via `display(_ text:)`, which forwards to `forwardToDisplay` on the MainActor.

#### Why UUID sentinels instead of `(lldb) ` prompt scanning

Searching for `(lldb) ` to delimit responses is fragile: the string appears inside help text, stop notifications, and other output. A UUID that we generate cannot appear in legitimate command output, so `receiveOutput` can wait for `LLDB_DONE_UUID\n` unambiguously regardless of what the command outputs.

#### LLDB output structure with sentinel

```
(lldb) COMMAND\n                      ← echo of real command
<command output>
(lldb) script print("LLDB_DONE_ID")\n ← echo of sentinel command
LLDB_DONE_ID\n                        ← sentinel output  ← delimiter
(lldb)                                ← bare prompt (may arrive in same chunk)
```

`receiveOutput` finds the sentinel, takes everything before it as the raw response, strips both echoes, and resumes the continuation.

### Session state machine (`DebuggerSessionState`)

```
idle → launching → ready ↔ running
                 → terminated / error
```

- `launching`: LLDB process spawned; `file` command not yet resolved
- `ready`: `file` command (or any stop) resolved; user can issue commands
- `running`: inferior executing after a step or continue command

### `inferiorNeedsInput: Bool`
Published flag set **only** in `continueExecution()` (after the user explicitly presses Continue). Cleared by `handleStopResponse()`, `terminate()`, and the process-exit path. `LLDBDebuggerView` uses this — not `sessionState == .running` — to decide whether to show the program-stdin input row.

### `PendingCommand` struct
Holds the continuation, original `command` text, and `sentinelID` (UUID without hyphens). Computed properties:
- `sentinelOutput` → `"LLDB_DONE_\(sentinelID)\n"` — the delimiter we wait for
- `commandEcho` → `"(lldb) \(command)\n"` — stripped from response start
- `sentinelCmdEcho` → `"(lldb) script print(\"LLDB_DONE_\(sentinelID)\")\n"` — stripped from response end

### `send(_ command: String) async -> String`
The sole command execution primitive. Under `outputLock`: appends a `PendingCommand` with a fresh UUID, sends `command + "\n"` and `script print("LLDB_DONE_UUID")\n` to LLDB stdin, then releases the lock and awaits the continuation.

### `display(_ text: String) async`
Forwards text to the user-visible LLDB console via `forwardToDisplay` on the MainActor. Called explicitly by launch, step, continue, and breakpoint methods. NOT called by `refreshState` — so internal register/memory reads stay hidden.

### `sendRawCommand(_ command: String) async -> String`
For user-typed LLDB commands. Delegates to `send()`. Does NOT echo to display — the caller (`AppState.sendLLDBCommand`) manages the `(lldb) ` prompt prefix and response display.

### `receiveOutput(_ chunk: String)`
Called by `LLDBSession.controllerOutputHandler` on the pipe's background reader thread. Appends to `outputBuffer`, checks for process-exit signals, then drains all sentinel-delimited responses with waiting continuations. For each pending command: searches `outputBuffer` for `sentinelOutput`; if not found, breaks (waits for more data); if found, extracts the raw response, advances the buffer past the sentinel, strips the bare `(lldb) ` prompt if it arrived in the same chunk, strips both echoes from the response, and enqueues the continuation for resumption. Continuations are resumed **after** `outputLock` is released to prevent re-entrancy deadlocks.

### Two delimiter modes — why `waitForStop` exists

In sentinel mode (default), `send()` appends `script print("LLDB_DONE_UUID")` to the pipe immediately after the real command. LLDB processes both sequentially while in command mode, and the sentinel output is a reliable delimiter.

However, while the inferior is **running** (after `continue`/step commands), LLDB reads bytes from its control pipe and echoes them verbatim to output without executing them. If the sentinel bytes are in the pipe when the inferior starts, they are consumed this way — `LLDB_DONE_UUID\n` never appears in output, and `send()` hangs forever.

For commands that run the inferior, `send(_:waitForStop: true)` sends NO sentinel. Instead, `receiveOutput` waits for `") stopped.\n"` — the final token of every LLDB stop notification (`Target N: (binary) stopped.\n`). This pattern always appears exactly once at the end of the inferior's stop output and is not present in any normal command output.

### Individual launch steps (public, called from debug command panel)

| Method | LLDB Command | Description |
|--------|-------------|-------------|
| `waitForStartup()` | `settings set target.process.stdin /dev/null` + `file "<path>"` | Isolate inferior stdin, load binary, transition to `.ready` |
| `launchStopAtEntry()` | `process launch --stop-at-entry` | Launch inferior, stop at dynamic linker |
| `breakAtMain()` | `b main` | Set breakpoint at `_main` |
| `setUserBreakpoints(...)` | `breakpoint set --file F --line N` | Set user-defined breakpoints |
| `continueToBreakpoint()` | `continue` | Resume to first breakpoint |
| `readRegisters()` | `register read` + `register read fpsr` | Populate register panel |
| `readBacktrace()` | `bt 1` | Determine current frame/line |
| `readStackMemory()` | `memory read $sp` | Read 16 quadwords from stack |
| `readDataSection()` | `image dump sections` + `memory read` | Read __DATA segment |
| `readTextSection()` | `image dump sections` + `memory read` | Read __TEXT segment |

`launchAndBreakAtMain()` composes all launch steps + `refreshState()`. `refreshState()` composes all read steps. Both are available as "Run All" / "Refresh All" buttons.

**Note**: Both `parseDataSection()` and `parseTextSection()` find all subsections within the segment and calculate the combined range from the first subsection to the last. This avoids displaying large zero-padded container regions.

**TEXT subsections matched**: `code` (e.g., `__text`, `__stubs`), `compact_unwind`, `literal_pointers`, `cstring_literals`, `symbols`, `unwind_info`

**DATA subsections matched**: `data` (e.g., `__data`), `zero_fill` (e.g., `__bss`), `common` (e.g., `__common`)

### `findDataSection()` / `findTextSection()` — cached section lookups
Issue `image dump sections <binary>` via `send()` once, cache the result. Subsequent calls return the cached value immediately without any LLDB traffic. Section addresses never change within a debugging session.

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

The view's header bar contains the language label (`.s` / `.c`), `DebuggerControlBar` (Run/Pause/Stop/Step buttons inline), and quick action buttons (Build & Run, Debug). The debugger controls are separated from the language label by a `Divider`.

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

## LLDBDebuggerView (`Views/BottomPanel/LLDBDebuggerView.swift`)

The LLDB tab view. When a debug session is active, displays a left sidebar (`DebugCommandPanel`, 200pt wide) alongside the `ConsoleOutputView`. Below: `LLDBCommandRow` or `ProgramInputRow` depending on `inferiorNeedsInput`.

### `DebugCommandPanel`
Left sidebar with ordered buttons for each debugger initialization step. Three sections:
- **Launch Sequence**: Steps 1–4 (launch, break, user breakpoints, continue)
- **Read State**: Steps a–e (registers, backtrace, stack, __DATA, __TEXT)
- **Batch**: "Run All Launch Steps" and "Refresh All State"

The launch steps are driven automatically by `launchAndBreakAtMain()` via the Run button. The individual public methods on `LLDBController` remain available for future use.

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
