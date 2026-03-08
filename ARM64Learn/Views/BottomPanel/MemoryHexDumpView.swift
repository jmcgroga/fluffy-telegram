import SwiftUI

// MARK: - Memory Hex Dump View (xxd-style)

struct MemoryHexDumpView: View {
    let segmentName: String
    @EnvironmentObject private var appState: AppState
    
    var segment: MemorySegment? {
        appState.memoryState.segments.first { $0.name == segmentName }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            MemoryHexDumpHeader(
                segment: segment,
                segmentName: segmentName
            )
            
            Divider()
            
            // Hex dump content
            ScrollView {
                if segmentName == "STACK", !appState.liveStackEntries.isEmpty {
                    LiveStackDumpContent(entries: appState.liveStackEntries)
                } else if segmentName == "__DATA", !appState.liveDataEntries.isEmpty {
                    LiveStackDumpContent(entries: appState.liveDataEntries)
                } else if segmentName == "__TEXT", !appState.liveTextEntries.isEmpty {
                    LiveStackDumpContent(entries: appState.liveTextEntries)
                } else if segment != nil {
                    HexDumpContent()
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

/// Displays live memory contents read from LLDB (`memory read`).
/// Shows each 8-byte quadword as a complete 64-bit value.
struct LiveStackDumpContent: View {
    let entries: [(address: UInt64, value: UInt64)]
    
    private var segmentName: String {
        // Determine segment name based on address range
        guard let firstAddress = entries.first?.address else { return "memory" }
        // Text section is typically in the lower address range (around 0x100000000 on macOS)
        if firstAddress >= 0x100000000 && firstAddress < 0x100010000 {
            return "text section"
        } else if firstAddress >= 0x1_0000_0000 && firstAddress < 0x2_0000_0000 {
            return "data section"
        } else {
            return "stack"
        }
    }

    var body: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                    StackQuadwordRow(address: entry.address, value: entry.value)
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
                        Text("Live \(segmentName) — \(entries.count) quadwords")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.regularMaterial)
                    Divider()
                }
            }
        }
        .padding(.top, 1)
    }
}

// MARK: - Stack Quadword Row

struct StackQuadwordRow: View {
    let address: UInt64
    let value: UInt64
    
    // Convert 64-bit value to little-endian bytes
    private var bytes: [UInt8] {
        (0..<8).map { i in UInt8((value >> (i * 8)) & 0xFF) }
    }
    
    // ASCII representation (printable chars only)
    private var asciiString: String {
        bytes.map { byte in
            (32...126).contains(byte) ? String(UnicodeScalar(byte)) : "."
        }.joined()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Address (16 hex digits, no 0x prefix)
            Text(String(format: "%016llX:", address))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            
            // Hex bytes (8 bytes, little-endian)
            Text(bytes.map { String(format: "%02x", $0) }.joined(separator: " "))
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 180, alignment: .leading)
            
            // ASCII representation
            Text(asciiString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

#Preview("Memory Hex Dump - Stack") {
    @Previewable @StateObject var previewAppState = AppState()
    
    MemoryHexDumpView(segmentName: "STACK")
        .environmentObject(previewAppState)
        .onAppear {
            // Add sample stack data for preview
            previewAppState.liveStackEntries = [
                (address: 0x16fdff000, value: 0x0000000016fdff010),  // Saved FP
                (address: 0x16fdff008, value: 0x0000000100003f80),  // Saved LR
                (address: 0x16fdff010, value: 0x0000000000000042),  // Local var
                (address: 0x16fdff018, value: 0x0000000000000001),  // Local var
            ]
        }
        .frame(width: 1000, height: 400)
}

#Preview("Memory Hex Dump - Data Segment") {
    @Previewable @StateObject var previewAppState = AppState()
    
    MemoryHexDumpView(segmentName: "__DATA")
        .environmentObject(previewAppState)
        .onAppear {
            // Add sample data segment for preview - "Hello, ARM64 World!" string
            previewAppState.liveDataEntries = [
                (address: 0x100008000, value: 0x41202c6f6c6c6548),  // "Hello, A"
                (address: 0x100008008, value: 0x726f572034364d52),  // "RM64 Wor"
                (address: 0x100008010, value: 0x0000000000216c64),  // "ld!\0\0\0\0\0"
            ]
        }
        .frame(width: 1000, height: 400)
}
#Preview("Memory Hex Dump - Text Segment") {
    @Previewable @StateObject var previewAppState = AppState()
    
    MemoryHexDumpView(segmentName: "__TEXT")
        .environmentObject(previewAppState)
        .onAppear {
            // Add sample text segment for preview - ARM64 machine code
            // These are actual ARM64 instructions
            previewAppState.liveTextEntries = [
                (address: 0x100003f5c, value: 0xa9bf7bfd_d10043ff),  // stp x29,x30,[sp,#-16]!; sub sp,sp,#16
                (address: 0x100003f64, value: 0x910003fd_90000000),  // mov x29,sp; adrp x0,...
                (address: 0x100003f6c, value: 0x91000000_94000000),  // add x0,x0,...; bl ...
                (address: 0x100003f74, value: 0xd2800000_a8c17bfd),  // mov x0,#0; ldp x29,x30,[sp],#16
                (address: 0x100003f7c, value: 0xd65f03c0_00000000),  // ret
            ]
        }
        .frame(width: 1000, height: 400)
}


