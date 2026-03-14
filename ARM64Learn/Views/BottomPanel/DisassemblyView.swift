import SwiftUI

// MARK: - Display Item

private enum DisassemblyItem: Identifiable {
    case sourceMarker(id: UUID, sourceLine: Int)
    case instruction(DisassemblyLine)

    var id: UUID {
        switch self {
        case .sourceMarker(let id, _): return id
        case .instruction(let line): return line.id
        }
    }
}

private func buildItems(from lines: [DisassemblyLine]) -> [DisassemblyItem] {
    var items: [DisassemblyItem] = []
    var lastSourceLine: Int? = nil
    for line in lines {
        if let sl = line.sourceLine, sl != lastSourceLine {
            items.append(.sourceMarker(id: UUID(), sourceLine: sl))
            lastSourceLine = sl
        }
        items.append(.instruction(line))
    }
    return items
}

// MARK: - DisassemblyView

struct DisassemblyView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            DisassemblyHeader()
            if appState.liveDisassembly.isEmpty {
                DisassemblyEmptyView()
            } else {
                DisassemblyColumnHeader()
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            let items = buildItems(from: appState.liveDisassembly)
                            ForEach(items) { item in
                                switch item {
                                case .sourceMarker(_, let sourceLine):
                                    DisassemblySourceMarkerRow(sourceLine: sourceLine)
                                case .instruction(let line):
                                    DisassemblyInstructionRow(
                                        line: line,
                                        isCurrent: line.address == appState.currentExecutionAddress
                                    )
                                    .id(line.id)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: appState.currentExecutionAddress) { _, newPC in
                        if let pc = newPC,
                           let line = appState.liveDisassembly.first(where: { $0.address == pc }) {
                            withAnimation { proxy.scrollTo(line.id, anchor: .center) }
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Header

private struct DisassemblyHeader: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "cpu.fill")
                .foregroundStyle(.blue)
            Text("Disassembly")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Column Header

private struct DisassemblyColumnHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            // ▶ indicator column
            Text("")
                .frame(width: 16)
            // Address
            Text("ADDRESS")
                .frame(width: 90, alignment: .leading)
            // Offset
            Text("OFFSET")
                .frame(width: 50, alignment: .leading)
            // Instruction
            Text("INSTRUCTION")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Instruction Row

private struct DisassemblyInstructionRow: View {
    let line: DisassemblyLine
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Current-instruction indicator
            Text(isCurrent ? "▶" : " ")
                .frame(width: 16)
                .foregroundStyle(isCurrent ? Color.yellow : Color.clear)

            // Address
            Text(String(format: "%016llX", line.address))
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(isCurrent ? .primary : .secondary)

            // Offset
            Text("+\(line.offset)")
                .frame(width: 50, alignment: .leading)
                .foregroundStyle(.secondary)

            // Instruction text
            Text(line.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.primary)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .background(isCurrent ? Color.yellow.opacity(0.18) : Color.clear)
    }
}

// MARK: - Source Marker Row

private struct DisassemblySourceMarkerRow: View {
    let sourceLine: Int

    var body: some View {
        Text(";; line \(sourceLine)")
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .italic()
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

// MARK: - Empty State

private struct DisassemblyEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "cpu")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("Start debugging to view disassembly")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview("Disassembly View") {
    @Previewable @StateObject var previewAppState = AppState()

    DisassemblyView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.liveDisassembly = [
                DisassemblyLine(address: 0x100003f58, offset: 0,  text: "stp    x29, x30, [sp, #-0x10]!", sourceLine: 5),
                DisassemblyLine(address: 0x100003f5c, offset: 4,  text: "mov    x29, sp",                   sourceLine: 5),
                DisassemblyLine(address: 0x100003f60, offset: 8,  text: "adrp   x0, 1",                     sourceLine: 6),
                DisassemblyLine(address: 0x100003f64, offset: 12, text: "add    x0, x0, #0x0",              sourceLine: 6),
                DisassemblyLine(address: 0x100003f68, offset: 16, text: "bl     0x100003f80",               sourceLine: 7),
                DisassemblyLine(address: 0x100003f6c, offset: 20, text: "mov    x0, #0x0",                  sourceLine: 8),
                DisassemblyLine(address: 0x100003f70, offset: 24, text: "ldp    x29, x30, [sp], #0x10",     sourceLine: 9),
                DisassemblyLine(address: 0x100003f74, offset: 28, text: "ret",                              sourceLine: 9),
            ]
            previewAppState.currentExecutionAddress = 0x100003f60
        }
        .frame(width: 500, height: 300)
}
