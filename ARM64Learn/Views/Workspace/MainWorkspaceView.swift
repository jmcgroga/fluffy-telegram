import SwiftUI

// MARK: - Main Workspace

struct MainWorkspaceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            WorkspaceToolbar()

            Divider()

            // Main content: top/bottom split
            VSplitView {
                // TOP: Tutorial | Code Editor | __DATA/__TEXT
                HSplitView {
                    if appState.tutorialPanelVisible {
                        TutorialContentView()
                            .frame(minWidth: 280)
                    }

                    CodeEditorView()
                        .frame(minWidth: 300)

                    SegmentPanelView()
                        .frame(minWidth: 250)
                }
                .frame(minHeight: 200)

                // BOTTOM: Registers + Stack + Heap (full width)
                MemoryStripView()
                    .frame(minHeight: 120)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.windowBackground)
    }
}

#Preview("Main Workspace") {
    @Previewable @StateObject var previewAppState = AppState()
    
    MainWorkspaceView()
        .environmentObject(previewAppState)
        .environment(\.sidebarToggle, SidebarToggle(isShowing: .constant(false)))
        .frame(width: 1400, height: 900)
}

