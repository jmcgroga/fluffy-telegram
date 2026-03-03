import SwiftUI
import Combine
import Foundation

// MARK: - Enums

enum CodeLanguage: String, CaseIterable, Identifiable {
    case arm64 = "ARM64 Assembly"
    case c = "C"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .arm64: return "s"
        case .c: return "c"
        }
    }

    var icon: String {
        switch self {
        case .arm64: return "cpu"
        case .c: return "c.circle"
        }
    }
}

enum BottomPanelTab: String, CaseIterable, Identifiable {
    case output = "Build Output"
    case terminal = "Terminal"
    case lldb = "LLDB"
    case stack = "Stack"
    case heap = "Heap"
    case data = "Data"
    case text = "Text"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .output: return "hammer"
        case .terminal: return "terminal"
        case .lldb: return "ant.circle"
        case .stack: return "square.stack.3d.down.right"
        case .heap: return "memorychip"
        case .data: return "tablecells"
        case .text: return "doc.text"
        }
    }
}

// MARK: - Code Samples

enum ARM64Samples {
    static let helloWorld = """
// ARM64 Assembly - Hello, World!
// Build: clang -arch arm64 hello.s -o hello && ./hello

.global _main
.align  2
.text

_main:
    // Prologue: save frame pointer and link register
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp

    // Load address of message string and print it
    adrp    x0, message@PAGE
    add     x0, x0, message@PAGEOFF
    bl      _puts

    // Return 0 (success)
    mov     x0, #0

    // Epilogue: restore frame pointer and link register
    ldp     x29, x30, [sp], #16
    ret

.data
message:
    .asciz  "Hello, World!"
"""
}

enum CSamples {
    static let helloWorld = """
#include <stdio.h>
#include <stdint.h>

int main(void) {
    printf("Hello, World!\\n");

    // Show ARM64 register-sized values
    uint64_t x_reg = 0xDEADBEEFCAFEBABE;
    uint32_t w_reg = (uint32_t)x_reg;

    printf("64-bit (x0): 0x%016llX\\n", x_reg);
    printf("32-bit (w0): 0x%08X\\n", w_reg);

    return 0;
}
"""
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    @Published var selectedTutorial: Tutorial?
    @Published var tutorialCategories: [TutorialCategory] = []
    @Published var currentCode: String = ""
    @Published var codeLanguage: CodeLanguage = .arm64
    @Published var memoryState: MemoryState = MemoryState()

    // Panel visibility
    @Published var tutorialPanelVisible: Bool = true
    @Published var registerPanelVisible: Bool = true
    @Published var bottomPanelVisible: Bool = true
    @Published var bottomPanelHeight: CGFloat = 300
    @Published var activeBottomTab: BottomPanelTab = .output

    // Build output
    @Published var buildOutput: String = "Ready to compile.\n\nPress ⌘B to build, or ⌘⇧B to build and launch debugger.\n"
    @Published var isCompiling: Bool = false

    // LLDB
    @Published var lldbOutput: String = "LLDB session not started.\n\nCompile with ⌘⇧B to build with debug symbols and launch LLDB.\n"
    @Published var lldbSession: LLDBSession?
    @Published var lldbInputHistory: [String] = []

    // Terminal
    @Published var terminalOutput: String = ""
    @Published var terminalSession: TerminalSession?

    init() {
        // Load tutorials from catalog
        tutorialCategories = TutorialLoader.loadTutorials()
        
        if let first = tutorialCategories.first?.tutorials.first {
            selectedTutorial = first
            currentCode = first.sampleCode ?? ARM64Samples.helloWorld
            codeLanguage = first.language
        } else {
            currentCode = ARM64Samples.helloWorld
        }
    }

    func selectTutorial(_ tutorial: Tutorial) {
        selectedTutorial = tutorial
        currentCode = tutorial.sampleCode ?? (tutorial.language == .arm64 ? ARM64Samples.helloWorld : CSamples.helloWorld)
        codeLanguage = tutorial.language
        memoryState = MemoryState(highlightedSegments: tutorial.memoryHighlights)
    }

    func compileCode() async {
        isCompiling = true
        bottomPanelVisible = true
        activeBottomTab = .output
        buildOutput = "Building \(codeLanguage == .arm64 ? "ARM64 Assembly" : "C") code...\n\n"

        let runner = ProcessRunner()
        let result = await runner.compile(code: currentCode, language: codeLanguage)
        buildOutput = result
        isCompiling = false
    }

    func compileAndDebug() async {
        isCompiling = true
        bottomPanelVisible = true
        activeBottomTab = .lldb
        buildOutput = "Building with debug symbols...\n"

        let runner = ProcessRunner()
        let (success, binaryPath, output) = await runner.compileWithDebugSymbols(
            code: currentCode,
            language: codeLanguage
        )

        buildOutput = output

        if success, let path = binaryPath {
            lldbOutput = "Starting LLDB session with binary: \(path)\n\n"
            let session = LLDBSession(binaryPath: path)
            session.outputHandler = { [weak self] text in
                self?.lldbOutput += text
            }
            await session.start()
            lldbSession = session
        } else {
            lldbOutput = "Build failed. Fix errors before debugging.\n\n" + output
            activeBottomTab = .output
        }
        isCompiling = false
    }

    func sendLLDBCommand(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        lldbInputHistory.append(command)
        lldbOutput += "(lldb) \(command)\n"
        lldbSession?.send(command + "\n")
    }

    func startTerminalIfNeeded() {
        guard terminalSession == nil else { return }
        let session = TerminalSession()
        session.outputHandler = { [weak self] text in
            self?.terminalOutput += text
        }
        session.start()
        terminalSession = session
    }

    func sendTerminalInput(_ input: String) {
        terminalSession?.send(input + "\n")
        terminalOutput += input + "\n"
    }
}
