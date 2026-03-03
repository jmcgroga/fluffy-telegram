import SwiftUI

// MARK: - LLDB Debugger View

struct LLDBDebuggerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var lldbInput = ""
    @State private var historyIndex = -1

    var body: some View {
        VStack(spacing: 0) {
            ConsoleOutputView(text: appState.lldbOutput)

            Divider()

            // LLDB input
            HStack(spacing: 8) {
                Text("(lldb)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)

                TextField("Enter LLDB command...", text: $lldbInput)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        sendCommand()
                    }

                Button("Send") {
                    sendCommand()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(lldbInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial)
        }
    }
    
    private func sendCommand() {
        let cmd = lldbInput.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }
        appState.sendLLDBCommand(cmd)
        lldbInput = ""
        historyIndex = -1
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
