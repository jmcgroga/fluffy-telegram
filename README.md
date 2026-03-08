# ARM64Learn

An interactive macOS IDE for learning ARM64 assembly language. Write ARM64 (or C) code, compile and run it instantly, step through it with a full LLDB debugger, and follow structured tutorials — all in one app.

## Features

### Editor
- **Syntax-highlighted code editor** — ARM64 assembly and C modes, switchable via a segmented control in the toolbar
- **Line number gutter** — Dark gutter with line numbers displayed alongside the code
- **Execution line indicator** — A green `▶` arrow highlights the current instruction during debugging
- **Breakpoint gutter** — Click any line number to toggle a breakpoint; active breakpoints show a red `●` dot and are sent to LLDB automatically

### Tutorials
- **10 built-in lessons** covering registers, memory addressing, data movement, arithmetic, logical operations, branches, the stack and functions, SIMD/NEON, and C interop
- Each tutorial loads sample code directly into the editor so you can run and modify it immediately
- The tutorial panel can be shown or hidden independently of the editor

### Compilation
- **One-click Build & Run** — Compiles with `clang -arch arm64` via Xcode Command Line Tools and streams output to the Build Output panel
- **Build & Debug** — Compiles with debug symbols and launches an LLDB session without leaving the app

### LLDB Debugger
- **Step controls** — Inst (single instruction), Over (step over), Into (step into), Out (step out), Continue, Pause, Stop
- **Live register panel** — All ARM64 registers grouped into collapsible categories (General, Special, Flags); changed registers are highlighted in yellow after each step; values toggle between hex and decimal on click
- **NZCV flag badges** — The `nzcv` register shows N / Z / C / V as colored badges (lit when set) instead of a raw hex value
- **Register change chip** — A summary bar below the step controls shows exactly which registers changed after the last step (e.g. `x0: 0x2A  ·  sp: 0x16F...`)
- **Raw LLDB console** — Full scrollable LLDB output with a command input row for arbitrary LLDB commands
- **Program stdin** — When the inferior is running and waiting for input, the input row switches to a program-input prompt

### Memory Panels
The bottom panel has four memory tabs that display an xxd-style hex dump:

| Tab | Contents |
|-----|----------|
| **Stack** | Live stack memory read from LLDB (`memory read $sp`) during a debug session; falls back to a simulated layout when no session is active |
| **Heap** | Simulated heap segment |
| **\_\_DATA** | Simulated data segment |
| **\_\_TEXT** | Simulated text segment with sample ARM64 instructions |

### Terminal
- **Embedded shell** — Full login-shell terminal panel (`$SHELL -l`) for running arbitrary commands alongside your code

## Layout

The app uses a resizable split-pane layout:

```
┌─ Tutorial list (sidebar) ──────────────────────────────────────────────────┐
│                                                                             │
│  ┌─ Tutorial content ─┐  ┌─ Code editor ──────┐  ┌─ Register panel ──┐   │
│  │                    │  │  (gutter + editor) │  │  General          │   │
│  │  Markdown lesson   │  │                    │  │  Special          │   │
│  │                    │  │                    │  │  Flags / NZCV     │   │
│  └────────────────────┘  └────────────────────┘  └───────────────────┘   │
│                           ┌─ Bottom panel ─────────────────────────────┐  │
│                           │  Output │ LLDB │ Terminal │ Stack │ …      │  │
│                           └────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

Each panel can be toggled independently from the toolbar.

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Build & Run | `⌘B` |
| Toggle tutorial list sidebar | `⌃⌘S` |
| Toggle tutorial panel | `⌥⌘1` |
| Toggle register panel | `⌥⌘2` |
| Toggle bottom panel | `⌥⌘3` |

## Requirements

- macOS 13 Ventura or later (Apple Silicon or Intel)
- Xcode 15 or later
- Xcode Command Line Tools (`xcode-select --install`)

## Getting Started

```bash
git clone https://github.com/jmcgroga/arm64-tutorial-ide.git
cd arm64-tutorial-ide
open ARM64Learn/ARM64Learn.xcodeproj
```

Select the **ARM64Learn** scheme, set the destination to **My Mac**, and press **⌘R**.

## Typical Workflow

1. Pick a tutorial from the sidebar.
2. Read the lesson in the tutorial panel; the sample code loads automatically into the editor.
3. Edit the code and press **Build & Run** (`⌘B`) to see the output.
4. Press **Debug** to compile with debug symbols and open an LLDB session.
5. Click line numbers in the gutter to set breakpoints before starting.
6. Use **Step** / **Over** / **Into** / **Out** to walk through instructions.
7. Watch the register panel for live values; changed registers are highlighted and a summary chip appears in the LLDB panel.
8. Switch to the **Stack** tab to inspect live stack memory at `$sp`.

## Tutorials

| # | Title |
|---|-------|
| 01 | Introduction to ARM64 |
| 02 | Registers |
| 03 | Memory Addressing |
| 04 | Data Movement |
| 05 | Arithmetic |
| 06 | Logical Operations |
| 07 | Branches & Control Flow |
| 08 | Stack & Functions |
| 09 | SIMD / NEON |
| 10 | Interfacing with C |

