import Foundation

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
///  - Automatic register + backtrace refresh after every stop
///  - Program stdin forwarding when the inferior is running
///  - Two-tier timeout: 5 s for instant commands; no timeout for run/continue
final class LLDBController: ObservableObject {

    // MARK: Published state

    @Published private(set) var sessionState: DebuggerSessionState = .idle
    @Published private(set) var lastStopReason: String = ""

    // MARK: Callbacks → AppState

    var onRegistersUpdated: (([String: UInt64]) -> Void)?
    var onFrameUpdated: ((ParsedFrame) -> Void)?
    var onProcessTerminated: ((Int32) -> Void)?
    /// Raw output forwarded to the console display (unchanged).
    var forwardToDisplay: ((String) -> Void)?

    // MARK: Private

    private weak var session: LLDBSession?
    private var outputBuffer = ""
    private var promptContinuation: CheckedContinuation<String, Never>?

    // MARK: - Attach

    func attach(to session: LLDBSession) {
        self.session = session
        sessionState = .launching
        // Wire the controller output handler on the session
        session.controllerOutputHandler = { [weak self] chunk in
            self?.receiveOutput(chunk)
        }
    }

    // MARK: - Launch & Break at _main

    func launchAndBreakAtMain() async {
        _ = await sendAndAwait("breakpoint set --name _main")
        sessionState = .running
        session?.send("run\n")
        // Open-ended wait: no timeout; ends when stop-reason prompt arrives
        let response = await awaitPrompt()
        handleStopResponse(response)
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
        await MainActor.run { self.sessionState = .running }
        session?.send("process continue\n")
        // Open-ended wait — inferior may block on stdin
        let response = await awaitPrompt()
        handleStopResponse(response)
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
        Task { @MainActor in self.sessionState = .terminated }
    }

    /// Send any raw LLDB command and return its response text (Tier-1, 5 s timeout).
    func sendRawCommand(_ command: String) async -> String {
        guard sessionState == .ready else { return "" }
        return await sendAndAwait(command)
    }

    // MARK: - Internal

    private func issueStepCommand(_ command: String) async {
        await MainActor.run { self.sessionState = .running }
        session?.send(command + "\n")
        // Open-ended wait until LLDB reports stopped
        let response = await awaitPrompt()
        handleStopResponse(response)
        // Auto-refresh register and frame state
        await refreshState()
    }

    private func handleStopResponse(_ response: String) {
        let reason = LLDBOutputParser.parseStopReason(from: response) ?? "stopped"
        Task { @MainActor in
            self.lastStopReason = reason
            self.sessionState = .ready
        }
    }

    // MARK: Output Buffering

    /// Called by LLDBSession.controllerOutputHandler on every chunk.
    func receiveOutput(_ chunk: String) {
        outputBuffer += chunk
        forwardToDisplay?(chunk)

        // Check for process exit before prompt detection
        if let code = LLDBOutputParser.detectProcessExit(in: outputBuffer) {
            let buffer = outputBuffer
            outputBuffer = ""
            promptContinuation?.resume(returning: buffer)
            promptContinuation = nil
            Task { @MainActor in
                self.sessionState = .terminated
                self.onProcessTerminated?(code)
            }
            return
        }

        // "(lldb) " with trailing space = end of a response
        while let range = outputBuffer.range(of: "(lldb) ") {
            let response = String(outputBuffer[..<range.lowerBound])
            outputBuffer = String(outputBuffer[range.upperBound...])

            // Transition from .launching → .ready on the very first prompt
            if case .launching = sessionState {
                Task { @MainActor in self.sessionState = .ready }
            }

            promptContinuation?.resume(returning: response)
            promptContinuation = nil
        }
    }

    // MARK: - Auto-Refresh After Stop

    private func refreshState() async {
        // 1. Register values
        let regOut = await sendAndAwait("register read")
        let values = LLDBOutputParser.parseRegisters(from: regOut)
        if !values.isEmpty {
            onRegistersUpdated?(values)
        }

        // 2. Current frame / source line
        let btOut = await sendAndAwait("bt 1")
        if let frame = LLDBOutputParser.parseBacktrace(from: btOut,
                                                        stopReason: lastStopReason) {
            onFrameUpdated?(frame)
        }
    }

    // MARK: - Tier-1 sendAndAwait (5 s timeout)

    private func sendAndAwait(_ command: String) async -> String {
        await MainActor.run { self.sessionState = .waitingResponse }
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
        await MainActor.run { self.sessionState = .ready }
        return response
    }

    // MARK: - Await next (lldb) prompt (no timeout)

    private func awaitPrompt() async -> String {
        await withCheckedContinuation { continuation in
            // If there's already a buffered prompt response waiting, deliver it immediately
            if let range = outputBuffer.range(of: "(lldb) ") {
                let response = String(outputBuffer[..<range.lowerBound])
                outputBuffer = String(outputBuffer[range.upperBound...])
                continuation.resume(returning: response)
            } else {
                promptContinuation = continuation
            }
        }
    }
}

// MARK: - LLDBOutputParser

enum LLDBOutputParser {

    // MARK: register read

    /// Parse "register read" output into a name → value dictionary.
    /// Input line format: "       x0 = 0x0000000000000001"
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
            let name = ns.substring(with: match.range(at: 1)).lowercased()
            let hexStr = ns.substring(with: match.range(at: 2))
            if let value = UInt64(hexStr.dropFirst(2), radix: 16) {
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

    /// Parse "memory read --size 8 --count N $sp" output.
    static func parseMemoryRead(from output: String) -> [(address: UInt64, value: UInt64)] {
        var result: [(UInt64, UInt64)] = []
        guard let regex = try? NSRegularExpression(
            pattern: #"(0x[0-9a-fA-F]+):\s+((?:0x[0-9a-fA-F]+\s*)+)"#,
            options: .anchorsMatchLines
        ) else { return result }

        let ns = output as NSString
        for match in regex.matches(in: output, range: NSRange(location: 0, length: ns.length)) {
            guard match.numberOfRanges == 3 else { continue }
            let addrStr = ns.substring(with: match.range(at: 1))
            guard let baseAddr = UInt64(addrStr.dropFirst(2), radix: 16) else { continue }
            let valuesStr = ns.substring(with: match.range(at: 2))
            let tokens = valuesStr.split(separator: " ")
            for (i, token) in tokens.enumerated() {
                let t = token.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("0x"), let val = UInt64(t.dropFirst(2), radix: 16) {
                    result.append((baseAddr + UInt64(i) * 8, val))
                }
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
}
