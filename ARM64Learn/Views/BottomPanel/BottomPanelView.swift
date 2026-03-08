import SwiftUI
import AppKit

// MARK: - Bottom Panel (Tabbed Console: Build Output / Terminal / LLDB)

struct BottomPanelView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                HStack(spacing: 1) {
                    ForEach(BottomPanelTab.allCases) { tab in
                        BottomTabButton(
                            tab: tab,
                            isSelected: appState.activeBottomTab == tab
                        ) {
                            appState.activeBottomTab = tab
                            if tab == .terminal {
                                appState.startTerminalIfNeeded()
                            }
                        }
                    }
                }
                .padding(.leading, 8)

                Spacer()

                // Panel controls
                HStack(spacing: 6) {
                    if appState.activeBottomTab == .output {
                        Button {
                            Task { await appState.compileCode() }
                        } label: {
                            Label("Build & Run", systemImage: "play.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(appState.isCompiling)

                        Button {
                            Task { await appState.compileAndDebug() }
                        } label: {
                            Label("Debug", systemImage: "ant.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(appState.isCompiling)
                    }

                    Button {
                        Task { @MainActor in
                            clearCurrentTab()
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear output")
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 34)
            .background(.regularMaterial)

            Divider()

            // Tab content
            Group {
                switch appState.activeBottomTab {
                case .output:
                    BuildOutputView()
                case .terminal:
                    TerminalPanelView()
                case .lldb:
                    LLDBDebuggerView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.95))
    }

    private func clearCurrentTab() {
        switch appState.activeBottomTab {
        case .output:   appState.buildOutput = ""
        case .terminal: appState.terminalOutput = ""
        case .lldb:     appState.lldbOutput = ""
        }
    }
}

// MARK: - Tab Button

struct BottomTabButton: View {
    let tab: BottomPanelTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.systemImage)
                    .font(.caption)
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(isSelected ? Color.accentColor : .clear)
                    .offset(y: 14),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}



// MARK: - Cursor helper

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
#Preview("Bottom Panel - Output") {
    @Previewable @StateObject var previewAppState = AppState()
    
    BottomPanelView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.activeBottomTab = .output
            previewAppState.buildOutput = """
            Building...
            Compiling main.s
            Linking...
            Build succeeded!
            """
        }
        .frame(width: 1000, height: 250)
}

#Preview("Bottom Panel - Debugger") {
    @Previewable @StateObject var previewAppState = AppState()
    
    BottomPanelView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.activeBottomTab = .lldb
            previewAppState.lldbOutput = """
            Breakpoint 1 hit at 0x100003f80
            x0: 0x0000000000000000
            x1: 0x0000000000000001
            x2: 0x0000000000000002
            """
        }
        .frame(width: 1000, height: 250)
}

#Preview("Bottom Panel - Terminal") {
    @Previewable @StateObject var previewAppState = AppState()
    
    BottomPanelView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.activeBottomTab = .terminal
            previewAppState.terminalOutput = """
            $ ./a.out
            Hello, ARM64 World!
            Exit code: 0
            """
        }
        .frame(width: 1000, height: 250)
}



