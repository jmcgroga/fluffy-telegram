# References

## ARM64 / AArch64 Architecture

- **ARM Architecture Reference Manual (ARMv8, for A-profile)** — canonical ISA reference including instruction encoding, register definitions, and PSTATE flags
  https://developer.arm.com/documentation/ddi0487/latest

- **ARM Procedure Call Standard for AArch64 (AAPCS64)** — calling convention: argument registers (x0–x7), callee-saved registers (x19–x28), frame pointer (x29), link register (x30), stack alignment
  https://github.com/ARM-software/abi-aa/blob/main/aapcs64/aapcs64.rst

- **PSTATE NZCV flags** — N (bit 31), Z (bit 30), C (bit 29), V (bit 28) in the condition flags register; set by comparison and arithmetic instructions
  https://developer.arm.com/documentation/ddi0595/2021-06/AArch64-Registers/NZCV--Condition-Flags

- **Apple Silicon ABI Addenda** — macOS-specific stack alignment, red zone, and `_main` entry point conventions
  https://developer.apple.com/documentation/xcode/writing-arm64-code-for-apple-platforms

## LLDB

- **LLDB Command Reference** — full list of debugger commands including `register read`, `memory read`, `breakpoint set`, `thread step-inst`, `bt`
  https://lldb.llvm.org/use/map.html

- **LLDB Python Scripting** — background on how LLDB formats output (used to write the regex parsers in `LLDBOutputParser`)
  https://lldb.llvm.org/use/python.html

- **`memory read` output format** — line format used by `LLDBOutputParser.parseMemoryRead`:
  `0x16fdef100: 0x000000016fdeffb8 0x0000000000000000`

- **`register read` output format** — line format used by `LLDBOutputParser.parseRegisters`:
  `       x0 = 0x0000000000000001`

- **`bt 1` output format** — line format used by `LLDBOutputParser.parseBacktrace`:
  `  * frame #0: 0x100003f5c prog\`_main + 4 at hello.s:12`

## Apple Frameworks

- **NSTextStorage / NSLayoutManager / NSTextContainer** — Cocoa text system underpinning `SyntaxHighlightingStorage` and `LineNumberTextView`
  https://developer.apple.com/documentation/appkit/nstextstorage

- **NSTextView** — base class for `LineNumberTextView`; `textContainerInset`, `drawsBackground`, `draw(_:)` override points used for the custom gutter
  https://developer.apple.com/documentation/appkit/nstextview

- **Process / Pipe** — used by `ProcessRunner`, `LLDBSession`, and `TerminalSession` to spawn and communicate with subprocesses
  https://developer.apple.com/documentation/foundation/process

- **SwiftUI `@EnvironmentObject`** — dependency injection mechanism used by all views to access `AppState`
  https://developer.apple.com/documentation/swiftui/environmentobject

- **`@MainActor`** — Swift concurrency annotation ensuring `AppState` mutations run on the main thread
  https://developer.apple.com/documentation/swift/mainactor

- **`xcrun --find clang` / `xcrun --find lldb`** — used to locate Xcode Command Line Tools binaries at runtime
  https://developer.apple.com/library/archive/technotes/tn2339/_index.html

## Xcode Project

- **Xcode project file (`project.pbxproj`) structure** — reference for manually adding files via `PBXFileReference`, `PBXBuildFile`, and `PBXGroup` entries when the Xcode GUI is not available
  https://www.mokacoding.com/blog/xcode-project-file-format/

- **`PBXFileSystemSynchronizedRootGroup`** — newer Xcode folder-sync groups (used for Views/BottomPanel, Views/Workspace, Views/Registers); files added to these directories are automatically included without modifying `project.pbxproj`
