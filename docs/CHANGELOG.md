# Changelog

Entries are newest first. Each entry covers one logical change set.

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
