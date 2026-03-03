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
                if let seg = segment {
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
