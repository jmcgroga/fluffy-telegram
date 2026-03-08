import SwiftUI

// MARK: - Output Window View

/// Standalone window containing the tabbed console output (Build Output / Terminal / LLDB).
struct OutputWindowView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        BottomPanelView()
    }
}

#Preview("Output Window") {
    @Previewable @StateObject var previewAppState = AppState()

    OutputWindowView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.buildOutput = """
            Building ARM64 Assembly code...

            Compiling main.s
            Linking...
            Build succeeded!
            """
        }
        .frame(width: 800, height: 400)
}
