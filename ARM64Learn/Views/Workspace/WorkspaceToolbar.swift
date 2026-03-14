import SwiftUI

// MARK: - Workspace Toolbar

struct WorkspaceToolbar: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.sidebarToggle) private var sidebarToggle
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 12) {
            // Sidebar toggle button (tutorial list)
            Button {
                sidebarToggle.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .symbolVariant(sidebarToggle.isShowing.wrappedValue ? .fill : .none)
            }
            .buttonStyle(.borderless)
            .help("Toggle tutorial list")
            .keyboardShortcut("s", modifiers: [.command, .control])
            
            Divider().frame(height: 20)
            
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

            DebuggerControlBar()

            Divider().frame(height: 20)

            // Panel visibility toggles
            HStack(spacing: 4) {
                // Tutorial panel toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.tutorialPanelVisible.toggle()
                    }
                } label: {
                    Image(systemName: "doc.text")
                        .symbolVariant(appState.tutorialPanelVisible ? .fill : .none)
                }
                .buttonStyle(.borderless)
                .help("Toggle tutorial panel (\(appState.tutorialPanelVisible ? "Hide" : "Show"))")
                .keyboardShortcut("1", modifiers: [.command, .option])

                // Output window toggle
                Button {
                    openWindow(id: "output-window")
                } label: {
                    Image(systemName: "terminal.fill")
                }
                .buttonStyle(.borderless)
                .help("Open output window")
                .keyboardShortcut("2", modifiers: [.command, .option])
            }

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

#Preview("Workspace Toolbar") {
    @Previewable @StateObject var previewAppState = AppState()
    
    WorkspaceToolbar()
        .environmentObject(previewAppState)
        .environment(\.sidebarToggle, SidebarToggle(isShowing: .constant(false)))
        .frame(width: 1200)
}
