# ARM64Learn

An interactive macOS IDE for learning ARM64 assembly language. Write ARM64 (or C) code, compile and run it instantly, step through it in LLDB, and follow structured tutorials — all in one app.

## Features

- **Structured tutorials** — 10 built-in lessons covering registers, memory addressing, data movement, arithmetic, logical operations, branches, the stack and functions, SIMD/NEON, and C interop
- **Live code editor** — Syntax-highlighted editor with ARM64 assembly and C support
- **One-click compile & run** — Compiles with `clang -arch arm64` via Xcode Command Line Tools and shows output immediately
- **Integrated LLDB debugger** — Build with debug symbols and drop into an interactive LLDB session without leaving the app
- **Embedded terminal** — Full login-shell terminal panel for running arbitrary commands
- **Memory visualization** — Diagram panel that highlights relevant memory segments for each tutorial

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

## Usage

| Action | Shortcut |
|--------|----------|
| Build & Run | `⌘B` |
| Build & Debug (LLDB) | `⌘⇧B` |

1. Pick a tutorial from the sidebar.
2. Read the lesson in the left panel and study the sample code in the editor.
3. Modify the code and press **Build & Run** to see the output in the bottom panel.
4. Press **Debug** to compile with debug symbols and open an interactive LLDB session.
5. Use the **Terminal** tab for a full shell alongside your code.

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

## Project Structure

```
ARM64Learn/
├── ARM64Learn/        # App source (AppState, ContentView, entry point)
├── Models/            # Tutorial and MemoryState data models
├── Views/             # SwiftUI view components
├── Services/          # Compilation, LLDB, terminal, syntax highlighting
└── Resources/
    └── Tutorials/     # Markdown lesson files
```

See [CLAUDE.md](CLAUDE.md) for detailed architecture and development notes.
