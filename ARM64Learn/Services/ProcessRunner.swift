import Foundation

// MARK: - Process Runner (compile & run)

final class ProcessRunner {

    private let tempDir: URL = {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ARM64Learn", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Compile (run binary, show stdout/stderr)

    func compile(code: String, language: CodeLanguage) async -> String {
        let sourceURL = tempDir.appendingPathComponent("source.\(language.fileExtension)")
        let outputURL = tempDir.appendingPathComponent("output")

        do {
            try code.write(to: sourceURL, atomically: true, encoding: .utf8)
        } catch {
            return "Error writing source file: \(error.localizedDescription)\n"
        }

        let compileResult = await runCompiler(source: sourceURL, output: outputURL, language: language, debug: false)
        guard compileResult.exitCode == 0 else {
            return "Build FAILED ✗\n\n" + compileResult.output
        }

        let runResult = await runBinary(at: outputURL)
        var out = "Build succeeded ✓\n"
        out += "─────────────────────────────────────────\n"
        out += "Program output:\n\n"
        out += runResult.output.isEmpty ? "(no output)\n" : runResult.output
        out += "\n─────────────────────────────────────────\n"
        out += "Exit code: \(runResult.exitCode)\n"
        return out
    }

    // MARK: - Compile with Debug Symbols

    func compileWithDebugSymbols(
        code: String,
        language: CodeLanguage
    ) async -> (success: Bool, binaryPath: String?, output: String) {
        let sourceURL = tempDir.appendingPathComponent("source_debug.\(language.fileExtension)")
        let outputURL = tempDir.appendingPathComponent("output_debug")

        do {
            try code.write(to: sourceURL, atomically: true, encoding: .utf8)
        } catch {
            return (false, nil, "Error writing source file: \(error.localizedDescription)\n")
        }

        let result = await runCompiler(source: sourceURL, output: outputURL, language: language, debug: true)
        if result.exitCode == 0 {
            let msg = "Build with debug symbols succeeded ✓\nBinary: \(outputURL.path)\n\n"
            return (true, outputURL.path, msg + result.output)
        } else {
            return (false, nil, "Build FAILED ✗\n\n" + result.output)
        }
    }

    // MARK: - Internal: Compiler Invocation

    private func runCompiler(
        source: URL,
        output: URL,
        language: CodeLanguage,
        debug: Bool
    ) async -> (exitCode: Int32, output: String) {
        var args: [String]

        switch language {
        case .arm64:
            // Use clang as the driver for assembling ARM64 .s files
            args = [
                "clang",
                "-arch", "arm64",
                "-x", "assembler",
                source.path,
                "-o", output.path,
            ]
        case .c:
            args = [
                "clang",
                "-arch", "arm64",
                source.path,
                "-o", output.path,
            ]
        }

        if debug {
            args += ["-g"]
        }

        // Locate clang via xcrun
        let xcrunResult = await shell("/usr/bin/xcrun", args: ["--find", "clang"])
        let clangPath = xcrunResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

        if !clangPath.isEmpty && xcrunResult.exitCode == 0 {
            args[0] = clangPath
        } else {
            args[0] = "/usr/bin/clang"
        }

        return await shell(args[0], args: Array(args.dropFirst()))
    }

    // MARK: - Internal: Run Binary

    private func runBinary(at url: URL) async -> (exitCode: Int32, output: String) {
        return await shell(url.path, args: [])
    }

    // MARK: - Shell Helper

    func shell(_ executable: String, args: [String]) async -> (exitCode: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = args

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let combined = [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
                    continuation.resume(returning: (process.terminationStatus, combined))
                } catch {
                    continuation.resume(returning: (-1, "Failed to launch \(executable): \(error.localizedDescription)\n"))
                }
            }
        }
    }
}

// MARK: - LLDB Session

final class LLDBSession {
    let binaryPath: String
    var outputHandler: ((String) -> Void)?
    /// Secondary output handler wired to LLDBController for command/response parsing.
    var controllerOutputHandler: ((String) -> Void)?

    private var process: Process?
    private var stdinPipe: Pipe?

    init(binaryPath: String) {
        self.binaryPath = binaryPath
    }

    func start() async {
        guard let lldbPath = await findLLDB() else {
            outputHandler?("LLDB not found. Please install Xcode Command Line Tools.\n")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: lldbPath)
        process.arguments = [binaryPath]

        let stdin  = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput  = stdin
        process.standardOutput = stdout
        process.standardError  = stderr

        // Stream output to display handler and controller parser
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            self?.controllerOutputHandler?(text)   // parser (sync, before main queue)
            DispatchQueue.main.async {
                self?.outputHandler?(text)
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            self?.controllerOutputHandler?(text)   // parser
            DispatchQueue.main.async {
                self?.outputHandler?(text)
            }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.outputHandler?("\n[LLDB session ended]\n")
            }
        }

        do {
            try process.run()
        } catch {
            outputHandler?("Failed to start LLDB: \(error.localizedDescription)\n")
            return
        }

        self.process = process
        self.stdinPipe = stdin
    }

    func send(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        stdinPipe?.fileHandleForWriting.write(data)
    }

    func terminate() {
        process?.terminate()
    }

    private func findLLDB() async -> String? {
        let runner = ProcessRunner()
        let result = await runner.shell("/usr/bin/xcrun", args: ["--find", "lldb"])
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.exitCode == 0 && !path.isEmpty ? path : nil
    }
}

// MARK: - Terminal Session

final class TerminalSession {
    var outputHandler: ((String) -> Void)?

    private var process: Process?
    private var stdinPipe: Pipe?

    func start() {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l"]   // login shell

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        process.environment = env

        let stdin  = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput  = stdin
        process.standardOutput = stdout
        process.standardError  = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.outputHandler?(text)
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.outputHandler?(text)
            }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.outputHandler?("\n[Session ended]\n")
            }
        }

        try? process.run()
        self.process = process
        self.stdinPipe = stdin
    }

    func send(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        stdinPipe?.fileHandleForWriting.write(data)
    }

    func terminate() {
        process?.terminate()
    }
}
