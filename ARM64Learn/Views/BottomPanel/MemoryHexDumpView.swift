import SwiftUI

// MARK: - Memory Hex Dump View (xxd-style)

struct MemoryHexDumpView: View {
    let segmentName: String
    @EnvironmentObject private var appState: AppState
    @State private var startAddress: UInt64 = 0
    @State private var bytesPerRow: Int = 16
    @State private var rowCount: Int = 32
    
    var segment: MemorySegment? {
        appState.memoryState.segments.first { $0.name == segmentName }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            MemoryHexDumpHeader(
                segment: segment,
                segmentName: segmentName,
                startAddress: $startAddress
            )
            
            Divider()
            
            // Hex dump content
            ScrollView {
                if segmentName == "STACK", !appState.liveStackEntries.isEmpty {
                    LiveStackDumpContent(entries: appState.liveStackEntries)
                } else if let seg = segment {
                    HexDumpContent(
                        segment: seg,
                        startAddress: startAddress == 0 ? seg.startAddress : startAddress,
                        bytesPerRow: bytesPerRow,
                        rowCount: rowCount
                    )
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                        Text("Memory segment '\(segmentName)' not found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.95))
        }
    }
}

// MARK: - Memory Hex Dump Header

struct MemoryHexDumpHeader: View {
    let segment: MemorySegment?
    let segmentName: String
    @Binding var startAddress: UInt64
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: segment?.systemImage ?? "square.grid.3x3")
                .foregroundStyle(segment?.color ?? .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(segment?.name ?? segmentName)
                    .font(.system(size: 13, weight: .semibold))
                if let seg = segment {
                    Text("\(seg.formattedStart) – \(seg.formattedEnd) (\(seg.formattedSize))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Address input
            HStack(spacing: 6) {
                Text("Address:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("0x", value: $startAddress, format: .number.notation(.scientific))
                    .font(.system(size: 11, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                
                Button {
                    if let seg = segment {
                        startAddress = seg.startAddress
                    }
                } label: {
                    Text("Reset")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

// Extension to add systemImage to MemorySegment
extension MemorySegment {
    var systemImage: String {
        switch name {
        case "STACK": return "square.stack.3d.down.right"
        case "HEAP": return "memorychip"
        case "__DATA": return "tablecells"
        case "__TEXT": return "doc.text"
        default: return "questionmark.square"
        }
    }
}

// MARK: - Live Stack Dump (from LLDB memory read)

/// Displays live stack contents read from LLDB (`memory read $sp --count 16 --size 8`).
/// Each entry is an 8-byte quadword; we expand into bytes for the standard hex dump rows.
struct LiveStackDumpContent: View {
    let entries: [(address: UInt64, value: UInt64)]

    /// Convert each 8-byte quadword into a `HexDumpRow`-compatible byte array (little-endian).
    private func bytes(for value: UInt64) -> [UInt8] {
        (0..<8).map { i in UInt8((value >> (i * 8)) & 0xFF) }
    }

    var body: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                    HexDumpRow(
                        address: entry.address,
                        data: bytes(for: entry.value),
                        bytesPerRow: 8
                    )
                    if idx < entries.count - 1 {
                        Divider().padding(.leading, 130)
                    }
                }
            } header: {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Image(systemName: "livephoto")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("Live stack — \(entries.count) quadwords from $sp")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.06))
                    HexDumpHeader(bytesPerRow: 8)
                }
            }
        }
        .padding(12)
    }
}

#Preview("Memory Hex Dump - Stack") {
    @Previewable @StateObject var previewAppState = AppState()
    
    MemoryHexDumpView(segmentName: "STACK")
        .environmentObject(previewAppState)
        .frame(width: 1000, height: 400)
}

#Preview("Memory Hex Dump - Text Segment") {
    @Previewable @StateObject var previewAppState = AppState()
    
    MemoryHexDumpView(segmentName: "__TEXT")
        .environmentObject(previewAppState)
        .frame(width: 1000, height: 400)
}
