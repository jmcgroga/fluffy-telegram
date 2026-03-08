# Changelog

Entries are newest first. Each entry covers one logical change set.

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
