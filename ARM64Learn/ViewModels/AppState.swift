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
    @Published var lldbController: LLDBController = LLDBController()

    // Debugger execution state
    @Published var currentExecutionLine: Int? = nil
    @Published var currentExecutionFile: String? = nil
    @Published var debugSourceFile: String? = nil  // Track the actual debug source file name
    @Published var lastChangedRegisters: Set<String> = []
    @Published var lastRegisterChangeSummary: String = ""
    @Published var liveStackEntries: [(address: UInt64, value: UInt64)] = []
    @Published var liveDataEntries: [(address: UInt64, value: UInt64)] = []
    @Published var liveTextEntries: [(address: UInt64, value: UInt64)] = []
    @Published var liveHeapData: [UInt8] = []
    @Published var liveDataSegmentData: [UInt8] = []
    @Published var liveTextSegmentData: [UInt8] = []
    @Published var activeBreakpoints: Set<Int> = []

    var debuggerState: DebuggerSessionState { lldbController.sessionState }
    var lldbIsPaused: Bool { lldbController.sessionState == .ready }
    var lldbIsRunning: Bool { lldbController.sessionState == .running }

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

            // Reset debugger state
            currentExecutionLine = nil
            currentExecutionFile = nil
            debugSourceFile = "source_debug.\(codeLanguage.fileExtension)"  // Track the debug source file
            lastChangedRegisters = []
            lastRegisterChangeSummary = ""
            liveStackEntries = []
            liveDataEntries = []
            liveTextEntries = []
            liveHeapData = []
            liveDataSegmentData = []
            liveTextSegmentData = []
            activeBreakpoints = []

            let session = LLDBSession(binaryPath: path)

            // Wire LLDBController (callbacks are already called on MainActor from controller)
            let controller = LLDBController()
            controller.forwardToDisplay = { [weak self] text in
                self?.lldbOutput += text
            }
            controller.onRegistersUpdated = { [weak self] values in
                self?.applyRegisterUpdate(values)
            }
            controller.onFrameUpdated = { [weak self] frame in
                self?.applyFrameUpdate(frame)
            }
            controller.onProcessTerminated = { [weak self] _ in
                self?.currentExecutionLine = nil
                self?.liveStackEntries = []
                self?.liveDataEntries = []
                self?.liveTextEntries = []
                self?.lastRegisterChangeSummary = ""
            }
            controller.onStackMemoryUpdated = { [weak self] entries in
                self?.liveStackEntries = entries
            }
            controller.onDataMemoryUpdated = { [weak self] entries in
                self?.liveDataEntries = entries
            }
            controller.onTextMemoryUpdated = { [weak self] entries in
                self?.liveTextEntries = entries
            }

            controller.attach(to: session)
            await session.start()
            lldbSession = session
            lldbController = controller

            await controller.launchAndBreakAtMain(
                breakpointLines: Array(activeBreakpoints),
                sourceFile: debugSourceFile
            )
        } else {
            lldbOutput = "Build failed. Fix errors before debugging.\n\n" + output
            activeBottomTab = .output
        }
        isCompiling = false
    }

    // MARK: - Register & Frame Updates

    func applyRegisterUpdate(_ values: [String: UInt64]) {
        let prev = Dictionary(uniqueKeysWithValues: memoryState.registers.map { ($0.name, $0.value) })
        lastChangedRegisters = Set(values.keys.filter { values[$0] != prev[$0] })
        for i in memoryState.registers.indices {
            if let v = values[memoryState.registers[i].name] {
                memoryState.registers[i].value = v
                memoryState.registers[i].isChanged = lastChangedRegisters.contains(memoryState.registers[i].name)
            }
        }
    }

    func applyFrameUpdate(_ frame: ParsedFrame) {
        currentExecutionLine = frame.sourceLine
        currentExecutionFile = frame.sourceFile
        memoryState.stackFrames = [StackFrame(
            functionName: frame.symbol,
            returnAddress: frame.address,
            framePointer: memoryState.registers.first(where: { $0.name == "x29" })?.value ?? 0,
            savedRegisters: [],
            localVariables: []
        )]
    }

    // MARK: - Step Controls

    func stepInstruction() {
        Task { await lldbController.stepInstruction() }
    }

    func stepOver() {
        Task { await lldbController.stepOver() }
    }

    func stepInto() {
        Task { await lldbController.stepInto() }
    }

    func stepOut() {
        Task { await lldbController.stepOut() }
    }

    func continueExecution() {
        Task { await lldbController.continueExecution() }
    }

    func pauseExecution() {
        lldbController.pause()
    }

    func terminateDebugger() {
        lldbController.terminate()
        lldbSession = nil
        currentExecutionLine = nil
    }

    // MARK: - Breakpoints

    func toggleBreakpoint(line: Int) {
        // Use the debug source file name if available, otherwise fall back
        let file = debugSourceFile ?? "source_debug.\(codeLanguage.fileExtension)"
        
        if activeBreakpoints.contains(line) {
            activeBreakpoints.remove(line)
            Task {
                await lldbController.removeBreakpoint(file: file, line: line)
            }
        } else {
            activeBreakpoints.insert(line)
            Task {
                await lldbController.addBreakpoint(file: file, line: line)
            }
        }
    }

    // MARK: - LLDB Commands

    func sendLLDBCommand(_ command: String) {
        guard !command.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        lldbInputHistory.append(command)
        lldbOutput += "(lldb) \(command)\n"
        Task { await lldbController.sendRawCommand(command) }
    }

    func sendProgramInput(_ text: String) {
        lldbOutput += text + "\n"
        lldbController.sendProgramInput(text)
    }

    // MARK: - Terminal

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
