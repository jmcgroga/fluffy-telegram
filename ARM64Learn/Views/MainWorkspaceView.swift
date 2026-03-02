import SwiftUI

// MARK: - Main Workspace

struct MainWorkspaceView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            WorkspaceToolbar()

            Divider()

            // Three-panel layout
            HSplitView {
                // Panel 1: Tutorial Content
                TutorialContentView()
                    .frame(minWidth: 320)

                // Panel 2: Code Editor
                CodeEditorView()
                    .frame(minWidth: 320)

                // Panel 3: Memory Visualization
                MemoryLayoutView()
                    .frame(minWidth: 280)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom panel (expandable, spans panels 2 + 3)
            if appState.bottomPanelVisible {
                Divider()
                BottomPanelView()
                    .frame(height: appState.bottomPanelHeight)
            }
        }
        .background(.windowBackground)
    }
}

// MARK: - Workspace Toolbar

struct WorkspaceToolbar: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            // Tutorial title
            if let tut = appState.selectedTutorial {
                HStack(spacing: 6) {
                    Image(systemName: tut.difficulty.icon)
                        .foregroundStyle(tut.difficulty.color)
                    Text(tut.title)
                        .font(.headline)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(tut.difficulty.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select a tutorial")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Language picker
            Picker("Language", selection: $appState.codeLanguage) {
                ForEach(CodeLanguage.allCases) { lang in
                    Label(lang.rawValue, systemImage: lang.icon).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 230)

            Divider().frame(height: 20)

            // Build buttons
            Button {
                Task { await appState.compileCode() }
            } label: {
                Label("Build & Run", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(appState.isCompiling)
            .keyboardShortcut("b", modifiers: .command)

            Button {
                Task { await appState.compileAndDebug() }
            } label: {
                Label("Debug", systemImage: "ant.fill")
            }
            .buttonStyle(.bordered)
            .disabled(appState.isCompiling)

            Divider().frame(height: 20)

            // Bottom panel toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.bottomPanelVisible.toggle()
                }
            } label: {
                Image(systemName: appState.bottomPanelVisible ? "rectangle.bottomthird.inset.filled" : "rectangle.bottomthird.inset.filled")
                    .symbolVariant(appState.bottomPanelVisible ? .fill : .none)
            }
            .buttonStyle(.borderless)
            .help("Toggle bottom panel")

            if appState.isCompiling {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}
