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
///  - Two-tier timeout: 5 s for instant commands; no timeout for run/continue
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
    /// Raw output forwarded to the console display (unchanged).
    var forwardToDisplay: ((String) -> Void)?

    // MARK: Private

    private weak var session: LLDBSession?
    private var outputBuffer = ""
    private var promptContinuations: [CheckedContinuation<String, Never>] = []
    private let outputLock = NSLock()
    
    // Cache section info (doesn't change during execution)
    private var cachedDataSection: (address: UInt64, size: UInt64)? = nil
    private var cachedTextSection: (address: UInt64, size: UInt64)? = nil

    // MARK: - Attach

    func attach(to session: LLDBSession) {
        self.session = session
        sessionState = .launching
        session.controllerOutputHandler = { [weak self] chunk in
            self?.receiveOutput(chunk)
        }
    }

    // MARK: - Data Section Discovery

    /// Find the .data section dynamically using image dump sections.
    /// Result is cached — the section address never changes during a debugging session.
    private func findDataSection() async -> (address: UInt64, size: UInt64)? {
        if let cached = cachedDataSection { return cached }
        guard let executablePath = session?.binaryPath else { return nil }
        let executableName = (executablePath as NSString).lastPathComponent
        let output = await sendInternal("image dump sections \(executableName)")
        let result = LLDBOutputParser.parseDataSection(from: output)
        cachedDataSection = result
        return result
    }
    
    /// Find the .text section dynamically using image dump sections
    private func findTextSection() async -> (address: UInt64, size: UInt64)? {
        guard let executablePath = session?.binaryPath else { return nil }
        
        // Extract just the filename from the full path
        let executableName = (executablePath as NSString).lastPathComponent
        
        let output = await sendAndAwait("image dump sections \(executableName)")
        return LLDBOutputParser.parseTextSection(from: output)
    }

    // MARK: - Launch & Break at _main

    func launchAndBreakAtMain(breakpointLines: [Int] = [], sourceFile: String? = nil) async {
        // First, consume any initial LLDB startup output (from 'target create')
        // LLDB automatically runs "target create" when started with a binary path
        _ = await awaitPrompt()
        
        // Launch with --stop-at-entry to stop at the dynamic linker
        // This ensures the binary is loaded before we set breakpoints
        await MainActor.run { 
            self.sessionState = .running
            self.forwardToDisplay?("process launch --stop-at-entry\n")
        }
        session?.send("process launch --stop-at-entry\n")
        _ = await awaitPrompt()
        
        // Now the binary is loaded, set breakpoint at main
        _ = await sendAndAwait("b main")
        
        // Set user breakpoints
        if let file = sourceFile {
            for line in breakpointLines {
                _ = await sendAndAwait("breakpoint set --file \(file) --line \(line)")
            }
        }
        
        // Continue to the first breakpoint (_main). Do NOT set inferiorNeedsInput — this
        // is an automated launch step, not a user-initiated continue.
        await MainActor.run {
            self.sessionState = .running
            self.forwardToDisplay?("continue\n")
        }
        session?.send("continue\n")
        let stopResponse = await awaitPrompt()
        await MainActor.run { self.forwardToDisplay?(stopResponse) }

        // Check if the process actually stopped at a breakpoint or exited
        if LLDBOutputParser.detectProcessExit(in: stopResponse) != nil {
            // Process exited without hitting breakpoint
            await handleStopResponse(stopResponse)
            return
        }

        // Process should be stopped at _main breakpoint
        await handleStopResponse(stopResponse)
        
        // Refresh state now that we're stopped
        await refreshState()
    }

    // MARK: - Step Commands (auto-refresh after each)

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
            self.forwardToDisplay?("process continue\n")
        }
        session?.send("process continue\n")
        let response = await awaitPrompt()
        await MainActor.run { self.forwardToDisplay?(response) }
        await handleStopResponse(response)

        // Only refresh if we stopped (not if process exited)
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
        _ = await sendAndAwait("breakpoint set --file \(file) --line \(line)")
    }

    /// Remove breakpoint at the specified file and line
    func removeBreakpoint(file: String, line: Int) async {
        // LLDB doesn't have a direct "delete by file:line", so we list and delete by ID
        // For simplicity, we'll delete all breakpoints at that location
        _ = await sendAndAwait("breakpoint list")
        // Parse breakpoint IDs that match the file:line
        // This is a simplified approach - in production you'd want more robust parsing
        _ = await sendAndAwait("breakpoint delete --file \(file) --line \(line)")
    }

    /// Send any raw LLDB command and return its response text (Tier-1, 5 s timeout).
    func sendRawCommand(_ command: String) async -> String {
        guard sessionState == .ready else { return "" }
        return await sendAndAwait(command)
    }

    // MARK: - Internal

    private func issueStepCommand(_ command: String) async {
        await MainActor.run {
            self.sessionState = .running
            self.forwardToDisplay?(command + "\n")
        }
        session?.send(command + "\n")
        let response = await awaitPrompt()
        await MainActor.run { self.forwardToDisplay?(response) }
        await handleStopResponse(response)
        await refreshState()
    }

    private func handleStopResponse(_ response: String) async {
        let reason = LLDBOutputParser.parseStopReason(from: response) ?? "stopped"
        await MainActor.run {
            self.lastStopReason = reason
            self.sessionState = .ready
            self.inferiorNeedsInput = false
        }
    }

    // MARK: Output Buffering

    /// Called by LLDBSession.controllerOutputHandler on every chunk.
    func receiveOutput(_ chunk: String) {
        // Do NOT forward raw output here. User-visible forwarding is done explicitly
        // in sendAndAwait (command echo) and in continueExecution/issueStepCommand
        // (stop-reason response), keeping internal refresh commands off the console.
        outputLock.lock()
        outputBuffer += chunk
        
        if let code = LLDBOutputParser.detectProcessExit(in: outputBuffer) {
            let buffer = outputBuffer
            outputBuffer = ""
            let continuations = promptContinuations
            promptContinuations = []
            outputLock.unlock()
            
            // Update state on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.sessionState = .terminated
                self.inferiorNeedsInput = false
                self.onProcessTerminated?(code)
            }
            
            for continuation in continuations {
                continuation.resume(returning: buffer)
            }
            return
        }

        while let range = outputBuffer.range(of: "(lldb) ") {
            let response = String(outputBuffer[outputBuffer.startIndex..<range.lowerBound])
            outputBuffer = String(outputBuffer[range.upperBound...])

            if case .launching = sessionState {
                DispatchQueue.main.async { [weak self] in
                    self?.sessionState = .ready
                }
            }

            if let continuation = promptContinuations.first {
                promptContinuations.removeFirst()
                continuation.resume(returning: response)
            }
        }
        
        outputLock.unlock()
    }

    // MARK: - Auto-Refresh After Stop

    private func refreshState() async {
        // 1. Register values (general purpose + special)
        let regOut = await sendInternal("register read")
        var values = LLDBOutputParser.parseRegisters(from: regOut)

        // 2. Read FPSR explicitly (not in the default register read output)
        let fpsrOut = await sendInternal("register read fpsr")
        let fpsrValues = LLDBOutputParser.parseRegisters(from: fpsrOut)
        values.merge(fpsrValues) { _, new in new }

        if !values.isEmpty {
            await MainActor.run { self.onRegistersUpdated?(values) }
        }

        // 3. Current frame / source line
        let btOut = await sendInternal("bt 1")
        if let frame = LLDBOutputParser.parseBacktrace(from: btOut, stopReason: lastStopReason) {
            await MainActor.run { self.onFrameUpdated?(frame) }
        }

        // 4. Live stack contents (16 quadwords starting at $sp)
        let memOut = await sendInternal("memory read --format uint8_t[] --size 8 --count 16 $sp")
        let stackEntries = LLDBOutputParser.parseMemoryRead(from: memOut)
        if !stackEntries.isEmpty {
            await MainActor.run { self.onStackMemoryUpdated?(stackEntries) }
        }

        // 5. Data section contents (find dynamically and read; address is cached after first call)
        if let dataSection = await findDataSection(), dataSection.size > 0 {
            let count = (dataSection.size + 7) / 8
            let dataMemOut = await sendInternal("memory read --format uint8_t[] --size 8 --count \(count) 0x\(String(dataSection.address, radix: 16))")
            let dataEntries = LLDBOutputParser.parseMemoryRead(from: dataMemOut)
            if !dataEntries.isEmpty {
                await MainActor.run { self.onDataMemoryUpdated?(dataEntries) }
            }
        }
        
        // 6. Text section contents (find dynamically and read)
        if let textSection = await findTextSection(), textSection.size > 0 {
            // Calculate number of 8-byte chunks needed
            let count = (textSection.size + 7) / 8  // Round up to nearest 8-byte boundary
            let textMemOut = await sendAndAwait("memory read --format uint8_t[] --size 8 --count \(count) 0x\(String(textSection.address, radix: 16))")
            let textEntries = LLDBOutputParser.parseMemoryRead(from: textMemOut)
            
            if !textEntries.isEmpty {
                await MainActor.run {
                    self.onTextMemoryUpdated?(textEntries)
                }
            }
        }
    }

    // MARK: - Tier-1 sendAndAwait (5 s timeout, echoes to console)

    private func sendAndAwait(_ command: String) async -> String {
        // Echo command to display
        await MainActor.run {
            self.forwardToDisplay?(command + "\n")
        }

        session?.send(command + "\n")
        let response = await withTaskGroup(of: String.self) { group in
            group.addTask { await self.awaitPrompt() }
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return "[timeout:\(command)]"
            }
            let result = await group.next()!
            group.cancelAll()
            return result
        }
        return response
    }

    // MARK: - Internal command (no echo, no timeout — for refreshState only)

    /// Send a command silently and wait indefinitely for the response.
    /// Used for internal refresh commands (register read, bt, memory read, image dump)
    /// so they never appear in the user's console and never leave dangling continuations.
    private func sendInternal(_ command: String) async -> String {
        session?.send(command + "\n")
        return await awaitPrompt()
    }

    // MARK: - Await next (lldb) prompt (no timeout)

    private func awaitPrompt() async -> String {
        await withCheckedContinuation { continuation in
            outputLock.lock()
            defer { outputLock.unlock() }
            
            if let range = outputBuffer.range(of: "(lldb) ") {
                let response = String(outputBuffer[outputBuffer.startIndex..<range.lowerBound])
                outputBuffer = String(outputBuffer[range.upperBound...])
                continuation.resume(returning: response)
            } else {
                promptContinuations.append(continuation)
            }
        }
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
            pattern: #"frame\s+#0:\s+(0x[0-9a-fA-F]+)\s+\S+`(\S+?)(?:\s+\+\s+\d+)?(?:\s+at\s+([^:]+):(\d+))?"#
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
