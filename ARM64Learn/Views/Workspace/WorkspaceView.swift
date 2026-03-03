import SwiftUI

// MARK: - Workspace View

struct WorkspaceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            WorkspaceToolbar()

            Divider()

            // Main content area
            HSplitView {
                // Panel 1: Tutorial Content (optional)
                if appState.tutorialPanelVisible {
                    TutorialContentView()
                        .frame(minWidth: 320)
                }

                // Panel 2 & 3: Editor + Memory with shared bottom panel
                VStack(spacing: 0) {
                    // Top: Editor and Memory side by side
                    HSplitView {
                        // Code Editor
                        CodeEditorView()
                            .frame(minWidth: 320)

                        // Memory Visualization (optional)
                        if appState.registerPanelVisible {
                            RegisterPanelView()
                                .frame(minWidth: 280)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Bottom panel (spans editor + memory only)
                    if appState.bottomPanelVisible {
                        Divider()
                        BottomPanelView()
                            .frame(height: appState.bottomPanelHeight)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.windowBackground)
    }
}

#Preview("Workspace") {
    @Previewable @StateObject var previewAppState = AppState()
    
    WorkspaceView()
        .environmentObject(previewAppState)
        .environment(\.sidebarToggle, SidebarToggle(isShowing: .constant(false)))
        .frame(width: 1200, height: 800)
}
