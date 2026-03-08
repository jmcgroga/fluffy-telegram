# ARM64Learn - Claude AI Assistant Instructions

## Project Overview

**ARM64Learn** is a macOS educational application for learning ARM64 assembly language and C programming with an integrated development environment, debugger, and interactive tutorials.

### Key Features
- Interactive ARM64 assembly and C code editor with syntax highlighting
- Integrated LLDB debugger with visual register and memory inspection
- Real-time memory visualization (Stack, Heap, Data, Text sections)
- Tutorial system with categorized lessons
- Terminal integration for running compiled programs
- Step-by-step debugging with breakpoint support

---

## 🚨 IMPORTANT: Documentation Policy

**ALL documentation files MUST be created in the `docs/` directory.**

### Rules for Documentation
1. ✅ **DO**: Create all `.md` documentation files in `docs/`
   - Example: `docs/FIX_SUMMARY.md`, `docs/ARCHITECTURE.md`, etc.

2. ❌ **DO NOT**: Create documentation files in the project root
   - Exceptions: `README.md`, `CLAUDE.md` (this file)

3. 📋 **When creating fix/feature documentation**:
   - Create in `docs/` with descriptive names
   - Use prefixes: `FIX_`, `FEATURE_`, `GUIDE_`, `ARCHITECTURE_`
   - Link from README.md if it's important reference material

4. 🧹 **Cleanup**: If documentation already exists in root, suggest moving it to `docs/`

---

## Project Architecture

### Core Components

#### 1. **AppState** (`AppState.swift`)
- Central state management for the entire application
- Manages tutorial selection, code editing, compilation, and debugging
- Publishes state changes to SwiftUI views via `@Published` properties
- Coordinates between LLDBController, ProcessRunner, and UI components

**Key Published Properties:**
- `currentCode: String` - Code in the editor
- `codeLanguage: CodeLanguage` - `.arm64` or `.c`
- `memoryState: MemoryState` - Registers and memory segments
- `liveStackEntries: [(address: UInt64, value: UInt64)]` - Live stack memory
- `liveDataEntries: [(address: UInt64, value: UInt64)]` - Live data section memory
- `lldbController: LLDBController` - Debugger controller
- `currentExecutionLine: Int?` - Current line during debugging
- `activeBreakpoints: Set<Int>` - User-set breakpoints

#### 2. **LLDBController** (`LLDBController.swift`)
- Manages LLDB debugger interaction via `LLDBSession`
- Parses LLDB output for registers, frames, memory, and execution state
- Provides high-level debugging commands (step, continue, breakpoints)
- Implements separate callback architecture for different memory types

**Key Features:**
- ✅ **Separate memory callbacks**: `onStackMemoryUpdated`, `onDataMemoryUpdated`
- Auto-refreshes registers and memory after each step
- Dynamic data section discovery using `image dump sections`
- Prompt-delimited command/response correlation
- Process exit detection and state management

**Callback Architecture:**
```swift
var onRegistersUpdated: (([String: UInt64]) -> Void)?
var onFrameUpdated: ((ParsedFrame) -> Void)?
var onProcessTerminated: ((Int32) -> Void)?
var onStackMemoryUpdated: (( [(address: UInt64, value: UInt64)] ) -> Void)?
var onDataMemoryUpdated: (( [(address: UInt64, value: UInt64)] ) -> Void)?
var forwardToDisplay: ((String) -> Void)?
```

#### 3. **MemoryState** (`MemoryState.swift`)
- Data model for ARM64 registers and memory segments
- Defines register types: general purpose (x0-x30), special (sp, pc, lr, fp), flags (nzcv, fpsr)
- Memory segments: STACK, HEAP, __DATA, __TEXT
- Tracks register value changes for highlighting in UI

#### 4. **ProcessRunner** (`ProcessRunner.swift`)
- Compiles ARM64 assembly and C code using system tools (clang)
- Manages temporary files for source code and binaries
- Provides debug symbol compilation for LLDB integration

#### 5. **Tutorial System** (`TutorialLoader.swift`)
- Loads tutorials from `Resources/Tutorials/` directory
- Parses `catalog.json` for categories and tutorial metadata
- Reads markdown content (`.md`) and sample code (`.s`, `.c`) files
- Auto-detects bundle structure (Resources/Tutorials, Tutorials, or root)

### UI Architecture

#### Main Views
- **ContentView** - Root view with three-panel layout
- **TutorialSidebarView** - Left panel with tutorial categories
- **CodeEditorView** - Center panel with syntax-highlighted editor
- **RegisterPanelView** - Right panel showing ARM64 registers
- **BottomPanelView** - Bottom panel with tabs (Output, LLDB, Terminal, Memory)

#### Memory Visualization
- **MemoryHexDumpView** - Displays hex/ASCII dump of memory regions
- **LiveStackDumpContent** - Shows live quadword memory entries
- **StackQuadwordRow** - Individual 8-byte memory row display

#### Debugger Controls
- **DebuggerControls** - Step, continue, pause, terminate buttons
- **BreakpointGutter** - Gutter in code editor for setting breakpoints

---

## Key Workflows

### 1. Build and Run Workflow
```
User presses ⌘B
↓
AppState.compileCode()
↓
ProcessRunner.compile()
↓
Writes code to temp file → Runs clang → Captures output
↓
Updates buildOutput → Displays in Build Output tab
```

### 2. Debug Workflow
```
User presses ⌘⇧B
↓
AppState.compileAndDebug()
↓
ProcessRunner.compileWithDebugSymbols()
↓
Creates LLDBSession with binary path
↓
LLDBController.attach() and launchAndBreakAtMain()
↓
LLDB breaks at _main
↓
refreshState() reads registers, frame, stack, data memory
↓
Callbacks update AppState (onRegistersUpdated, onStackMemoryUpdated, etc.)
↓
UI updates to show current line, register values, memory contents
```

### 3. Memory Visualization Workflow
```
LLDBController.refreshState() after each step:
  ├─ memory read $sp → Stack entries
  │   └─ onStackMemoryUpdated?(stackEntries)
  │       └─ AppState.liveStackEntries = stackEntries
  │           └─ MemoryHexDumpView(segmentName: "STACK") displays them
  │
  └─ memory read 0x<data_addr> → Data entries
      └─ onDataMemoryUpdated?(dataEntries)
          └─ AppState.liveDataEntries = dataEntries
              └─ MemoryHexDumpView(segmentName: "__DATA") displays them
```

---

## Common Issues and Solutions

### 1. Stack and Data Views Showing Same Content
**Status:** ✅ Fixed (March 7, 2026)

**Problem:** Both memory tabs displayed data section content.

**Solution:** Implemented separate callback architecture in `LLDBController`:
- `onStackMemoryUpdated` for stack memory from `memory read $sp`
- `onDataMemoryUpdated` for data section from `memory read 0x<address>`
- Removed address-based heuristics in `AppState`

**See:** `docs/FIX_SUMMARY.md`, `docs/FIX_COMPLETE.md`

### 2. Tutorial Files Not Loading
**Problem:** Catalog or tutorial files not found in bundle.

**Solution:**
1. Add `Resources/` or `Tutorials/` folder as **folder reference** (blue folder) in Xcode
2. Ensure "Create folder references" is selected (NOT "Create groups")
3. Verify in Build Phases → Copy Bundle Resources
4. Check console output for detected path

**See:** `README.md` section "Adding a New Tutorial"

### 3. LLDB Output Mixing or Duplication
**Problem:** Command responses mix with subsequent output.

**Solution:**
- Use prompt-delimited buffering in `LLDBController.receiveOutput()`
- Echo commands to display before sending
- Await initial prompt after `target create` auto-command
- Proper command sequencing in `launchAndBreakAtMain()`

---

## Code Style Guidelines

### Swift Conventions
1. **Use Swift Concurrency** (async/await, actors) over Dispatch or Combine
2. **@MainActor for UI updates** - Mark UI-related methods with `@MainActor`
3. **Weak self in closures** - Prevent retain cycles: `[weak self]`
4. **Published properties** in `@ObservableObject` classes
5. **Environment objects** for shared state: `@EnvironmentObject var appState: AppState`

### SwiftUI Patterns
1. **Composition over monoliths** - Break views into smaller components
2. **View extensions** for reusable modifiers
3. **Previews** for all views with sample data
4. **Computed properties** for derived state (not stored properties)

### Naming
- **Views**: `*View` suffix (e.g., `CodeEditorView`)
- **Controllers**: `*Controller` suffix (e.g., `LLDBController`)
- **State**: `*State` suffix (e.g., `AppState`, `MemoryState`)
- **Callbacks**: `on*` prefix (e.g., `onRegistersUpdated`)
- **Boolean properties**: `is*` or `has*` prefix (e.g., `isCompiling`, `hasBreakpoint`)

---

## Testing and Debugging

### Manual Testing Workflow
1. Build with ⌘B to check for compilation errors
2. Run with ⌘R to test UI functionality
3. Test debugger with sample ARM64 assembly:
   ```assembly
   .global _main
   .text
   _main:
       stp x29, x30, [sp, #-16]!
       mov x29, sp
       mov x0, #0
       ldp x29, x30, [sp], #16
       ret
   .data
   message: .asciz "Hello, World!"
   ```
4. Verify tabs: Stack, Data, LLDB output, Build output
5. Check console for error messages or warnings

### Debugging LLDB Issues
- Enable verbose logging in `LLDBController`
- Check `forwardToDisplay` callback output
- Verify command echo and response in LLDB tab
- Examine `outputBuffer` state in `receiveOutput()`

### Memory View Verification
- Stack should show high addresses (0x16XXXXXXXX)
- Data should show low addresses (0x100008XXX)
- ASCII column should show printable characters
- Addresses should be unique between tabs

---

## File Organization

```
ARM64Learn/
├── CLAUDE.md                    ← This file
├── README.md                    ← Tutorial system documentation
├── docs/                        ← ALL documentation goes here
│   ├── FIX_SUMMARY.md
│   ├── TESTING_GUIDE.md
│   └── ARCHITECTURE_*.md
├── ARM64Learn/
│   ├── ARM64LearnApp.swift     ← App entry point
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── CodeEditorView.swift
│   │   ├── RegisterPanelView.swift
│   │   ├── BottomPanelView.swift
│   │   └── Memory/
│   │       ├── MemoryHexDumpView.swift
│   │       └── HexDumpComponents.swift
│   ├── Models/
│   │   ├── AppState.swift
│   │   ├── MemoryState.swift
│   │   ├── Tutorial.swift
│   │   └── Register.swift
│   ├── Controllers/
│   │   ├── LLDBController.swift
│   │   └── ProcessRunner.swift
│   ├── Services/
│   │   ├── LLDBSession.swift
│   │   ├── TerminalSession.swift
│   │   └── TutorialLoader.swift
│   └── Resources/
│       └── Tutorials/
│           ├── catalog.json
│           ├── 01_introduction.json
│           ├── 01_introduction.md
│           ├── 01_introduction.s
│           └── ...
└── ARM64LearnTests/            ← Unit tests
```

---

## Adding New Features

### Adding a New Memory View (e.g., Text Section)

1. **Add callback to LLDBController**:
   ```swift
   var onTextMemoryUpdated: (( [(address: UInt64, value: UInt64)] ) -> Void)?
   ```

2. **Add section discovery method**:
   ```swift
   private func findTextSection() async -> (address: UInt64, size: UInt64)? {
       // Similar to findDataSection()
   }
   ```

3. **Update refreshState()**:
   ```swift
   if let textSection = await findTextSection() {
       let textMemOut = await sendAndAwait("memory read ...")
       let textEntries = LLDBOutputParser.parseMemoryRead(from: textMemOut)
       await MainActor.run {
           self.onTextMemoryUpdated?(textEntries)
       }
   }
   ```

4. **Wire up in AppState**:
   ```swift
   controller.onTextMemoryUpdated = { [weak self] entries in
       self?.liveTextEntries = entries
   }
   ```

5. **Update MemoryHexDumpView**:
   ```swift
   else if segmentName == "__TEXT", !appState.liveTextEntries.isEmpty {
       LiveStackDumpContent(entries: appState.liveTextEntries)
   }
   ```

### Adding a New Tutorial

See `README.md` section "Adding a New Tutorial" for complete instructions.

---

## Dependencies

- **SwiftUI** - UI framework
- **AppKit** (NSTask, NSPipe) - Process execution
- **Foundation** - File I/O, JSON parsing
- **System LLDB** - Located at `/usr/bin/lldb`
- **System Clang** - Located at `/usr/bin/clang`

---

## Build Configuration

- **Minimum macOS Version**: 13.0+
- **Architecture**: Apple Silicon (arm64) and Intel (x86_64)
- **Build System**: Xcode 15+
- **Swift Version**: 5.9+

---

## Resources for Claude

When helping with this project:

1. **Check existing docs first**: Look in `docs/` for relevant documentation
2. **Follow the architecture**: Use callbacks for async operations, separate concerns
3. **Create docs in `docs/`**: All new documentation files go in `docs/` directory
4. **Test with real ARM64 code**: Use sample assembly when testing debugger features
5. **Preserve working code**: Don't refactor working systems without user request
6. **Console output matters**: Check console for LLDB and tutorial loader messages

---

## Recent Changes

### March 7, 2026
- ✅ Fixed Stack/Data memory view duplication issue
- ✅ Implemented separate callback architecture in LLDBController
- ✅ Removed address-based heuristics from AppState
- ✅ Created comprehensive documentation in `docs/`
- 📝 Created this CLAUDE.md file

---

## Contact & Contribution

**Project Owner**: James McGrogan  
**Created**: March 7, 2026  
**Platform**: macOS  
**Language**: Swift + SwiftUI  

For architectural decisions or major changes, consult the project owner.

