//
//  ARM64LearnTests.swift
//  ARM64LearnTests
//
//  Created by James McGrogan on 3/1/26.
//

import Testing
@testable import ARM64Learn

// ============================================================
// MARK: - LLDBOutputParser: parseRegisters
// ============================================================

@Suite("LLDBOutputParser.parseRegisters")
struct ParseRegistersTests {

    @Test("parses standard general-purpose registers")
    func standardRegisters() {
        let output = """
               x0 = 0x0000000000000001
               x1 = 0x000000016fdff250
              x28 = 0xdeadbeefcafebabe
        """
        let result = LLDBOutputParser.parseRegisters(from: output)
        #expect(result["x0"] == 0x0000000000000001)
        #expect(result["x1"] == 0x000000016fdff250)
        #expect(result["x28"] == 0xdeadbeefcafebabe)
    }

    @Test("maps fp alias to x29")
    func fpAlias() {
        let output = "        fp = 0x000000016fdff3a0\n"
        let result = LLDBOutputParser.parseRegisters(from: output)
        #expect(result["x29"] == 0x000000016fdff3a0)
        #expect(result["fp"] == nil)
    }

    @Test("maps lr alias to x30")
    func lrAlias() {
        let output = "        lr = 0x0000000100003f84\n"
        let result = LLDBOutputParser.parseRegisters(from: output)
        #expect(result["x30"] == 0x0000000100003f84)
        #expect(result["lr"] == nil)
    }

    @Test("maps cpsr alias to nzcv")
    func cpsrAlias() {
        let output = "      cpsr = 0x60000000\n"
        let result = LLDBOutputParser.parseRegisters(from: output)
        #expect(result["nzcv"] == 0x60000000)
        #expect(result["cpsr"] == nil)
    }

    @Test("parses register with value zero")
    func zeroValue() {
        let output = "        x0 = 0x0000000000000000\n"
        let result = LLDBOutputParser.parseRegisters(from: output)
        #expect(result["x0"] == 0)
    }

    @Test("returns empty dictionary for empty input")
    func emptyInput() {
        let result = LLDBOutputParser.parseRegisters(from: "")
        #expect(result.isEmpty)
    }

    @Test("ignores lines without hex values")
    func noHexValue() {
        let output = "General Purpose Registers:\n        x0 = <unavailable>\n"
        let result = LLDBOutputParser.parseRegisters(from: output)
        #expect(result.isEmpty)
    }

    @Test("parses multiple registers in a block")
    func multipleRegisters() {
        let output = """
        General Purpose Registers:
               x0 = 0x0000000000000000
               x1 = 0x0000000100003f80
               x2 = 0x000000016fdff248
               sp = 0x000000016fdff220
               pc = 0x0000000100003f5c
        """
        let result = LLDBOutputParser.parseRegisters(from: output)
        #expect(result.count >= 5)
        #expect(result["x0"] == 0)
        #expect(result["x1"] == 0x0000000100003f80)
        #expect(result["sp"] == 0x000000016fdff220)
        #expect(result["pc"] == 0x0000000100003f5c)
    }
}

// ============================================================
// MARK: - LLDBOutputParser: parseBacktrace
// ============================================================

@Suite("LLDBOutputParser.parseBacktrace")
struct ParseBacktraceTests {

    @Test("parses frame with source file and line number")
    func frameWithSource() {
        let output = "  * frame #0: 0x0000000100003f5c prog`_main + 4 at hello.s:12"
        let frame = LLDBOutputParser.parseBacktrace(from: output)
        #expect(frame != nil)
        #expect(frame?.address == 0x0000000100003f5c)
        #expect(frame?.symbol == "_main")
        #expect(frame?.sourceFile == "hello.s")
        #expect(frame?.sourceLine == 12)
    }

    @Test("parses frame without source location")
    func frameWithoutSource() {
        let output = "  * frame #0: 0x0000000100003f80 prog`_main"
        let frame = LLDBOutputParser.parseBacktrace(from: output)
        #expect(frame != nil)
        #expect(frame?.address == 0x0000000100003f80)
        #expect(frame?.symbol == "_main")
        #expect(frame?.sourceFile == nil)
        #expect(frame?.sourceLine == nil)
    }

    @Test("returns nil for empty input")
    func emptyInput() {
        let frame = LLDBOutputParser.parseBacktrace(from: "")
        #expect(frame == nil)
    }

    @Test("returns nil for unrelated output")
    func unrelatedOutput() {
        let output = "error: no process\n"
        let frame = LLDBOutputParser.parseBacktrace(from: output)
        #expect(frame == nil)
    }

    @Test("propagates provided stop reason")
    func stopReasonPropagated() {
        let output = "  * frame #0: 0x0000000100003f5c prog`_main + 4 at hello.s:12"
        let frame = LLDBOutputParser.parseBacktrace(from: output, stopReason: "breakpoint 1.1")
        #expect(frame?.stopReason == "breakpoint 1.1")
    }

    @Test("uses 'stopped' as default stop reason")
    func defaultStopReason() {
        let output = "  * frame #0: 0x0000000100003f5c prog`_main"
        let frame = LLDBOutputParser.parseBacktrace(from: output, stopReason: "")
        #expect(frame?.stopReason == "stopped")
    }

    @Test("parses C source file extension")
    func cSourceFile() {
        let output = "  * frame #0: 0x0000000100003f5c prog`main + 4 at main.c:7"
        let frame = LLDBOutputParser.parseBacktrace(from: output)
        #expect(frame?.sourceFile == "main.c")
        #expect(frame?.sourceLine == 7)
    }
}

// ============================================================
// MARK: - LLDBOutputParser: parseStopReason
// ============================================================

@Suite("LLDBOutputParser.parseStopReason")
struct ParseStopReasonTests {

    @Test("parses breakpoint stop reason")
    func breakpointReason() {
        let output = """
        Process 12345 stopped
        * thread #1, queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
            frame #0: 0x0000000100003f80 prog`_main
        """
        let reason = LLDBOutputParser.parseStopReason(from: output)
        #expect(reason == "breakpoint 1.1")
    }

    @Test("parses instruction step stop reason")
    func instructionStepReason() {
        let output = "stop reason = instruction step into\n"
        let reason = LLDBOutputParser.parseStopReason(from: output)
        #expect(reason == "instruction step into")
    }

    @Test("parses step over stop reason")
    func stepOverReason() {
        let output = "stop reason = step over\n"
        let reason = LLDBOutputParser.parseStopReason(from: output)
        #expect(reason == "step over")
    }

    @Test("parses signal stop reason")
    func signalReason() {
        let output = "stop reason = signal SIGSEGV\n"
        let reason = LLDBOutputParser.parseStopReason(from: output)
        #expect(reason == "signal SIGSEGV")
    }

    @Test("returns nil for output with no stop reason")
    func noStopReason() {
        let output = "Current executable set to './a.out' (arm64).\n"
        let reason = LLDBOutputParser.parseStopReason(from: output)
        #expect(reason == nil)
    }

    @Test("returns nil for empty input")
    func emptyInput() {
        let reason = LLDBOutputParser.parseStopReason(from: "")
        #expect(reason == nil)
    }

    @Test("trims trailing whitespace from reason")
    func trimsWhitespace() {
        let output = "stop reason = breakpoint 2.3   \n"
        let reason = LLDBOutputParser.parseStopReason(from: output)
        #expect(reason == "breakpoint 2.3")
    }
}

// ============================================================
// MARK: - LLDBOutputParser: parseMemoryRead
// ============================================================

@Suite("LLDBOutputParser.parseMemoryRead")
struct ParseMemoryReadTests {

    @Test("parses a single row of 8 bytes (little-endian)")
    func singleRow() {
        // bytes: 0x50, 0xf4, 0xdf, 0x6f, 0x01, 0x00, 0x00, 0x00
        // little-endian UInt64 = 0x000000016fdff450
        let output = "0x16fdfedf0: {0x50 0xf4 0xdf 0x6f 0x01 0x00 0x00 0x00}\n"
        let entries = LLDBOutputParser.parseMemoryRead(from: output)
        #expect(entries.count == 1)
        #expect(entries[0].address == 0x16fdfedf0)
        #expect(entries[0].value == 0x000000016fdff450)
    }

    @Test("parses multiple rows in order")
    func multipleRows() {
        let output = """
        0x16fdfedf0: {0x01 0x00 0x00 0x00 0x00 0x00 0x00 0x00}
        0x16fdfedf8: {0x02 0x00 0x00 0x00 0x00 0x00 0x00 0x00}
        0x16fdfee00: {0x03 0x00 0x00 0x00 0x00 0x00 0x00 0x00}
        """
        let entries = LLDBOutputParser.parseMemoryRead(from: output)
        #expect(entries.count == 3)
        #expect(entries[0].value == 1)
        #expect(entries[1].value == 2)
        #expect(entries[2].value == 3)
    }

    @Test("all-zero bytes produce value zero")
    func allZeroBytes() {
        let output = "0x100008000: {0x00 0x00 0x00 0x00 0x00 0x00 0x00 0x00}\n"
        let entries = LLDBOutputParser.parseMemoryRead(from: output)
        #expect(entries.count == 1)
        #expect(entries[0].value == 0)
    }

    @Test("all-0xFF bytes produce UInt64.max")
    func allMaxBytes() {
        let output = "0x100008000: {0xff 0xff 0xff 0xff 0xff 0xff 0xff 0xff}\n"
        let entries = LLDBOutputParser.parseMemoryRead(from: output)
        #expect(entries.count == 1)
        #expect(entries[0].value == UInt64.max)
    }

    @Test("ignores rows with fewer than 8 bytes")
    func fewerThanEightBytes() {
        let output = "0x16fdfedf0: {0x01 0x02 0x03}\n"
        let entries = LLDBOutputParser.parseMemoryRead(from: output)
        #expect(entries.isEmpty)
    }

    @Test("returns empty for empty input")
    func emptyInput() {
        let entries = LLDBOutputParser.parseMemoryRead(from: "")
        #expect(entries.isEmpty)
    }

    @Test("returns empty for unrelated output")
    func unrelatedOutput() {
        let output = "error: no process to read memory\n"
        let entries = LLDBOutputParser.parseMemoryRead(from: output)
        #expect(entries.isEmpty)
    }
}

// ============================================================
// MARK: - LLDBOutputParser: detectProcessExit
// ============================================================

@Suite("LLDBOutputParser.detectProcessExit")
struct DetectProcessExitTests {

    @Test("detects exit code 0")
    func exitCodeZero() {
        let output = "Process 12345 exited with status = 0\n"
        let code = LLDBOutputParser.detectProcessExit(in: output)
        #expect(code == 0)
    }

    @Test("detects non-zero exit code")
    func nonZeroExitCode() {
        let output = "Process 12345 exited with status = 1\n"
        let code = LLDBOutputParser.detectProcessExit(in: output)
        #expect(code == 1)
    }

    @Test("detects large exit code")
    func largeExitCode() {
        let output = "Process 99 exited with status = 127\n"
        let code = LLDBOutputParser.detectProcessExit(in: output)
        #expect(code == 127)
    }

    @Test("returns nil when no exit in output")
    func noExit() {
        let output = "Process 12345 stopped\n* thread #1, stop reason = breakpoint 1.1\n"
        let code = LLDBOutputParser.detectProcessExit(in: output)
        #expect(code == nil)
    }

    @Test("returns nil for empty input")
    func emptyInput() {
        let code = LLDBOutputParser.detectProcessExit(in: "")
        #expect(code == nil)
    }

    @Test("detects exit embedded in larger output block")
    func exitEmbeddedInBlock() {
        let output = """
        (lldb) process continue
        Process 12345 resuming
        Hello, World!
        Process 12345 exited with status = 0
        """
        let code = LLDBOutputParser.detectProcessExit(in: output)
        #expect(code == 0)
    }

    @Test("does not match partial 'exited' word")
    func partialMatch() {
        let output = "Process exited abnormally without status\n"
        let code = LLDBOutputParser.detectProcessExit(in: output)
        #expect(code == nil)
    }
}

// ============================================================
// MARK: - LLDBOutputParser: parseDataSection
// ============================================================

@Suite("LLDBOutputParser.parseDataSection")
struct ParseDataSectionTests {

    static let singleSection = """
    Sections for '/tmp/ARM64Learn/output_debug' (arm64):
      SectID     Type             Load Address                             Perm File Off.  File Size  Flags      Section Name
      ---------- ---------------- ---------------------------------------  ---- ---------- ---------- ---------- ----------------------------
      0x00000001 container        [0x0000000100000000-0x0000000100008020)  ---  0x00000000 0x00008020 0x00000000 output_debug.__TEXT
      0x00000002 code             [0x0000000100003f60-0x0000000100003f84)  r-x  0x00003f60 0x00000024 0x80000400 output_debug.__TEXT.__text
      0x00000003 container        [0x0000000100008000-0x0000000100008020)  ---  0x00008000 0x00000020 0x00000000 output_debug.__DATA
      0x00000004 data             [0x0000000100008000-0x0000000100008014)  rw-  0x00008000 0x00000014 0x00000000 output_debug.__DATA.__data
    """

    static let multipleSections = """
      0x00000004 data             [0x0000000100008000-0x0000000100008014)  rw-  0x00008000 0x00000014 0x00000000 output_debug.__DATA.__data
      0x00000005 zero_fill        [0x0000000100008014-0x0000000100008020)  rw-  0x00008014 0x0000000c 0x00000001 output_debug.__DATA.__bss
    """

    @Test("parses a single __DATA.__data subsection")
    func singleDataSection() {
        let result = LLDBOutputParser.parseDataSection(from: Self.singleSection)
        #expect(result != nil)
        #expect(result?.address == 0x0000000100008000)
        #expect(result?.size == 0x14)
    }

    @Test("combines multiple __DATA subsections into one range")
    func multipleDataSections() {
        let result = LLDBOutputParser.parseDataSection(from: Self.multipleSections)
        #expect(result != nil)
        #expect(result?.address == 0x0000000100008000)
        // Combined: from 0x100008000 to end of __bss at 0x100008020
        #expect(result?.size == 0x20)
    }

    @Test("returns nil when no __DATA subsections exist")
    func noDataSection() {
        let output = """
          0x00000002 code  [0x0000000100003f60-0x0000000100003f84)  r-x  ... output_debug.__TEXT.__text
        """
        let result = LLDBOutputParser.parseDataSection(from: output)
        #expect(result == nil)
    }

    @Test("returns nil for empty input")
    func emptyInput() {
        let result = LLDBOutputParser.parseDataSection(from: "")
        #expect(result == nil)
    }
}

// ============================================================
// MARK: - LLDBOutputParser: parseTextSection
// ============================================================

@Suite("LLDBOutputParser.parseTextSection")
struct ParseTextSectionTests {

    static let singleTextSection = """
      0x00000002 code             [0x0000000100003f60-0x0000000100003f84)  r-x  0x00003f60 0x00000024 0x80000400 output_debug.__TEXT.__text
    """

    static let multipleTextSections = """
      0x00000002 code             [0x0000000100003f60-0x0000000100003f84)  r-x  0x00003f60 0x00000024 0x80000400 output_debug.__TEXT.__text
      0x00000003 code             [0x0000000100003f84-0x0000000100003f90)  r-x  0x00003f84 0x0000000c 0x80000408 output_debug.__TEXT.__stubs
    """

    @Test("parses a single __TEXT.__text subsection")
    func singleTextSection() {
        let result = LLDBOutputParser.parseTextSection(from: Self.singleTextSection)
        #expect(result != nil)
        #expect(result?.address == 0x0000000100003f60)
        #expect(result?.size == 0x24)
    }

    @Test("combines multiple __TEXT subsections into one range")
    func multipleTextSections() {
        let result = LLDBOutputParser.parseTextSection(from: Self.multipleTextSections)
        #expect(result != nil)
        #expect(result?.address == 0x0000000100003f60)
        // Combined: 0x100003f60 to 0x100003f90 = 0x30
        #expect(result?.size == 0x30)
    }

    @Test("returns nil when no __TEXT subsections exist")
    func noTextSection() {
        let output = "  0x00000004 data  [0x100008000-0x100008014)  rw-  ... output_debug.__DATA.__data\n"
        let result = LLDBOutputParser.parseTextSection(from: output)
        #expect(result == nil)
    }

    @Test("returns nil for empty input")
    func emptyInput() {
        let result = LLDBOutputParser.parseTextSection(from: "")
        #expect(result == nil)
    }
}

// ============================================================
// MARK: - LLDBController: Initial State
// ============================================================

@Suite("LLDBController initial state")
struct LLDBControllerInitialStateTests {

    @Test("sessionState starts as idle")
    func initialStateIsIdle() {
        let controller = LLDBController()
        #expect(controller.sessionState == .idle)
    }

    @Test("lastStopReason starts empty")
    func initialStopReasonEmpty() {
        let controller = LLDBController()
        #expect(controller.lastStopReason == "")
    }

    @Test("inferiorNeedsInput starts false")
    func initialInferiorNeedsInputFalse() {
        let controller = LLDBController()
        #expect(controller.inferiorNeedsInput == false)
    }
}

// ============================================================
// MARK: - LLDBController: attach() state transition
// ============================================================

@Suite("LLDBController.attach()")
struct LLDBControllerAttachTests {

    @Test("attach transitions state to launching")
    func attachTransitionsToLaunching() {
        let session = LLDBSession(binaryPath: "/fake/binary")
        let controller = LLDBController()
        controller.attach(to: session)
        #expect(controller.sessionState == .launching)
    }
}

// ============================================================
// MARK: - LLDBController: receiveOutput process exit
// ============================================================

@Suite("LLDBController.receiveOutput — process exit")
struct LLDBControllerProcessExitTests {

    // Flush all pending DispatchQueue.main.async work before asserting.
    // receiveOutput schedules state changes on the main dispatch queue, and since
    // MainActor uses the same queue, awaiting MainActor.run runs after those blocks.
    private func flushMain() async {
        await MainActor.run { }
    }

    @Test("receiveOutput fires onProcessTerminated for exit code 0")
    func exitZeroFiresCallback() async {
        let controller = LLDBController()
        var receivedCode: Int32? = nil
        controller.onProcessTerminated = { code in receivedCode = code }

        controller.receiveOutput("Process 12345 exited with status = 0\n")
        await flushMain()

        #expect(receivedCode == 0)
    }

    @Test("receiveOutput fires onProcessTerminated for non-zero exit code")
    func nonZeroExitFiresCallback() async {
        let controller = LLDBController()
        var receivedCode: Int32? = nil
        controller.onProcessTerminated = { code in receivedCode = code }

        controller.receiveOutput("Process 99 exited with status = 1\n")
        await flushMain()

        #expect(receivedCode == 1)
    }

    @Test("receiveOutput sets sessionState to terminated on process exit")
    func exitSetsTerminatedState() async {
        let controller = LLDBController()
        controller.receiveOutput("Process 12345 exited with status = 0\n")
        await flushMain()

        #expect(controller.sessionState == .terminated)
    }

    @Test("receiveOutput clears inferiorNeedsInput on process exit")
    func exitClearsInferiorNeedsInput() async {
        let controller = LLDBController()
        controller.receiveOutput("Process 12345 exited with status = 0\n")
        await flushMain()

        #expect(controller.inferiorNeedsInput == false)
    }

    @Test("receiveOutput does not fire callback for unrelated output")
    func noCallbackForNonExitOutput() async {
        let controller = LLDBController()
        var callbackFired = false
        controller.onProcessTerminated = { _ in callbackFired = true }

        controller.receiveOutput("Process 12345 stopped\n* thread #1, stop reason = breakpoint 1.1\n")
        await flushMain()

        #expect(callbackFired == false)
    }
}

// ============================================================
// MARK: - DebuggerSessionState: Equatable and labels
// ============================================================

@Suite("DebuggerSessionState")
struct DebuggerSessionStateTests {

    @Test("idle equals idle")
    func idleEquality() { #expect(DebuggerSessionState.idle == .idle) }

    @Test("launching equals launching")
    func launchingEquality() { #expect(DebuggerSessionState.launching == .launching) }

    @Test("ready equals ready")
    func readyEquality() { #expect(DebuggerSessionState.ready == .ready) }

    @Test("running equals running")
    func runningEquality() { #expect(DebuggerSessionState.running == .running) }

    @Test("terminated equals terminated")
    func terminatedEquality() { #expect(DebuggerSessionState.terminated == .terminated) }

    @Test("error with same message equals error")
    func errorEqualSameMessage() {
        #expect(DebuggerSessionState.error("oops") == .error("oops"))
    }

    @Test("error with different messages not equal")
    func errorDifferentMessages() {
        #expect(DebuggerSessionState.error("a") != .error("b"))
    }

    @Test("different states not equal")
    func differentStatesNotEqual() {
        #expect(DebuggerSessionState.idle != .ready)
        #expect(DebuggerSessionState.running != .terminated)
        #expect(DebuggerSessionState.launching != .waitingResponse)
    }

    @Test("labels are non-empty strings")
    func labelsNonEmpty() {
        let states: [DebuggerSessionState] = [
            .idle, .launching, .ready, .running, .waitingResponse, .terminated, .error("x")
        ]
        for state in states {
            #expect(!state.label.isEmpty)
        }
    }
}
