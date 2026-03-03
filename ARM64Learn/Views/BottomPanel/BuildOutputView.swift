import SwiftUI

// MARK: - Build Output View

struct BuildOutputView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ConsoleOutputView(text: appState.buildOutput)

            if appState.isCompiling {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Compiling...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                .padding(12)
            }
        }
    }
}

#Preview("Build Output") {
    @Previewable @StateObject var previewAppState = AppState()
    
    BuildOutputView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.buildOutput = """
            Building ARM64 Assembly code...
            
            Compiling main.s
            Linking...
            Build succeeded!
            """
        }
        .frame(width: 800, height: 300)
}
