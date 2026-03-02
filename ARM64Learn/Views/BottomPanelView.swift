import SwiftUI
import AppKit

// MARK: - Bottom Panel

struct BottomPanelView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle + tab bar
            HStack(spacing: 0) {
                // Resize handle
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 4)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let newHeight = appState.bottomPanelHeight - value.translation.height
                                appState.bottomPanelHeight = max(120, min(600, newHeight))
                            }
                    )
                    .cursor(.resizeUpDown)
            }

            HStack(spacing: 0) {
                // Tab bar
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

                    if appState.activeBottomTab == .output || appState.activeBottomTab == .lldb {
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

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.bottomPanelVisible = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .help("Close panel")
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
                    TerminalView()
                case .lldb:
                    LLDBView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.95))
    }

    private func clearCurrentTab() {
        switch appState.activeBottomTab {
        case .output:  appState.buildOutput = ""
        case .terminal: appState.terminalOutput = ""
        case .lldb:    appState.lldbOutput = ""
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

// MARK: - Build Output View

struct BuildOutputView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ConsoleTextView(text: appState.buildOutput)

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

// MARK: - LLDB View

struct LLDBView: View {
    @EnvironmentObject private var appState: AppState
    @State private var lldbInput = ""
    @State private var historyIndex = -1

    var body: some View {
        VStack(spacing: 0) {
            ConsoleTextView(text: appState.lldbOutput)

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
                        let cmd = lldbInput.trimmingCharacters(in: .whitespaces)
                        guard !cmd.isEmpty else { return }
                        appState.sendLLDBCommand(cmd)
                        lldbInput = ""
                        historyIndex = -1
                    }

                Button("Send") {
                    let cmd = lldbInput.trimmingCharacters(in: .whitespaces)
                    guard !cmd.isEmpty else { return }
                    appState.sendLLDBCommand(cmd)
                    lldbInput = ""
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
}

// MARK: - Terminal View

struct TerminalView: View {
    @EnvironmentObject private var appState: AppState
    @State private var terminalInput = ""

    var body: some View {
        VStack(spacing: 0) {
            ConsoleTextView(
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
                        let cmd = terminalInput.trimmingCharacters(in: .whitespaces)
                        guard !cmd.isEmpty else { return }
                        appState.sendTerminalInput(cmd)
                        terminalInput = ""
                    }

                Button("Run") {
                    let cmd = terminalInput.trimmingCharacters(in: .whitespaces)
                    guard !cmd.isEmpty else { return }
                    appState.sendTerminalInput(cmd)
                    terminalInput = ""
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
}

// MARK: - Console Text View (auto-scrolling output)

struct ConsoleTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        textView.textColor = NSColor(red: 0.80, green: 0.85, blue: 0.80, alpha: 1.0)
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Check if text actually changed to avoid unnecessary updates
        if context.coordinator.lastText == text {
            return
        }
        context.coordinator.lastText = text

        // Apply styled text with color coding
        let attributed = buildAttributedString(text)
        textView.textStorage?.setAttributedString(attributed)

        // Auto-scroll to bottom on next run loop
        textView.scrollToEndOfDocument(nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        weak var textView: NSTextView?
        var lastText: String = ""
    }

    private func buildAttributedString(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor(red: 0.80, green: 0.85, blue: 0.80, alpha: 1.0)
        ]

        let lines = text.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() {
            var attrs = baseAttrs
            // Color coding by content
            if line.contains("error:") || line.contains("FAILED") || line.contains("Error") {
                attrs[.foregroundColor] = NSColor.systemRed
            } else if line.contains("warning:") {
                attrs[.foregroundColor] = NSColor.systemYellow
            } else if line.contains("✓") || line.contains("succeeded") {
                attrs[.foregroundColor] = NSColor.systemGreen
            } else if line.hasPrefix("(lldb)") || line.hasPrefix("//") {
                attrs[.foregroundColor] = NSColor.systemBlue
            } else if line.hasPrefix("$") || line.hasPrefix(">") || line.hasPrefix("─") {
                attrs[.foregroundColor] = NSColor.systemCyan
            }

            result.append(NSAttributedString(string: line, attributes: attrs))
            if i < lines.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: baseAttrs))
            }
        }
        return result
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
