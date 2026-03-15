import Foundation
import Combine

// MARK: - Debugger State

enum DebuggerSessionState: Equatable {
    case idle                   // No session; not started
    case launching              // LLDB process spawned; waiting for first prompt
    case ready                  // At breakpoint/step; user can issue commands
    case running                // Inferior process executing; may be blocked on stdin
    case waitingResponse        // Sent a command; buffering output until next prompt
    case terminated             // Process exited or LLDB was killed
    case error(String)          // LLDB not found, launch failure, etc.

    static func == (lhs: DebuggerSessionState, rhs: DebuggerSessionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.launching, .launching), (.ready, .ready),
             (.running, .running), (.waitingResponse, .waitingResponse),
             (.terminated, .terminated): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }

    var label: String {
        switch self {
        case .idle:            return "idle"
        case .launching:       return "launching…"
        case .ready:           return "ready"
        case .running:         return "running"
        case .waitingResponse: return "busy…"
        case .terminated:      return "terminated"
        case .error(let msg):  return "error: \(msg)"
        }
    }
}

// MARK: - Parsed Types

struct ParsedFrame {
    let address: UInt64
    let symbol: String        // e.g. "_main"
    let sourceFile: String?   // e.g. "hello.s"
    let sourceLine: Int?      // 1-based line number
    let stopReason: String    // e.g. "instruction step into"
}

// MARK: - LLDBController

/// Wraps an LLDBSession and provides:
///  - A prompt-delimited command/response correlator
///  - Automatic register + backtrace + stack-memory refresh after every stop
///  - Program stdin forwarding when the inferior is running
///
/// ## Command execution architecture
///
/// There is exactly ONE primitive for sending a command and getting its response:
///
///     `send(_ command:) async -> String`
///
/// It registers a continuation, sends the command, and awaits the `(lldb) ` prompt.
/// No timeout, no display, no side effects. Every higher-level method composes on top.
///
/// Display forwarding is opt-in at each call site via `display(_:)`.
final class LLDBController: ObservableObject {

    // MARK: Published state

    @Published private(set) var sessionState: DebuggerSessionState = .idle
    @Published private(set) var lastStopReason: String = ""
    /// True only while the inferior is executing after the user explicitly pressed Continue.
    /// Not set during the automated launch sequence or during step commands.
    @Published private(set) var inferiorNeedsInput: Bool = false

    // MARK: Callbacks → AppState

    var onRegistersUpdated: (([String: UInt64]) -> Void)?
    var onFrameUpdated: ((ParsedFrame) -> Void)?
    var onProcessTerminated: ((Int32) -> Void)?
    var onStackMemoryUpdated: (( [(address: UInt64, value: UInt64)] ) -> Void)?
    var onDataMemoryUpdated: (( [(address: UInt64, value: UInt64)] ) -> Void)?
    var onTextMemoryUpdated: (( [(address: UInt64, value: UInt64)] ) -> Void)?
    var onDisassemblyUpdated: (([DisassemblyLine]) -> Void)?
    /// Raw output forwarded to the console display (unchanged). Called on MainActor.
    var forwardToDisplay: ((String) -> Void)?

    // MARK: Private

    private weak var session: LLDBSession?
    private var outputBuffer = ""
    private let outputLock = NSLock()

    /// Each pending command carries its continuation, original command text, and
    /// either a UUID sentinel (for commands where LLDB stays in command mode) or a
    /// "wait for stop" flag (for commands that run the inferior).
    ///
    /// ## Two delimiter modes
    ///
    /// **Sentinel mode** (`waitForStop == false`, default):
    ///   After the real command we also send `script print("LLDB_DONE_UUID")`.
    ///   `receiveOutput` waits for `LLDB_DONE_UUID\n` — unambiguous regardless of
    ///   what the command outputs.
    ///
    /// **Stop-notification mode** (`waitForStop == true`):
    ///   Used by `continue`, `process continue`, and step commands. While the
    ///   inferior is running, LLDB reads bytes from its control pipe (our stdin)
    ///   and echoes them verbatim to output without executing them. Sending a
    ///   sentinel during this window means the sentinel bytes are consumed and
    ///   never executed, so `send()` hangs forever. Instead, NO sentinel is sent;
    ///   `receiveOutput` waits for `") stopped.\n"` — the last line of every LLDB
    ///   stop notification — as the natural response delimiter.
    private struct PendingCommand {
        let continuation: CheckedContinuation<String, Never>
        let command: String          // original command text (for echo stripping)
        let sentinelID: String       // UUID used in sentinel (ignored when waitForStop)
        let waitForStop: Bool        // true → detect stop notification; false → sentinel
        var sentinelOutput: String { "LLDB_DONE_\(sentinelID)\n" }
        var commandEcho: String { "(lldb) \(command)\n" }
        var sentinelCmdEcho: String { "(lldb) script print(\"LLDB_DONE_\(sentinelID)\")\n" }
    }
    private var promptContinuations: [PendingCommand] = []
    
    // Cache section info (doesn't change during execution)
    private var cachedDataSection: (address: UInt64, size: UInt64)? = nil
    private var cachedTextSection: (address: UInt64, size: UInt64)? = nil

    // The stack pointer value at the first stop after launch. The OS allocates the
    // stack region before the process starts, so this value is the fixed "ceiling"
    // of the user's stack. Comparing it against the current SP tells us exactly how
    // much stack has been allocated at any given point.
    private var stackBase: UInt64? = nil

    // Cache disassembly lines keyed by the base address of the disassembled function.
    // Source-line enrichment (image lookup per instruction) is expensive, so we only
    // run it once per function and reuse the result on subsequent steps.
    private var cachedDisassemblyBase: UInt64? = nil
    private var cachedDisassemblyLines: [DisassemblyLine] = []

    // MARK: - Attach

    func attach(to session: LLDBSession) {
        self.session = session
        sessionState = .launching
        cachedDataSection = nil
        cachedTextSection = nil
        cachedDisassemblyBase = nil
        cachedDisassemblyLines = []
        stackBase = nil
        session.controllerOutputHandler = { [weak self] chunk in
            self?.receiveOutput(chunk)
        }
    }

    // =========================================================================
    // MARK: - Primitive: send one command → get one response
    // =========================================================================

    /// Send a command and return its output. This is the ONLY way to execute
    /// an LLDB command. Does NOT echo to display. Does NOT timeout.
    ///
    /// - Parameter waitForStop: Pass `true` for commands that run the inferior
    ///   (`continue`, step commands). No sentinel is sent; `receiveOutput` resolves
    ///   the continuation when the stop notification arrives. Pass `false` (default)
    ///   for all other commands — a UUID sentinel is appended and used as the delimiter.
    private func send(_ command: String, waitForStop: Bool = false) async -> String {
        let sentinelID = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return await withCheckedContinuation { continuation in
            outputLock.lock()
            promptContinuations.append(PendingCommand(
                continuation: continuation,
                command: command,
                sentinelID: sentinelID,
                waitForStop: waitForStop
            ))
            session?.send(command + "\n")
            if !waitForStop {
                // Sentinel: LLDB will execute this after the real command and output
                // LLDB_DONE_UUID, which receiveOutput uses as the response delimiter.
                session?.send("script print(\"LLDB_DONE_\(sentinelID)\")\n")
            }
            // Both writes happen under the lock so receiveOutput cannot drain
            // stale data before the command is registered.
            outputLock.unlock()
        }
    }

    /// Append text to the user-visible LLDB console.
    private func display(_ text: String) async {
        await MainActor.run { forwardToDisplay?(text) }
    }

    // =========================================================================
    // MARK: - Output Buffering (called from LLDBSession's background reader)
    // =========================================================================

    /// Called by LLDBSession.controllerOutputHandler on every chunk of LLDB output.
    func receiveOutput(_ chunk: String) {
        outputLock.lock()
        outputBuffer += chunk
        
        // Check for process exit before prompt parsing
        if let code = LLDBOutputParser.detectProcessExit(in: outputBuffer) {
            let buffer = outputBuffer
            outputBuffer = ""
            let pending = promptContinuations
            promptContinuations = []
            outputLock.unlock()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.sessionState = .terminated
                self.inferiorNeedsInput = false
                self.onProcessTerminated?(code)
            }

            for p in pending {
                p.continuation.resume(returning: buffer)
            }
            return
        }

        // Drain responses that have a waiting continuation. Two delimiter modes:
        //
        // Sentinel mode (waitForStop == false):
        //   Wait for "LLDB_DONE_UUID\n" — only appears when LLDB executes the
        //   sentinel script command we appended after the real command.
        //
        // Stop-notification mode (waitForStop == true):
        //   Wait for ") stopped.\n" — the final line of every LLDB stop notification.
        //   No sentinel is sent for these commands because LLDB reads and echoes
        //   control-pipe bytes while the inferior runs, consuming any sentinel before
        //   executing it.
        var toResume: [(CheckedContinuation<String, Never>, String)] = []

        while !promptContinuations.isEmpty {
            let pending = promptContinuations[0]

            if pending.waitForStop {
                // Stop-notification mode: wait for the stop notification end marker.
                // Every LLDB stop notification ends with:
                //   Target N: (binary-name) stopped.\n
                // The closing paren + " stopped.\n" is the most specific part to match.
                guard let stopRange = outputBuffer.range(of: ") stopped.\n") else { break }

                var response = String(outputBuffer[outputBuffer.startIndex..<stopRange.upperBound])

                // Advance buffer. Skip any bare "(lldb) " prompt that may have already
                // arrived — it would be the prompt before the next command's echo.
                var remainder = outputBuffer[stopRange.upperBound...]
                if remainder.hasPrefix("(lldb) ") {
                    remainder = remainder.dropFirst("(lldb) ".count)
                }
                outputBuffer = String(remainder)

                // Strip command echo from start of response
                if response.hasPrefix(pending.commandEcho) {
                    response = String(response.dropFirst(pending.commandEcho.count))
                }

                toResume.append((promptContinuations.removeFirst().continuation, response))

            } else {
                // Sentinel mode: wait for "LLDB_DONE_UUID\n".
                guard let sentinelRange = outputBuffer.range(of: pending.sentinelOutput) else { break }

                // Everything before the sentinel is the raw output for this command.
                // It includes: (lldb) COMMAND\n, real output, (lldb) script print("ID")\n
                var response = String(outputBuffer[outputBuffer.startIndex..<sentinelRange.lowerBound])

                // Advance buffer past the sentinel line. Also strip any bare "(lldb) " prompt
                // that arrived in the same chunk — leave anything else intact.
                var remainder = outputBuffer[sentinelRange.upperBound...]
                if remainder.hasPrefix("(lldb) ") {
                    remainder = remainder.dropFirst("(lldb) ".count)
                }
                outputBuffer = String(remainder)

                // Strip command echo from start of response
                if response.hasPrefix(pending.commandEcho) {
                    response = String(response.dropFirst(pending.commandEcho.count))
                }
                // Strip sentinel command echo from end of response
                if response.hasSuffix(pending.sentinelCmdEcho) {
                    response = String(response.dropLast(pending.sentinelCmdEcho.count))
                }

                toResume.append((promptContinuations.removeFirst().continuation, response))
            }
        }

        outputLock.unlock()

        // Resume outside the lock to prevent re-entrancy deadlocks
        for (continuation, response) in toResume {
            continuation.resume(returning: response)
        }
    }

    // =========================================================================
    // MARK: - Section Discovery (cached)
    // =========================================================================

    private func findDataSection() async -> (address: UInt64, size: UInt64)? {
        if let cached = cachedDataSection { return cached }
        guard let executablePath = session?.binaryPath else { return nil }
        let name = (executablePath as NSString).lastPathComponent
        let output = await send("image dump sections \(name)")
        let result = LLDBOutputParser.parseDataSection(from: output)
        cachedDataSection = result
        return result
    }
    
    private func findTextSection() async -> (address: UInt64, size: UInt64)? {
        if let cached = cachedTextSection { return cached }
        guard let executablePath = session?.binaryPath else { return nil }
        let name = (executablePath as NSString).lastPathComponent
        let output = await send("image dump sections \(name)")
        let result = LLDBOutputParser.parseTextSection(from: output)
        cachedTextSection = result
        return result
    }

    // =========================================================================
    // MARK: - Launch Steps (called individually from the debug command panel)
    // =========================================================================

    /// Step 1: Load the binary into LLDB using the `file` command.
    /// Called automatically when the session starts.
    ///
    /// LLDB is launched with no arguments. With a pipe for stdin (non-interactive mode)
    /// it does NOT emit an initial `(lldb) ` prompt, so there is nothing to wait for
    /// before sending the first command. LLDB does output `(lldb) ` after processing
    /// any command, so `send()` resolves correctly from the file command's response.
    func waitForStartup() async {
        guard let path = session?.binaryPath else { return }
        let cmd = "file \"\(path)\""
        await display("(lldb) \(cmd)\n")
        let response = await send(cmd)
        await display(response)
        await MainActor.run { self.sessionState = .ready }
    }

    /// Step 2: Launch the inferior with --stop-at-entry so the binary is loaded.
    func launchStopAtEntry() async {
        await MainActor.run { self.sessionState = .running }
        await display("(lldb) process launch --stop-at-entry\n")
        let response = await send("process launch --stop-at-entry")
        await display(response)
        await MainActor.run { self.sessionState = .ready }
    }

    /// Step 3: Set breakpoint at main.
    func breakAtMain() async {
        await display("(lldb) b main\n")
        let response = await send("b main")
        await display(response)
    }

    /// Step 4: Set user breakpoints at specific file/line locations.
    func setUserBreakpoints(breakpointLines: [Int], sourceFile: String) async {
        for line in breakpointLines {
            let cmd = "breakpoint set --file \(sourceFile) --line \(line)"
            await display("(lldb) \(cmd)\n")
            let r = await send(cmd)
            await display(r)
        }
    }

    /// Step 5: Continue execution to the first breakpoint.
    func continueToBreakpoint() async {
        await MainActor.run { self.sessionState = .running }
        await display("(lldb) continue\n")
        let stopResponse = await send("continue", waitForStop: true)
        await display(stopResponse)

        if LLDBOutputParser.detectProcessExit(in: stopResponse) != nil {
            await handleStopResponse(stopResponse)
            return
        }
        await handleStopResponse(stopResponse)
    }

    /// Step 6: Read registers and populate the register panel.
    func readRegisters() async {
        let regOut = await send("register read")
        var values = LLDBOutputParser.parseRegisters(from: regOut)

        let fpsrOut = await send("register read fpsr")
        values.merge(LLDBOutputParser.parseRegisters(from: fpsrOut)) { _, new in new }

        if !values.isEmpty {
            await MainActor.run { self.onRegistersUpdated?(values) }
        }
    }

    /// Step 7: Read the backtrace to determine the current frame/source line.
    func readBacktrace() async {
        let btOut = await send("bt 1")
        if let frame = LLDBOutputParser.parseBacktrace(from: btOut, stopReason: lastStopReason) {
            await MainActor.run { self.onFrameUpdated?(frame) }
        }
    }

    /// Step 8: Read stack memory from $sp up to the stack base.
    ///
    /// On the first call the current SP is captured as `stackBase` — the ceiling of
    /// the user's stack for this session. On every subsequent call the read covers
    /// exactly `(stackBase - sp) / 8` quadwords: the precise set of 8-byte slots the
    /// program has pushed since we started watching. If SP equals the base (nothing
    /// pushed yet) the callback is invoked with an empty array so the view clears.
    func readStackMemory() async {
        let spOut = await send("register read sp")
        let regs = LLDBOutputParser.parseRegisters(from: spOut)
        guard let sp = regs["sp"], sp > 0 else { return }

        // First stop: record the stack ceiling.
        if stackBase == nil { stackBase = sp }

        guard let base = stackBase, base > sp else {
            // SP is at the base — nothing has been pushed onto the user's stack yet.
            await MainActor.run { self.onStackMemoryUpdated?([]) }
            return
        }

        let count = min(256, Int((base - sp) / 8))
        let memOut = await send("memory read --format uint8_t[] --size 8 --count \(count) $sp")
        let stackEntries = LLDBOutputParser.parseMemoryRead(from: memOut)
        await MainActor.run { self.onStackMemoryUpdated?(stackEntries) }
    }

    /// Step 9: Read __DATA section contents.
    func readDataSection() async {
        if let ds = await findDataSection(), ds.size > 0 {
            let count = (ds.size + 7) / 8
            let out = await send("memory read --format uint8_t[] --size 8 --count \(count) 0x\(String(ds.address, radix: 16))")
            let entries = LLDBOutputParser.parseMemoryRead(from: out)
            if !entries.isEmpty {
                await MainActor.run { self.onDataMemoryUpdated?(entries) }
            }
        }
    }

    /// Step 10: Read __TEXT section contents.
    func readTextSection() async {
        if let ts = await findTextSection(), ts.size > 0 {
            let count = (ts.size + 7) / 8
            let out = await send("memory read --format uint8_t[] --size 8 --count \(count) 0x\(String(ts.address, radix: 16))")
            let entries = LLDBOutputParser.parseMemoryRead(from: out)
            if !entries.isEmpty {
                await MainActor.run { self.onTextMemoryUpdated?(entries) }
            }
        }
    }

    /// Step 11: Disassemble the current frame's function.
    ///
    /// Uses `disassemble --frame` (always works; no source-file dependency).
    /// Source line numbers are read from the DWARF debug info embedded in the
    /// binary via `image lookup --address`, which works even after the `.s`
    /// file has been moved or deleted.
    ///
    /// The enriched result is cached by function base address so the per-
    /// instruction `image lookup` calls only happen once per function — not
    /// on every step.
    func readDisassembly() async {
        let output = await send("disassemble --frame")
        let rawLines = LLDBOutputParser.parseDisassembly(from: output)
        guard !rawLines.isEmpty else { return }

        let baseAddr = rawLines[0].address

        // Reuse cache if we're still in the same function.
        if baseAddr == cachedDisassemblyBase {
            let cached = cachedDisassemblyLines
            await MainActor.run { self.onDisassemblyUpdated?(cached) }
            return
        }

        // New function — enrich each instruction with its source line from DWARF.
        let enriched = await enrichWithSourceLines(rawLines)
        cachedDisassemblyBase = baseAddr
        cachedDisassemblyLines = enriched
        await MainActor.run { self.onDisassemblyUpdated?(enriched) }
    }

    /// For each disassembly line, issue `image lookup --address` to retrieve
    /// the source line number from the embedded DWARF debug info.
    /// Lines that have no debug info carry the last known source line forward.
    private func enrichWithSourceLines(_ lines: [DisassemblyLine]) async -> [DisassemblyLine] {
        var result: [DisassemblyLine] = []
        var lastSourceLine: Int? = nil
        for line in lines {
            let out = await send("image lookup --address 0x\(String(line.address, radix: 16))")
            let sl = LLDBOutputParser.parseImageLookupLine(from: out)
            if sl != nil { lastSourceLine = sl }
            result.append(DisassemblyLine(
                address: line.address,
                offset:  line.offset,
                text:    line.text,
                sourceLine: sl ?? lastSourceLine
            ))
        }
        return result
    }

    /// Convenience: run all launch steps automatically (Steps 1-5 + refreshState).
    func launchAndBreakAtMain(breakpointLines: [Int] = [], sourceFile: String? = nil) async {
        await waitForStartup()
        await launchStopAtEntry()
        await breakAtMain()
        if let file = sourceFile {
            await setUserBreakpoints(breakpointLines: breakpointLines, sourceFile: file)
        }
        await continueToBreakpoint()
        await refreshState()
    }

    // =========================================================================
    // MARK: - Step Commands (auto-refresh after each)
    // =========================================================================

    func stepInstruction() async {
        guard sessionState == .ready else { return }
        await issueStepCommand("thread step-inst")
    }

    func stepOver() async {
        guard sessionState == .ready else { return }
        await issueStepCommand("thread step-over")
    }

    func stepInto() async {
        guard sessionState == .ready else { return }
        await issueStepCommand("thread step-in")
    }

    func stepOut() async {
        guard sessionState == .ready else { return }
        await issueStepCommand("thread step-out")
    }

    func continueExecution() async {
        guard sessionState == .ready else { return }
        await MainActor.run {
            self.sessionState = .running
            self.inferiorNeedsInput = true
        }
        await display("(lldb) process continue\n")
        let response = await send("process continue", waitForStop: true)
        await display(response)
        await handleStopResponse(response)

        let currentState = await MainActor.run { self.sessionState }
        if currentState == .ready {
            await refreshState()
        }
    }

    /// Send text to the running inferior's stdin (e.g. answering a scanf prompt).
    func sendProgramInput(_ text: String) {
        guard sessionState == .running else { return }
        session?.send(text + "\n")
    }

    func pause() {
        session?.send("process interrupt\n")
    }

    func terminate() {
        session?.send("quit\n")
        session?.terminate()
        Task { @MainActor in
            self.sessionState = .terminated
            self.inferiorNeedsInput = false
        }
    }

    /// Add a breakpoint at the specified file and line
    func addBreakpoint(file: String, line: Int) async {
        let cmd = "breakpoint set --file \(file) --line \(line)"
        await display("(lldb) \(cmd)\n")
        let r = await send(cmd)
        await display(r)
    }

    /// Remove breakpoint at the specified file and line
    func removeBreakpoint(file: String, line: Int) async {
        let cmd = "breakpoint delete --file \(file) --line \(line)"
        await display("(lldb) \(cmd)\n")
        let r = await send(cmd)
        await display(r)
    }

    /// Send a user-typed LLDB command. Returns the response text.
    /// Does NOT echo to display — caller (AppState) manages the "(lldb) " prefix.
    func sendRawCommand(_ command: String) async -> String {
        guard sessionState == .ready else { return "" }
        return await send(command)
    }

    // =========================================================================
    // MARK: - Internal Helpers
    // =========================================================================

    private func issueStepCommand(_ command: String) async {
        await MainActor.run { self.sessionState = .running }
        await display("(lldb) \(command)\n")
        let response = await send(command, waitForStop: true)
        await display(response)
        await handleStopResponse(response)
        // Only refresh state if the process is still running (didn't exit during the step)
        let currentState = await MainActor.run { self.sessionState }
        if currentState == .ready {
            await refreshState()
        }
    }

    private func handleStopResponse(_ response: String) async {
        // If the process exited, receiveOutput already set .terminated; don't override it.
        guard LLDBOutputParser.detectProcessExit(in: response) == nil else {
            await MainActor.run { self.inferiorNeedsInput = false }
            return
        }
        let reason = LLDBOutputParser.parseStopReason(from: response) ?? "stopped"
        await MainActor.run {
            self.lastStopReason = reason
            self.sessionState = .ready
            self.inferiorNeedsInput = false
        }
    }

    // =========================================================================
    // MARK: - Auto-Refresh After Stop (all silent — nothing echoed to console)
    // =========================================================================

    /// Refresh all state panels: registers, backtrace, stack, __DATA, __TEXT, disassembly.
    func refreshState() async {
        await readRegisters()
        await readBacktrace()
        await readStackMemory()
        await readDataSection()
        await readTextSection()
        await readDisassembly()
    }
}

// MARK: - LLDBOutputParser

enum LLDBOutputParser {

    // MARK: register read

    /// Parse "register read" output into a name → value dictionary.
    /// Input line format: "       x0 = 0x0000000000000001"
    /// Also handles aliases: fp → x29, lr → x30
    static func parseRegisters(from output: String) -> [String: UInt64] {
        var result: [String: UInt64] = [:]
        
        guard let regex = try? NSRegularExpression(
            pattern: #"^\s+(\w+)\s*=\s*(0x[0-9a-fA-F]+)"#,
            options: .anchorsMatchLines
        ) else { return result }

        let ns = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: ns.length))
        
        for match in matches {
            guard match.numberOfRanges == 3 else { continue }
            var name = ns.substring(with: match.range(at: 1)).lowercased()
            let hexStr = ns.substring(with: match.range(at: 2))
            
            // Map common aliases to their canonical register names
            switch name {
            case "fp": name = "x29"
            case "lr": name = "x30"
            case "cpsr": name = "nzcv"  // Map CPSR (Current Program Status Register) to NZCV flags
            default: break
            }
            
            // Parse hex string - extract everything after "0x"
            var hexValue = hexStr
            if hexValue.hasPrefix("0x") || hexValue.hasPrefix("0X") {
                hexValue = String(hexValue.dropFirst(2))
            }
            
            // Parse as UInt64 - handle manually to avoid truncation bugs
            var value: UInt64 = 0
            for (_, char) in hexValue.enumerated() {
                if let digit = char.hexDigitValue {
                    value = (value << 4) | UInt64(digit)
                } else {
                    // Invalid hex character, skip this register
                    value = 0
                    break
                }
            }
            
            if value > 0 || hexValue.allSatisfy({ $0 == "0" }) {
                result[name] = value
            }
        }
        return result
    }

    // MARK: bt 1

    /// Parse "bt 1" output for the current frame's PC, symbol, file, and line.
    /// Example line: "  * frame #0: 0x100003f5c prog`_main + 4 at hello.s:12"
    static func parseBacktrace(from output: String, stopReason: String = "") -> ParsedFrame? {
        guard let regex = try? NSRegularExpression(
            pattern: #"frame\s+#0:\s+(0x[0-9a-fA-F]+)\s+\S+`(\S+)(?:\s+\+\s+\d+)?(?:\s+at\s+([^:]+):(\d+))?"#
        ) else { return nil }

        let ns = output as NSString
        guard let match = regex.firstMatch(
            in: output,
            range: NSRange(location: 0, length: ns.length)
        ), match.numberOfRanges >= 3 else { return nil }

        let addrStr = ns.substring(with: match.range(at: 1))
        let symbol  = ns.substring(with: match.range(at: 2))
        let address = UInt64(addrStr.dropFirst(2), radix: 16) ?? 0

        var sourceFile: String? = nil
        var sourceLine: Int? = nil
        if match.numberOfRanges >= 5,
           match.range(at: 3).location != NSNotFound,
           match.range(at: 4).location != NSNotFound {
            sourceFile = ns.substring(with: match.range(at: 3))
            sourceLine = Int(ns.substring(with: match.range(at: 4)))
        }

        let reason = stopReason.isEmpty ? "stopped" : stopReason
        return ParsedFrame(address: address, symbol: symbol,
                           sourceFile: sourceFile, sourceLine: sourceLine,
                           stopReason: reason)
    }

    // MARK: stop reason

    /// Extract the stop-reason string from a LLDB output block.
    static func parseStopReason(from output: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"stop reason\s*=\s*(.+)"#,
            options: .anchorsMatchLines
        ) else { return nil }
        let ns = output as NSString
        guard let match = regex.firstMatch(
            in: output,
            range: NSRange(location: 0, length: ns.length)
        ), match.numberOfRanges == 2 else { return nil }
        return ns.substring(with: match.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: memory read

    /// Parse "memory read --format uint8_t[] --size 8 --count N $sp" output into address/value pairs.
    /// Example line: "0x16fdfedf0: {0x50 0xf4 0xdf 0x6f 0x01 0x00 0x00 0x00}"
    /// Each line contains 8 bytes that represent a single 64-bit value (little-endian on ARM64).
    static func parseMemoryRead(from output: String) -> [(address: UInt64, value: UInt64)] {
        var result: [(UInt64, UInt64)] = []
        guard let regex = try? NSRegularExpression(
            pattern: #"(0x[0-9a-fA-F]+):\s+\{((?:0x[0-9a-fA-F]+\s*)+)\}"#,
            options: .anchorsMatchLines
        ) else { return result }

        let ns = output as NSString
        for match in regex.matches(in: output, range: NSRange(location: 0, length: ns.length)) {
            guard match.numberOfRanges == 3 else { continue }
            let addrStr = ns.substring(with: match.range(at: 1))
            guard let address = UInt64(addrStr.dropFirst(2), radix: 16) else { continue }
            
            let bytesStr = ns.substring(with: match.range(at: 2))
            let byteTokens = bytesStr.split(separator: " ")
            
            // Collect 8 bytes and convert to UInt64 (little-endian)
            var bytes: [UInt8] = []
            for token in byteTokens {
                let t = token.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("0x"), let byte = UInt8(t.dropFirst(2), radix: 16) {
                    bytes.append(byte)
                }
            }
            
            // Convert 8 bytes to UInt64 (little-endian)
            if bytes.count == 8 {
                var value: UInt64 = 0
                for (i, byte) in bytes.enumerated() {
                    value |= UInt64(byte) << (i * 8)
                }
                result.append((address, value))
            }
        }
        return result
    }

    // MARK: process exit

    /// Returns exit code if the output contains a "Process NNN exited with status = N" line.
    static func detectProcessExit(in output: String) -> Int32? {
        guard let regex = try? NSRegularExpression(
            pattern: #"Process\s+\d+\s+exited\s+with\s+status\s*=\s*(\d+)"#
        ) else { return nil }
        let ns = output as NSString
        guard let match = regex.firstMatch(
            in: output, range: NSRange(location: 0, length: ns.length)
        ), match.numberOfRanges == 2 else { return nil }
        return Int32(ns.substring(with: match.range(at: 1)))
    }
    
    // MARK: data section
    
    /// Parse "image dump sections" output to find all subsections within __DATA container
    /// Example lines:
    ///   "0x00000004 data                   [0x0000000100008000-0x0000000100008014)  rw-  ... output_debug.__DATA.__data"
    ///   "0x00000005 zero_fill              [0x0000000100008014-0x0000000100008020)  rw-  ... output_debug.__DATA.__bss"
    /// Returns the combined range from the first subsection to the end of the last subsection
    static func parseDataSection(from output: String) -> (address: UInt64, size: UInt64)? {
        // Pattern to match any subsection within __DATA (not the container itself)
        // Match lines like: .__DATA.__data, .__DATA.__bss, .__DATA.__common, etc.
        guard let regex = try? NSRegularExpression(
            pattern: #"0x[0-9a-fA-F]+\s+(?:data|zero_fill|common)\s+\[(0x[0-9a-fA-F]+)-(0x[0-9a-fA-F]+)\).*\.__DATA\.\w+"#,
            options: .anchorsMatchLines
        ) else { return nil }
        
        let ns = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: ns.length))
        
        guard !matches.isEmpty else { return nil }
        
        var minStart: UInt64 = .max
        var maxEnd: UInt64 = 0
        
        // Find the overall range by combining all subsections
        for match in matches {
            guard match.numberOfRanges == 3 else { continue }
            let startStr = ns.substring(with: match.range(at: 1))
            let endStr = ns.substring(with: match.range(at: 2))
            
            guard let startAddr = UInt64(startStr.dropFirst(2), radix: 16),
                  let endAddr = UInt64(endStr.dropFirst(2), radix: 16) else {
                continue
            }
            
            minStart = min(minStart, startAddr)
            maxEnd = max(maxEnd, endAddr)
        }
        
        guard minStart != .max && maxEnd > minStart else { return nil }
        
        let size = maxEnd - minStart
        return (minStart, size)
    }
    
    // MARK: disassembly

    /// Parse `disassemble --frame` output into raw DisassemblyLine values.
    ///
    /// LLDB output format (source lines are populated later via `image lookup`):
    /// ```
    /// source_debug`_main:
    ///     0x100003f58 <+0>:  stp    x29, x30, [sp, #-16]!
    /// ->  0x100003f5c <+4>:  mov    x29, sp
    ///     0x100003f60 <+8>:  adrp   x0, 1
    /// ```
    /// The `->` current-PC marker is ignored; highlighting is driven by
    /// `currentExecutionAddress` in the view layer.
    static func parseDisassembly(from output: String) -> [DisassemblyLine] {
        var result: [DisassemblyLine] = []

        // Matches: "    0x100003f58 <+0>:  stp ..." or "->  0x100003f5c <+4>:  mov ..."
        guard let instrPattern = try? NSRegularExpression(
            pattern: #"^(?:->\s+|\s+)(0x[0-9a-fA-F]+)\s+<\+(\d+)>:\s+(.+?)\s*$"#,
            options: .anchorsMatchLines
        ) else { return result }

        for line in output.components(separatedBy: "\n") {
            let ns = line as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let match = instrPattern.firstMatch(in: line, range: range),
                  match.numberOfRanges == 4,
                  match.range(at: 1).location != NSNotFound,
                  match.range(at: 2).location != NSNotFound,
                  match.range(at: 3).location != NSNotFound else { continue }

            let addrStr   = ns.substring(with: match.range(at: 1))
            let offsetStr = ns.substring(with: match.range(at: 2))
            let text      = ns.substring(with: match.range(at: 3))

            guard let address = UInt64(addrStr.dropFirst(2), radix: 16),
                  let offset  = Int(offsetStr) else { continue }

            result.append(DisassemblyLine(address: address, offset: offset, text: text, sourceLine: nil))
        }
        return result
    }

    // MARK: image lookup source line

    /// Parse `image lookup --address 0x...` output for the source line number.
    ///
    /// LLDB writes a Summary line like:
    /// ```
    ///   Summary: source_debug`_main + 8 at source_debug.s:7:3
    /// ```
    /// Source line is extracted from the `:LINE` before the column suffix.
    /// Works from DWARF debug info embedded in the binary — the source file
    /// does not need to be present on disk.
    static func parseImageLookupLine(from output: String) -> Int? {
        guard let regex = try? NSRegularExpression(
            pattern: #"\bat\s+\S+\.(?:s|c|cpp|m):(\d+)"#
        ) else { return nil }
        let ns = output as NSString
        guard let match = regex.firstMatch(
            in: output, range: NSRange(location: 0, length: ns.length)
        ), match.numberOfRanges == 2 else { return nil }
        return Int(ns.substring(with: match.range(at: 1)))
    }

    // MARK: text section

    /// Parse "image dump sections" output to find all subsections within __TEXT container
    /// Example lines:
    ///   "0x00000001 code                   [0x0000000100000458-0x0000000100000478)  r-x  ... output_debug.__TEXT.__text"
    ///   "0x00000002 code                   [0x0000000100000478-0x0000000100000484)  r-x  ... output_debug.__TEXT.__stubs"
    /// Returns the combined range from the first subsection to the end of the last subsection
    static func parseTextSection(from output: String) -> (address: UInt64, size: UInt64)? {
        // Pattern to match any subsection within __TEXT (not the container itself)
        // Match lines like: .__TEXT.__text, .__TEXT.__stubs, .__TEXT.__const, etc.
        guard let regex = try? NSRegularExpression(
            pattern: #"0x[0-9a-fA-F]+\s+(?:code|data|compact_unwind|literal_pointers?|cstring_literals?|symbols?|unwind_info)\s+\[(0x[0-9a-fA-F]+)-(0x[0-9a-fA-F]+)\).*\.__TEXT\.\w+"#,
            options: .anchorsMatchLines
        ) else { return nil }
        
        let ns = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: ns.length))
        
        guard !matches.isEmpty else { return nil }
        
        var minStart: UInt64 = .max
        var maxEnd: UInt64 = 0
        
        // Find the overall range by combining all subsections
        for match in matches {
            guard match.numberOfRanges == 3 else { continue }
            let startStr = ns.substring(with: match.range(at: 1))
            let endStr = ns.substring(with: match.range(at: 2))
            
            guard let startAddr = UInt64(startStr.dropFirst(2), radix: 16),
                  let endAddr = UInt64(endStr.dropFirst(2), radix: 16) else {
                continue
            }
            
            minStart = min(minStart, startAddr)
            maxEnd = max(maxEnd, endAddr)
        }
        
        guard minStart != .max && maxEnd > minStart else { return nil }
        
        let size = maxEnd - minStart
        return (minStart, size)
    }
}
