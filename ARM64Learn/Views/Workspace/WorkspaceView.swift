import SwiftUI

// MARK: - Workspace View

struct WorkspaceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            WorkspaceToolbar()

            Divider()

            // Main content: top/bottom split
            VSplitView {
                // TOP HALF: Tutorial | (Editor + Segments + Console)
                HSplitView {
                    if appState.tutorialPanelVisible {
                        TutorialContentView()
                            .frame(minWidth: 280)
                    }

                    // Right side: editor+segments on top, console below
                    VSplitView {
                        // Editor and segment panels side by side
                        HSplitView {
                            CodeEditorView()
                                .frame(minWidth: 300)

                            SegmentPanelView()
                                .frame(minWidth: 250)
                        }
                        .frame(minHeight: 150)

                        // Tabbed console spanning editor + segment panel
                        BottomPanelView()
                            .frame(minHeight: 100)
                    }
                }
                .frame(minHeight: 300)

                // BOTTOM HALF: Registers + Stack + Heap (full width)
                MemoryStripView()
                    .frame(minHeight: 120)
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
        .frame(width: 1400, height: 900)
}
