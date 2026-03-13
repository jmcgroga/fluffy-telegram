import SwiftUI

// MARK: - LLDB Debugger View

struct LLDBDebuggerView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            ConsoleOutputView(text: appState.lldbOutput)

            Divider()

            // Input row: switches between LLDB command prompt and program stdin.
            if appState.lldbInferiorNeedsInput {
                ProgramInputRow()
            } else {
                LLDBCommandRow()
            }
        }
    }
}

// MARK: - Debugger Control Bar

struct DebuggerControlBar: View {
    @EnvironmentObject private var appState: AppState

    private var state: DebuggerSessionState { appState.debuggerState }
    private var isPaused:  Bool { appState.lldbIsPaused }
    private var isRunning: Bool { appState.lldbIsRunning }
    private var hasSession: Bool {
        switch state {
        case .idle, .error: return false
        default: return true
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            // Run / Continue
            StepButton(label: "Run", icon: "play.fill", tint: .green,
                       enabled: !hasSession || isPaused) {
                if !hasSession { Task { await appState.compileAndDebug() } }
                else           { appState.continueExecution() }
            }
            .help(!hasSession ? "Build with debug symbols and run" : "Continue (c)")

            // Pause
            StepButton(label: "Pause", icon: "pause.fill", tint: .orange, enabled: isRunning) {
                appState.pauseExecution()
            }
            .help("Interrupt running process")

            // Stop
            StepButton(label: "Stop", icon: "stop.fill", tint: .red, enabled: hasSession) {
                appState.terminateDebugger()
            }
            .help("Terminate debugger session")

            Divider().frame(height: 22).padding(.horizontal, 3)

            // Step: single instruction
            StepButton(label: "Inst", icon: "arrow.right.to.line", enabled: isPaused) {
                appState.stepInstruction()
            }
            .help("Step one ARM64 instruction")

            // Step over source line
            StepButton(label: "Over", icon: "arrow.uturn.right", enabled: isPaused) {
                appState.stepOver()
            }
            .help("Step over current source line")

            // Step into call
            StepButton(label: "Into", icon: "arrow.down.right", enabled: isPaused) {
                appState.stepInto()
            }
            .help("Step into function call")

            // Step out
            StepButton(label: "Out", icon: "arrow.up.right", enabled: isPaused) {
                appState.stepOut()
            }
            .help("Step out of current function")

            Divider().frame(height: 22).padding(.horizontal, 3)

            // Status dot + label
            HStack(spacing: 5) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: state)
                Text(state.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 64, alignment: .leading)
            }

            // Stop reason chip
            if isPaused, !appState.lldbController.lastStopReason.isEmpty {
                Text(appState.lldbController.lastStopReason)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.1)))
            }
        }
    }

    private var stateColor: Color {
        switch state {
        case .idle, .terminated:           return .gray
        case .launching, .waitingResponse: return .yellow
        case .ready:                        return .green
        case .running:                      return .orange
        case .error:                        return .red
        }
    }
}

// MARK: - Step Button

struct StepButton: View {
    let label: String
    let icon: String
    var tint: Color = .primary
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(label)
                    .font(.system(size: 9))
            }
            .foregroundStyle(enabled ? tint : Color.secondary.opacity(0.35))
            .frame(width: 38, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.001)) // hit-testing
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - LLDB Command Row (shown when debugger is paused / ready)

struct LLDBCommandRow: View {
    @EnvironmentObject private var appState: AppState
    @State private var input = ""

    var body: some View {
        HStack(spacing: 8) {
            Text("(lldb)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.blue)
            TextField("Enter LLDB command…", text: $input)
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(.plain)
                .onSubmit { submit() }
            Button("Send") { submit() }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.regularMaterial)
    }

    private func submit() {
        let cmd = input.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }
        appState.sendLLDBCommand(cmd)
        input = ""
    }
}

// MARK: - Program Input Row (shown when inferior is executing / blocked on stdin)

struct ProgramInputRow: View {
    @EnvironmentObject private var appState: AppState
    @State private var input = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(.orange).font(.caption)
            Text("Program input")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.orange)
            TextField("Type and press Return to send to running program…", text: $input)
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(.plain)
                .onSubmit { submit() }
            Button("Send") { submit() }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(.orange)
                .disabled(input.isEmpty)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Color.orange.opacity(0.06))
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(Color.orange.opacity(0.25)),
            alignment: .top
        )
    }

    private func submit() {
        guard !input.isEmpty else { return }
        appState.sendProgramInput(input)
        input = ""
    }
}

#Preview("LLDB Debugger") {
    @Previewable @StateObject var previewAppState = AppState()

    LLDBDebuggerView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.lldbOutput = """
            (lldb) target create ./a.out
            Current executable set to './a.out' (arm64).
            (lldb) b main
            Breakpoint 1: where = a.out`main, address = 0x0000000100003f80
            (lldb) run
            Process 12345 launched: './a.out' (arm64)
            Process 12345 stopped
            * thread #1, queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
            """
        }
        .frame(width: 800, height: 300)
}
