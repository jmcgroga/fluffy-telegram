# Changelog

Entries are newest first. Each entry covers one logical change set.

---

## 2026-03-14 — Move debugger controls to toolbar; separate Run and Debug buttons

### Changed
- **`DebuggerControlBar`** (`LLDBDebuggerView.swift`): Replaced the single "Run/Continue" button with two distinct buttons:
  - **Run** (blue, `play.fill`): builds and runs without a debugger session (`compileCode()`). Disabled when a debug session is already active.
  - **Debug/Cont** (green, `ant.fill` / `forward.fill`): starts a debug session (`compileAndDebug()`) when no session exists; acts as Continue (`continueExecution()`) when a session is paused. Label and icon switch dynamically between "Debug" and "Cont".
  - Both buttons open the output window automatically via `@Environment(\.openWindow)`.
- **`WorkspaceToolbar`** (`WorkspaceToolbar.swift`): Replaced the standalone "Build & Run" and "Debug" buttons with `DebuggerControlBar()`, consolidating all execution controls in one place.
- **`CodeEditorView`** (`CodeEditorView.swift`): Removed `DebuggerControlBar()` from the editor header. The header now shows only the language label and quick-action buttons (reset, copy).

---

## 2026-03-13 — Restore __TEXT hex dump, highlight current instruction bytes, assembly hover tooltip

### Feature: __TEXT hex dump restored in SegmentPanel

`SegmentPanelView` now shows three panes: `__DATA`, `__TEXT`, and `Disassembly`. The `__TEXT`
pane shows the raw machine code bytes of the text section read via LLDB `memory read`. The
`readTextSection()` call was re-added to `LLDBController.refreshState()`.

### Feature: Current instruction highlighted in __TEXT hex dump

When the debugger is paused, the 4 bytes of the currently-executing ARM64 instruction are
highlighted in orange within the `__TEXT` hex dump. ARM64 instructions are always 4 bytes and
4-byte aligned, so they occupy either bytes [0-3] or [4-7] within each 8-byte quadword row.

`StackQuadwordRow` now accepts an optional `highlightByteRange: Range<Int>?` and renders each
byte as a separate `Text` view in an `HStack`, applying an orange background to highlighted bytes.
`LiveStackDumpContent` receives an optional `highlightAddress` and computes the byte range
per row by masking with `~7`. `MemoryHexDumpView` passes `appState.currentExecutionAddress`
as `highlightAddress` for the `__TEXT` segment.

### Feature: Assembly instruction hover tooltip in source editor

Hovering the mouse over a source line in the editor now shows a native macOS tooltip with:
- The disassembly text of the corresponding ARM64 instruction(s)
- The machine code bytes (e.g. `FD 7B BF A9`) from the live `__TEXT` memory
- A plain-English description of the instruction mnemonic

`LineNumberTextView` adds an `NSTrackingArea` for `mouseMoved` events. On each move it
converts the mouse point to a source-line number, filters `disassembly` for matching lines,
extracts 4 bytes from `textEntries` at the instruction's address, and sets `toolTip`.
The byte extraction: `quadwordAddr = address & ~7`, `byteOffset = address & 7` (0 or 4).
`SyntaxTextEditor` now accepts `disassembly` and `textEntries` params and syncs them to
the text view in `updateNSView`. A 90-entry mnemonic description table covering all common
ARM64 instructions is embedded in `LineNumberTextView`.

---

## 2026-03-13 — Fix disassembly view showing no data; add source-line lookup via DWARF

### Bug: disassembly view empty after program starts

The original command `disassemble -l --function _main` used two wrong flags:
- `-l` in LLDB is `--line` (expects a line number argument), not source-interleaving
- `--function` is not a valid `disassemble` option; the correct form is `--name`

So LLDB received a malformed command and returned an error instead of instructions.

**Fix**: Changed to `disassemble --frame` which always works — it disassembles the current
frame's function regardless of symbol name, requires no source file, and never needs `-l`.

### Feature: source line numbers from DWARF (no source file required)

Source line markers from `disassemble --mixed` require the `.s` file to be accessible on disk.
Instead, we now use `image lookup --address <addr>` per instruction, which reads the source
line from the DWARF line-table embedded in the binary. This works after the source file has
been moved or deleted (e.g. the temp file in `/var/folders/...`).

`LLDBOutputParser.parseImageLookupLine(from:)` extracts the line number from the
`Summary: ..._main + N at source_debug.s:LINE:COL` summary text.

Results are cached by function base address in `LLDBController` so the N per-instruction
lookups only run once per function — subsequent steps within the same function reuse the cache.

---

## 2026-03-13 — Disassembly view with source-line markers and PC highlighting

Replaced the raw `__TEXT` hex dump in `SegmentPanelView` with a new `DisassemblyView` that shows decoded ARM64 instructions alongside source-line markers and a live `▶` current-PC indicator.

### New: `DisassemblyLine` model (`MemoryState.swift`)
`DisassemblyLine` stores `address`, `offset`, `text`, and `sourceLine` (from LLDB's `;; file:N` markers).

### New: `DisassemblyView` (`Views/BottomPanel/DisassemblyView.swift`)
- Renders instructions in fixed-width monospaced columns (address / offset / instruction)
- Inserts italic `;; line N` source-marker separators when the source line changes
- Highlights the current PC row with `▶` indicator and yellow background (`0.18` opacity)
- Auto-scrolls to keep the current instruction visible via `ScrollViewReader` + `.onChange`
- Shows an empty state ("Start debugging to view disassembly") before a session starts

### New: `LLDBController.readDisassembly()` + `LLDBOutputParser.parseDisassembly(from:)`
Issues `disassemble --frame` after each stop. Parses instruction lines to produce raw `[DisassemblyLine]`. Then issues `image lookup --address` per instruction to read source line numbers from embedded DWARF debug info (works without the source file on disk). Results are cached by function base address so the per-instruction lookups only happen once per function. Fires via `onDisassemblyUpdated` callback.

### Updated: `AppState`
- New `@Published var currentExecutionAddress: UInt64?` — set from `ParsedFrame.address` on each stop; cleared on terminate/reset
- New `@Published var liveDisassembly: [DisassemblyLine]` — populated by `onDisassemblyUpdated` callback; cleared on terminate/reset
- `applyFrameUpdate` now also sets `currentExecutionAddress`

### Updated: `SegmentPanelView`
Bottom panel is now `DisassemblyView()` instead of `MemoryHexDumpView("__TEXT")`.

---

## 2026-03-13 — Fix debugging controls not working; fix step hang on process exit

### Bug: debugging controls non-functional after starting a session

`compileAndDebug()` only called `waitForStartup()` (the `file` command), so no inferior was ever launched. Step and continue buttons had no process to act on.

**Fix**: `compileAndDebug()` now calls `launchAndBreakAtMain()` which runs the full sequence: load binary → launch inferior → set breakpoints → continue to main → refresh panels. `lldbSession` and `lldbController` are assigned before the launch sequence so the UI observes all intermediate state transitions (launching → running → ready) in real time.

### Bug: step commands hang when the inferior exits during a step

`issueStepCommand()` always called `refreshState()` after `handleStopResponse()`. If the inferior exited during the step, `refreshState()` sent commands to a dead session and waited forever for responses that never came.

Additionally, `handleStopResponse()` always set `sessionState = .ready`, silently overriding the `.terminated` state set by `receiveOutput` when it detected the process exit.

**Fix**:
- `handleStopResponse()` now checks `detectProcessExit` first; if the process exited it only clears `inferiorNeedsInput` and returns, leaving the `.terminated` state intact
- `issueStepCommand()` checks `sessionState` after `handleStopResponse()` and only calls `refreshState()` when still `.ready`

---

## 2026-03-13 — Add unit tests for LLDB parser and controller

Added comprehensive unit tests in `ARM64LearnTests/ARM64LearnTests.swift` using Swift Testing:

- **`LLDBOutputParser.parseRegisters`** — standard registers, `fp`/`lr`/`cpsr` aliases, zero values, empty input, unrecognisable lines
- **`LLDBOutputParser.parseBacktrace`** — frames with/without source location, default stop reason, nil on no match
- **`LLDBOutputParser.parseStopReason`** — breakpoint, step, signal, whitespace trimming, nil on no match
- **`LLDBOutputParser.parseMemoryRead`** — single/multiple rows, little-endian conversion, all-zero, all-0xFF, sub-8-byte rows ignored
- **`LLDBOutputParser.detectProcessExit`** — exit 0, non-zero, embedded in block, no exit, partial word
- **`LLDBOutputParser.parseDataSection`** — single subsection, combined range across multiple subsections, nil when absent
- **`LLDBOutputParser.parseTextSection`** — same as above for `__TEXT`
- **`LLDBController` initial state** — `sessionState == .idle`, `lastStopReason == ""`, `inferiorNeedsInput == false`
- **`LLDBController.attach()`** — transitions `sessionState` to `.launching`
- **`LLDBController.receiveOutput` — process exit path** — `onProcessTerminated` callback fired with correct code, `sessionState` → `.terminated`, `inferiorNeedsInput` cleared, no spurious callbacks for non-exit output
- **`DebuggerSessionState`** — `Equatable` correctness, label non-emptiness

---

## 2026-03-13 — Remove debug command panel

Removed `DebugCommandPanel`, `CommandButton`, and `SectionHeader` from `LLDBDebuggerView` — the step-by-step manual launch buttons were only needed while debugging the LLDB integration. `LLDBDebuggerView` now shows only the console output and command input row. All launch steps are driven automatically by `launchAndBreakAtMain()` via the Run button in `DebuggerControlBar`.

---

## 2026-03-13 — Fix `continue` hang; add command/response visual distinction in LLDB console

### Bug: `continue` hung indefinitely (root cause confirmed)

Live testing revealed the exact mechanism: while the inferior is running after `continue`, LLDB reads bytes from its control pipe (stdin) and **echoes them verbatim to output without executing them**. The UUID sentinel (`script print("LLDB_DONE_UUID")`) was consumed this way — it appeared in LLDB's output as plain text without the `(lldb) ` echo prefix, and `LLDB_DONE_UUID\n` was never output, so `receiveOutput` hung forever waiting for it.

Note: `settings set target.process.stdin /dev/null` (attempted in the previous fix) is not a valid LLDB setting path and does not help.

**Fix: hybrid delimiter strategy**

Commands that run the inferior (`continue`, `process continue`, step commands) now use `waitForStop: true` in `send()`. No sentinel is sent for these commands. Instead, `receiveOutput` waits for `") stopped.\n"` — the end of every LLDB stop notification (`Target N: (name) stopped.\n`). All other commands continue using the UUID sentinel approach.

- `PendingCommand` gets a `waitForStop: Bool` field
- `send(_:waitForStop:)` takes the new parameter; skips the sentinel write when `true`
- `receiveOutput` drain loop has two paths: sentinel search and stop-notification search
- `continueToBreakpoint()`, `continueExecution()`, `issueStepCommand()` pass `waitForStop: true`

### Display: commands now shown with `(lldb) ` prefix

All panel-initiated commands were displayed without the `(lldb) ` prefix, so they appeared the same color as response text. All `display()` call sites for commands now use `(lldb) CMD` format, matching `ConsoleOutputView`'s existing rule that colors `(lldb)` lines blue. Commands are now visually distinct from responses.

---

## 2026-03-13 — Robust LLDB output parsing via UUID sentinel commands

### Problem
The previous `(lldb) ` prompt search was fragile:
- `(lldb) ` appearing inside command output (help text, stop notifications) prematurely terminated responses
- Any startup text before the first command could orphan the `file` command's echo
- `hasPrefix` echo-stripping only worked when the echo was exactly at the buffer start

### Solution
After every real command, `send()` also writes a hidden sentinel to LLDB stdin:
```
script print("LLDB_DONE_UUID")
```
`receiveOutput` waits for `LLDB_DONE_UUID\n` — a string that cannot appear in legitimate command output — instead of scanning for `(lldb) `.

### Changed
- **`LLDBController.PendingCommand`** — replaced `echo: String` field with `command`, `sentinelID`, and computed `sentinelOutput`/`commandEcho`/`sentinelCmdEcho` properties
- **`LLDBController.send()`** — generates a UUID sentinel per call, sends both the real command and `script print("LLDB_DONE_UUID")` atomically under `outputLock`
- **`LLDBController.receiveOutput()` drain loop** — now searches for `pending.sentinelOutput` instead of `(lldb) `; strips command echo from start and sentinel echo from end of response; removes the `.launching → .ready` state transition (moved to `waitForStartup`)
- **`LLDBController.waitForStartup()`** — transitions `sessionState` to `.ready` after the `file` command sentinel resolves

---

## 2026-03-12 — Fix LLDB response off-by-one caused by startup echo

### Root cause
When LLDB is launched with a binary argument it emits `(lldb) target create "..."` (the auto-run command with the prompt prefix) followed by the response and a trailing `(lldb) ` ready prompt. The prompt parser searched for the first `(lldb) ` in the buffer, which matched the startup echo at position 0 instead of the actual ready prompt at the end. This left the real ready prompt as a stale entry in the buffer. Every subsequent `send()` call consumed the *previous* command's response — responses were shifted by one, so the first button press showed no output, typing `pwd` showed the launch output, etc.

### Fixed
- **`LLDBSession.start()`** — LLDB is now launched with no arguments instead of passing the binary path on the command line. This eliminates the startup `(lldb) target create ...` echo that was the root cause of the response off-by-one.
- **`LLDBController` — command echo stripping** (root cause fix): LLDB echoes every command as `(lldb) commandText\n` before its response, even in non-interactive/pipe mode. `receiveOutput` was treating the echo's `(lldb) ` as the real response prompt, resolving continuations with empty strings and leaving the actual response stranded in the buffer. Fixed with `PendingCommand` struct that carries the expected `echo: String` alongside each continuation. `receiveOutput` now strips both the full `(lldb) commandText\n` prefix (typical first chunk) and the bare `commandText\n` leftover (after a prior prompt search already consumed the `(lldb) ` of a batched echo) before scanning for the real prompt.
- **`LLDBController.waitForStartup()`** — Removed the now-unnecessary `waitForPrompt()` call. LLDB with pipe stdin does not emit an initial prompt before receiving a command; the echo-stripping in `send()` handles everything correctly from the first `file` command onward.
- **`ProcessRunner.signForDebugging()`** (new) — After debug compilation, ad-hoc signs the binary with the `com.apple.security.get-task-allow` entitlement. Without this, macOS denies LLDB the task port right and `process launch --stop-at-entry` hangs indefinitely.
- **`AppState.compileAndDebug()`** — `lldbSession` and `lldbController` are now assigned **after** `waitForStartup()` completes instead of before. This prevents the command input from being live while `sessionState` is still `.launching`, which caused manually typed commands to be silently dropped (sendRawCommand returns "" when state != .ready).

---

## 2026-03-11 — Add debug command panel; manual step-by-step debugger initialization

### Added
- **Debug command panel** — Left sidebar in the LLDB tab with buttons for each initialization step. Buttons are in execution order and show the LLDB command they will run. Spinner shown while each step is executing.
  - **Launch Sequence**: (1) Launch stop-at-entry, (2) Break at main, (3) Set user breakpoints, (4) Continue to breakpoint
  - **Read State**: (a) Registers, (b) Backtrace, (c) Stack memory, (d) __DATA section, (e) __TEXT section
  - **Batch**: "Run All Launch Steps" and "Refresh All State" convenience buttons
- **Individual public methods on LLDBController** — `waitForStartup()`, `launchStopAtEntry()`, `breakAtMain()`, `setUserBreakpoints()`, `continueToBreakpoint()`, `readRegisters()`, `readBacktrace()`, `readStackMemory()`, `readDataSection()`, `readTextSection()`. Each wraps a single LLDB interaction and can be called independently.

### Changed
- **`compileAndDebug()` no longer auto-runs the launch sequence** — It only consumes the LLDB startup prompt. The user drives each step from the debug command panel (or uses "Run All" for the old automatic behavior).
- **`refreshState()` made public** — Now delegates to the individual read methods. Called by step/continue commands and the "Refresh All State" button.
- **`launchAndBreakAtMain()` preserved as convenience** — Now composes the individual step methods. Used by the "Run All Launch Steps" button.

---

## 2026-03-11 — Rewrite LLDB command execution to fix debugger hang on launch

### Root cause
`LLDBController` had 5 overlapping send/await variants (`awaitPrompt`, `sendAndAwaitPrompt`, `sendAndAwait`, `sendInternal`, `sendRawCommand`) with inconsistent timeout, display, and locking behavior. A race condition in the original `send → awaitPrompt` sequence allowed LLDB responses to arrive before a continuation was registered, causing `receiveOutput` to silently discard the response. This made the controller hang forever during `refreshState` (register read, memory read, etc.) after the initial breakpoint.

### Fixed
- **Race condition in prompt handling** — The old code called `session.send()` then `awaitPrompt()` as separate steps. If LLDB responded before `awaitPrompt()` registered its continuation, `receiveOutput` consumed the `(lldb)` prompt with no waiting continuation and discarded the response. Commands would hang indefinitely.
- **Prompt discard when no continuation waiting** — `receiveOutput` now leaves buffered prompts in place when no continuation is registered, instead of consuming and discarding them.
- **Lock held during continuation resume** — Continuations are now collected and resumed **after** `outputLock` is released, preventing re-entrancy deadlocks.
- **Double console output** — `LLDBSession` was forwarding raw output to both a display handler and the controller parser. Now it only sends to the controller parser; all display forwarding is managed explicitly by `LLDBController`.

### Changed
- **Single command primitive** — Replaced 5 overlapping send methods with one: `send(_ command:) async -> String`. It atomically registers a continuation then sends. No timeout, no display, no side effects. All higher-level methods compose on top.
- **Explicit display forwarding** — New `display(_ text:) async` helper. Called at each call site that should show output to the user. `refreshState` calls `send()` directly without `display()`, keeping internal commands hidden.
- **`sendRawCommand` simplified** — Now a thin wrapper around `send()`. No timeout, no echo. `AppState.sendLLDBCommand` manages the `(lldb)` prefix and appends the response.
- **`findTextSection` now caches** — Like `findDataSection`, cached after first lookup.
- **`LLDBSession` output path** — Only forwards to controller parser. Termination message uses the separate `outputHandler`.

---

## 2026-03-08 — Move debugger controls to editor header and console output to separate window

### Changed
- **Debugger control bar** — Moved `DebuggerControlBar` (Run/Pause/Stop/Step buttons) from the LLDB tab into the code editor's header bar, inline next to the language label and quick action buttons. Removed the bar's own background and padding so it integrates with the existing header.
- **Console output window** — The tabbed console (Build Output, Terminal, LLDB) is now displayed in a separate macOS window instead of being embedded in the workspace. The output window opens automatically when building or debugging.
- **Workspace layout simplified** — The main workspace is now a two-level `VSplitView`: top has Tutorial | Code Editor | Segment Panel; bottom has MemoryStrip (Registers, Stack, Heap). The console is no longer part of the workspace layout.
- **AppState ownership** — `AppState` is now owned at the `ARM64LearnApp` level (`@StateObject` in the `App` struct) and injected via `.environmentObject()` into both the main `WindowGroup` and the output `Window`. Previously owned by `AppRootView`.

### Added
- **OutputWindowView** (`Views/BottomPanel/OutputWindowView.swift`) — Wrapper view for `BottomPanelView` displayed in the output window.
- **Output window scene** — `Window("Output", id: "output-window")` added to `ARM64LearnApp` with default size 800×400.
- **Output window toolbar button** — Terminal icon button (`⌘⌥2`) in the toolbar opens the output window.
- **Auto-open on build/debug** — Build & Run, Debug buttons, and keyboard shortcut handlers call `openWindow(id: "output-window")` automatically.

### Removed
- `DebuggerControlBar` from `LLDBDebuggerView` body — now lives in `CodeEditorView` header.
- Console panel from workspace split views — moved to separate window.

---

## 2026-03-08 — Restructure workspace layout into nested split with always-visible memory panels

### Changed
- **Workspace layout** — Replaced the old HSplitView + fixed-height bottom panel with a nested split layout using `VSplitView` and `HSplitView`.
- **Top area** — `HSplitView`: Tutorial Content (togglable) | inner `VSplitView` containing:
  - **Upper**: `HSplitView` of Code Editor + Segment Panel (__DATA/__TEXT stacked vertically)
  - **Lower**: Tabbed Console (Build Output, Terminal, LLDB) spanning the full width of the editor and segment panel
- **Bottom area** — Memory Strip (Registers, Stack, Heap all visible side-by-side) at full window width.
- **BottomPanelTab** — Reduced from 7 tabs (Build, Terminal, LLDB, Stack, Heap, Data, Text) to 3 tabs (Build, Terminal, LLDB). Memory views are no longer tabs.
- **WorkspaceToolbar** — Removed register panel and bottom panel toggle buttons. Only the tutorial panel toggle remains.

### Added
- **SegmentPanelView** (`Views/BottomPanel/SegmentPanelView.swift`) — New `VSplitView` containing __DATA hex dump (top) and __TEXT hex dump (bottom) in the top-right area.
- **MemoryStripView** (`Views/BottomPanel/MemoryStripView.swift`) — New `HSplitView` displaying Registers, Stack, and Heap side-by-side at the bottom. All three are always visible simultaneously.

### Removed
- `AppState.registerPanelVisible` — Registers are always visible in the Memory Strip.
- `AppState.bottomPanelVisible` — All panels are always visible (resizable via split views).
- `AppState.bottomPanelHeight` — No longer needed; VSplitView handles sizing.
- `BottomPanelTab.stack`, `.heap`, `.data`, `.text` cases — These views are now always-visible panels, not tabs.

---

## 2026-03-08 — Optimize TEXT and DATA section parsing to skip empty container space

### Changed
- **TEXT section memory reading** — Now finds and combines only the actual subsections (`__text`, `__stubs`, `__const`, `__cstring`, etc.) instead of reading the entire container. This avoids displaying large regions of zeros that pad the container but aren't used.
- **DATA section memory reading** — Similarly optimized to combine only actual subsections (`__data`, `__bss`, `__common`) instead of the full container.
- `LLDBOutputParser.parseTextSection()` — Uses regex to find all TEXT subsections, calculates the range from the first subsection start to the last subsection end, combining only the used portions.
- `LLDBOutputParser.parseDataSection()` — Uses regex to find all DATA subsections and combines their ranges.
- Regex pattern matches section types: `code`, `data`, `zero_fill`, `common`, `compact_unwind`, `literal_pointers`, `cstring_literals`, `symbols`, `unwind_info`.

### Result
For example, if the TEXT container is `0x0000000100000000-0x0000000100004000` (16 KB) but only `__text` (`0x100000458-0x100000478`) and `__stubs` (`0x100000478-0x100000484`) are present, the view now shows only `0x100000458-0x100000484` (44 bytes) instead of 16 KB of mostly zeros.

---

## 2026-03-08 — Fix TEXT and DATA section parsing to capture full containers

### Fixed
- **Incomplete TEXT section display** — Changed `parseTextSection()` to match the `__TEXT` container instead of just `__TEXT.__text`, ensuring all subsections (`.text`, `.stubs`, `.const`, `.cstring`, etc.) are included in the memory view.
- **Incomplete DATA section display** — Changed `parseDataSection()` to match the `__DATA` container instead of just `__DATA.__data`, capturing all subsections (`.data`, `.bss`, `.common`, etc.).
- Regex pattern updated from matching `code` type to matching `container` type.
- Pattern now matches lines ending with `.__TEXT\s*$` and `.__DATA\s*$` to avoid matching subsections.

### Changed
- `LLDBOutputParser.parseTextSection()` — Now parses the entire `__TEXT` container (e.g., `0x0000000100000000-0x0000000100004000`) instead of just the `__text` code subsection.
- `LLDBOutputParser.parseDataSection()` — Now parses the entire `__DATA` container instead of just the `__data` subsection.

---

## 2026-03-08 — Fix address formatting in memory views

### Fixed
- **Address display truncation** — Changed format specifier from `%011X` to `%016llX` to display all 16 hex digits of 64-bit addresses. Previously, addresses like `0x0000000100008000` were incorrectly displayed as `0x00000008000`.
- `StackQuadwordRow` in `MemoryHexDumpView.swift` — Address format updated and width increased from 100pt to 140pt.
- `MemorySegment.formattedStart` and `formattedEnd` in `MemoryState.swift` — Fixed to show full 64-bit addresses.

### Changed
- **Address prefix removed** — Memory view addresses no longer show the `0x` prefix (now displays `0000000100008000:` instead of `0x0000000100008000:`). The header still uses the format returned by `formattedStart`/`formattedEnd`.

---

## 2026-03-08 — Remove line wrapping from console views

### Changed
- **ConsoleOutputView** — Set `widthTracksTextView = false` on the text container to disable line wrapping and enable horizontal scrolling in all console output views (Build Output, LLDB, Terminal).
- `NSTextContainer` now uses `CGFloat.greatestFiniteMagnitude` for width, allowing text to extend horizontally without wrapping.
- Horizontal scrollbar is now visible and auto-hides when not needed.

### Added
- **ConsoleOutputView.swift** — New shared `NSViewRepresentable` component for displaying scrollable monospaced console text with horizontal scrolling support.
- **BuildOutputView.swift** — Wraps `ConsoleOutputView` with `appState.buildOutput`.
- **TerminalPanelView.swift** — Terminal output view with input row, using `ConsoleOutputView`.

---

## 2026-03-08 — Live text section memory view

### Added
- **Live text section memory tab** — `LLDBController.refreshState()` now reads the __TEXT.__text section after every step using `image dump sections` to find the section dynamically, then reads its contents with `memory read`. Parsed quadword entries are stored in `AppState.liveTextEntries`.
- **Text section parser** — `LLDBOutputParser.parseTextSection()` parses `image dump sections` output to locate the __TEXT.__text section address and size.
- **Text section callback** — `LLDBController.onTextMemoryUpdated` callback added and wired to `AppState` in `compileAndDebug()`.
- **Text tab display** — The Text tab in `MemoryHexDumpView` now shows `LiveStackDumpContent` (green-bannered live view) when `liveTextEntries` are present, displaying machine code bytes in the same hex/ASCII format as Stack and Data tabs.
- Text section preview added to `MemoryHexDumpView` showing sample ARM64 machine code.

### Changed
- `LiveStackDumpContent.segmentName` computation updated to detect text section addresses (0x100000000 range) and display "text section" in the header.

---

## 2026-03-09 — Fix three LLDB debugger integration bugs

### Fixed

- **Initial panels empty after launch** (`LLDBController.swift`): `findDataSection()` was ignoring its declared `cachedDataSection` field and re-issuing `image dump sections` on every `refreshState()` call. That slow command would hit the 5-second `sendAndAwait` timeout before the data arrived. Fixed by populating the cache on first successful lookup. `image dump sections` is now only ever sent once per debugging session.

- **Deferred refresh output appearing after bad command** (`LLDBController.swift`): All internal refresh commands (`register read`, `bt 1`, `memory read $sp`, `image dump sections`) were echoed to the user's LLDB console via `sendAndAwait` and `receiveOutput`. When they timed out their LLDB responses arrived late, appearing in the console alongside the next user command. Fixed by:
  - Adding `sendInternal()` — a silent, no-echo, no-timeout variant used exclusively by `refreshState()` and `findDataSection()`.
  - Removing the blanket `forwardToDisplay` call from `receiveOutput()`. Console output is now forwarded explicitly: command echoes in `sendAndAwait`, and stop-reason responses after `continueExecution()` and `issueStepCommand()`.

- **False "Program stdin" UI** (`LLDBController.swift`, `AppState.swift`, `LLDBDebuggerView.swift`): `lldbIsRunning` (`sessionState == .running`) was used to decide whether to show `ProgramInputRow`. That state is set during the automated launch sequence and every step command, not only when the user explicitly continued execution. Added `inferiorNeedsInput: Bool` to `LLDBController`, set `true` only in `continueExecution()` and cleared by `handleStopResponse()`, process termination, and `terminate()`. `LLDBDebuggerView` now uses `lldbInferiorNeedsInput` (backed by that flag) instead of `lldbIsRunning`.

---

## 2026-03-08 — Repository restructure to standard Xcode project layout

### Changed
- **`ARM64Learn.xcodeproj/`** moved to the repository root (was `ARM64Learn/ARM64Learn.xcodeproj/`). Open with `open ARM64Learn.xcodeproj`.
- **`ARM64Learn/`** is now the sole source directory at the root. Subdirectories reorganised:
  - `App/` — `ARM64LearnApp.swift`, `ContentView.swift` (app entry point and root view)
  - `ViewModels/` — `AppState.swift` (was `ARM64Learn/ARM64Learn/AppState.swift`)
  - `Models/`, `Views/`, `Services/` — same contents, now inside `ARM64Learn/`
  - `Resources/` — `Assets.xcassets` moved here from `ARM64Learn/ARM64Learn/`; `Tutorials/` unchanged
- **`ARM64LearnTests/`** and **`ARM64LearnUITests/`** moved to the repository root (were inside `ARM64Learn/`).
- **`project.pbxproj`** simplified: removed all explicit `PBXFileReference`, `PBXBuildFile`, and `PBXGroup` entries for source files. A single `PBXFileSystemSynchronizedRootGroup` for `ARM64Learn/` now auto-discovers all app sources, resources, and assets.
- **`ARM64Learn/docs/`** deleted (18 stale fix-note files).
- **`ARM64Learn/CLAUDE.md`** deleted (root `CLAUDE.md` is the authoritative instructions file).

### Added
- **`.github/`** — CI/CD workflows (`ci.yml`, `release.yml`, `pr-lint.yml`), issue templates (bug report, feature request, config), `PULL_REQUEST_TEMPLATE.md`, `CODEOWNERS`, `dependabot.yml`.
- **`.gitignore`** — Xcode + macOS standard ignores, ARM64Learn temp directory.
- **`.editorconfig`** — Swift 4-space indentation, LF line endings, UTF-8.

---

## 2026-03-08 — LLDB enhancements: live stack, register diff chip, NZCV badges, breakpoint UI

**Commits:** `d74b372`

### Added
- **Live stack memory tab** — `LLDBController.refreshState()` now issues `memory read $sp --count 16 --size 8` after every step; parsed quadword entries are stored in `AppState.liveStackEntries`. The Stack tab shows `LiveStackDumpContent` (green-bannered live view) when entries are present, falling back to generated sample data when no debug session is active.
- **Register change annotation chip** — `AppState.lastRegisterChangeSummary` is built from `lastChangedRegisters` after each step (e.g. `x0: 0x2A  ·  sp: 0x16F…`). `LLDBDebuggerView` shows a yellow-tinted chip below the control bar while paused.
- **NZCV flag badges** — `RegisterPanelView.RegisterRowView` detects the `nzcv` register and renders `FlagBitsView` — four N/Z/C/V colored badges (lit = set, dimmed = clear, with tooltips) instead of a raw hex value.
- **Breakpoint gutter UI** — `LineNumberTextView` accepts `breakpoints: Set<Int>` and `onBreakpointToggle: ((Int) -> Void)?`. Clicking any gutter line calls `AppState.toggleBreakpoint(line:)` which sends `breakpoint set / breakpoint clear` to LLDB. Active breakpoints render a red `●` dot; the line number is tinted red.
- `AppState.activeBreakpoints: Set<Int>` and `AppState.toggleBreakpoint(line:)` added.
- `LLDBController.onMemoryUpdated` callback added.

---

## 2026-03-08 — README update

**Commits:** `adfddf0`

Updated `README.md` to document the register panel, NZCV badges, register change chip, breakpoint gutter, live stack tab, execution line indicator, all keyboard shortcuts, the bottom panel tabs, and the actual project directory structure.

---

## 2026-03-07 — Live debugger stepping with register/memory visualization

**Commits:** `4743ca0`

### Added
- `LLDBController` — prompt-delimited command/response correlator wrapping `LLDBSession`. Tracks `DebuggerSessionState`, `lastStopReason`, and fires `onRegistersUpdated` / `onFrameUpdated` / `onProcessTerminated` callbacks.
- `LLDBOutputParser` — static parsers for `register read`, `bt 1`, stop reason, and process exit detection using `NSRegularExpression`.
- `DebuggerControlBar` in `LLDBDebuggerView` — Run, Pause, Stop, Inst, Over, Into, Out step buttons with state-sensitive enable/disable and status dot.
- `ProgramInputRow` — alternative input row shown when the inferior is running (stdin forwarding).
- `AppState.currentExecutionLine` / `currentExecutionFile` — drives gutter arrow and execution line background in `SyntaxHighlightingStorage`.
- `AppState.lastChangedRegisters` / `applyRegisterUpdate` — diffs register values after each step; `RegisterRowView` shows yellow background for changed registers.
- `RegisterPanelView` with collapsible `General` / `Special` / `Flags` categories; hex/decimal toggle on click.
- `MemoryHexDumpView` and `HexDumpComponents` — xxd-style hex dump with address, hex bytes (16/row), and ASCII column; simulated data per segment type.

---

## Earlier — Layout refactor: registers right, memory bottom, xxd-style hex dump

**Commits:** `943d3a2`

- Moved register display from a floating overlay to a dedicated right-side panel.
- Moved memory visualization from a panel to the bottom panel as tabbed hex dump views (Stack, Heap, \_\_DATA, \_\_TEXT).
- Register list redesigned as a single scrollable list with collapsible category sections.

---

## Earlier — Xcode project conversion

**Commits:** `a816ba6`, `49ed709`

- Converted from Swift Package Manager layout to a full Xcode project (`ARM64Learn.xcodeproj`).
- Source files moved from `Sources/ARM64Learn/` to `ARM64Learn/` subdirectory groups.

---

## Earlier — Tutorial system: bundled Markdown resources

**Commits:** `e7d4218`, `164dd95`

- Tutorials moved from hardcoded Swift strings to Markdown files in `Resources/Tutorials/`.
- `TutorialLoader` updated to load exclusively from the app bundle; sample code embedded in Markdown files as fenced code blocks.

---

## Earlier — Line number gutter and no-wrap editor

**Commits:** `804abba`

- `LineNumberTextView` introduced as an `NSTextView` subclass drawing its own gutter.
- Horizontal scrolling enabled; text wrapping disabled.
- Sidebar changed to overlay mode (covers tutorial text) to preserve editor width.

---

## Initial release

**Commits:** `65fc68a`

- `ARM64Learn` macOS app created.
- 10 ARM64 assembly tutorials (01 Introduction through 10 C Interop).
- Code editor with ARM64/C syntax highlighting.
- Build & Run (`⌘B`) via `clang -arch arm64`.
- LLDB session via Build & Debug.
- Embedded terminal session.
- Memory segment visualization panel.
