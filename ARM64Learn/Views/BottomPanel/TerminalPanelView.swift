import SwiftUI

// MARK: - Terminal View

struct TerminalPanelView: View {
    @EnvironmentObject private var appState: AppState
    @State private var terminalInput = ""

    var body: some View {
        VStack(spacing: 0) {
            ConsoleOutputView(
                text: appState.terminalOutput.isEmpty
                    ? "Terminal ready. Type commands below.\n"
                    : appState.terminalOutput
            )

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Enter command...", text: $terminalInput)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.plain)
                    .onSubmit {
                        runCommand()
                    }

                Button("Run") {
                    runCommand()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(terminalInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial)
        }
        .onAppear {
            Task { @MainActor in
                appState.startTerminalIfNeeded()
            }
        }
    }
    
    private func runCommand() {
        let cmd = terminalInput.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }
        appState.sendTerminalInput(cmd)
        terminalInput = ""
    }
}

#Preview("Terminal Panel") {
    @Previewable @StateObject var previewAppState = AppState()
    
    TerminalPanelView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.terminalOutput = """
            $ ls -la
            total 64
            drwxr-xr-x  5 user  staff   160 Mar  2 10:30 .
            drwxr-xr-x  8 user  staff   256 Mar  1 15:20 ..
            -rwxr-xr-x  1 user  staff 16384 Mar  2 10:30 a.out
            -rw-r--r--  1 user  staff   512 Mar  2 10:25 main.s
            $ ./a.out
            Hello, ARM64 World!
            Exit code: 0
            $
            """
        }
        .frame(width: 800, height: 300)
}
