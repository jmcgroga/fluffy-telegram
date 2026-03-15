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
            
            // Hex dump content — each live content view owns its own scroll view
            if segmentName == "STACK", !appState.liveStackEntries.isEmpty {
                LiveStackDumpContent(entries: appState.liveStackEntries,
                                     spAddress: appState.currentSP)
            } else if segmentName == "__DATA", !appState.liveDataEntries.isEmpty {
                LiveStackDumpContent(entries: appState.liveDataEntries)
            } else if segmentName == "__TEXT", !appState.liveTextEntries.isEmpty {
                LiveTextDumpContent(
                    entries: appState.liveTextEntries,
                    highlightAddress: appState.currentExecutionAddress
                )
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
/// When `highlightAddress` is set, the 4-byte ARM64 instruction at that address
/// is highlighted within its containing 8-byte quadword row.
/// When `spAddress` is set, the row whose address matches SP gets a ▶ indicator
/// and the view auto-scrolls to keep that row visible whenever SP changes.
struct LiveStackDumpContent: View {
    let entries: [(address: UInt64, value: UInt64)]
    var highlightAddress: UInt64? = nil
    var spAddress: UInt64? = nil

    private var segmentName: String {
        guard let firstAddress = entries.first?.address else { return "memory" }
        if firstAddress >= 0x100000000 && firstAddress < 0x100010000 {
            return "text section"
        } else if firstAddress >= 0x1_0000_0000 && firstAddress < 0x2_0000_0000 {
            return "data section"
        } else {
            return "stack"
        }
    }

    /// ARM64 instructions are always 4 bytes and 4-byte aligned.
    /// Returns the byte range [0-3] or [4-7] within the 8-byte quadword that
    /// contains the instruction at `highlightAddress`, or nil if not in this row.
    private func highlightByteRange(for quadwordAddr: UInt64) -> Range<Int>? {
        guard let pc = highlightAddress else { return nil }
        guard (pc & ~UInt64(7)) == quadwordAddr else { return nil }
        let byteOffset = Int(pc & 7)   // 0 or 4 for 4-byte-aligned ARM64
        return byteOffset..<(byteOffset + 4)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "livephoto")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text("Live \(segmentName) — \(entries.count) quadwords")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(.regularMaterial)
                        Divider()
                        ForEach(Array(entries.enumerated()), id: \.element.address) { idx, entry in
                            VStack(spacing: 0) {
                                StackQuadwordRow(
                                    address: entry.address,
                                    value: entry.value,
                                    isSP: entry.address == spAddress,
                                    highlightByteRange: highlightByteRange(for: entry.address)
                                )
                                if idx < entries.count - 1 {
                                    Divider().padding(.leading, 156)
                                }
                            }
                            .id(entry.address)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .topLeading)
                }
                .background(Color(nsColor: .textBackgroundColor).opacity(0.95))
                .onChange(of: spAddress) { _, newSP in
                    guard let sp = newSP else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(sp, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Stack Quadword Row

struct StackQuadwordRow: View {
    let address: UInt64
    let value: UInt64
    /// Whether this row's address is the current stack pointer.
    var isSP: Bool = false
    /// Optional byte range [0-7] within this quadword to highlight (e.g. a 4-byte ARM64 instruction).
    var highlightByteRange: Range<Int>? = nil

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
            // SP indicator — mirrors the ▶ used for the current instruction in DisassemblyView
            Text(isSP ? "▶" : " ")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 12)
                .foregroundStyle(isSP ? Color.orange : Color.clear)

            // Address (16 hex digits, no 0x prefix)
            Text(String(format: "%016llX:", address))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(isSP ? Color.primary : Color.secondary)
                .frame(width: 140, alignment: .leading)

            // Hex bytes — per-byte Text views so individual bytes can be highlighted
            HStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { i in
                    let highlighted = highlightByteRange?.contains(i) == true
                    Text(String(format: "%02x", bytes[i]))
                        .font(.system(size: 11,
                                      weight: highlighted ? .semibold : .regular,
                                      design: .monospaced))
                        .foregroundStyle(highlighted ? Color.orange : Color.primary)
                        .padding(.horizontal, 1)
                        .background(
                            highlighted ? Color.orange.opacity(0.18) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 2)
                        )
                }
                Spacer()
            }
            .frame(width: 180, alignment: .leading)

            // ASCII representation
            Text(asciiString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isSP ? Color.orange.opacity(0.12) : Color.clear)
    }
}

// MARK: - Live Text Dump (32-bit instruction rows)

/// Displays live __TEXT memory as 4-byte instruction rows, one ARM64 instruction per row.
/// Highlights the row whose address matches `highlightAddress` (the current PC).
struct LiveTextDumpContent: View {
    let entries: [(address: UInt64, value: UInt64)]
    var highlightAddress: UInt64? = nil

    /// Expand each 8-byte entry into two 4-byte instruction rows (little-endian).
    private var instructionRows: [(address: UInt64, word: UInt32)] {
        entries.flatMap { entry -> [(address: UInt64, word: UInt32)] in
            let lo = UInt32(entry.value & 0xFFFF_FFFF)
            let hi = UInt32((entry.value >> 32) & 0xFFFF_FFFF)
            return [
                (address: entry.address,     word: lo),
                (address: entry.address + 4, word: hi),
            ]
        }
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "livephoto")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text("Live __text — \(instructionRows.count) instructions")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(.regularMaterial)
                        Divider()
                        ForEach(Array(instructionRows.enumerated()), id: \.element.address) { idx, row in
                            VStack(spacing: 0) {
                                TextInstructionRow(
                                    address: row.address,
                                    word: row.word,
                                    isPC: row.address == highlightAddress
                                )
                                if idx < instructionRows.count - 1 {
                                    Divider().padding(.leading, 168)
                                }
                            }
                            .id(row.address)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .topLeading)
                }
                .background(Color(nsColor: .textBackgroundColor).opacity(0.95))
                .onChange(of: highlightAddress) { _, newPC in
                    guard let pc = newPC else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(pc, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Text Instruction Row (4-byte / 32-bit)

struct TextInstructionRow: View {
    let address: UInt64
    let word: UInt32
    var isPC: Bool = false

    private var bytes: [UInt8] {
        (0..<4).map { i in UInt8((word >> (i * 8)) & 0xFF) }
    }

    private var asciiString: String {
        bytes.map { byte in
            (32...126).contains(byte) ? String(UnicodeScalar(byte)) : "."
        }.joined()
    }

    var body: some View {
        HStack(spacing: 12) {
            // PC indicator
            Text(isPC ? "▶" : " ")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 12)
                .foregroundStyle(isPC ? Color.orange : Color.clear)

            // Address (16 hex digits, no 0x prefix)
            Text(String(format: "%016llX:", address))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(isPC ? Color.primary : Color.secondary)
                .frame(width: 140, alignment: .leading)

            // 4 hex bytes
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    Text(String(format: "%02x", bytes[i]))
                        .font(.system(size: 11,
                                      weight: isPC ? .semibold : .regular,
                                      design: .monospaced))
                        .foregroundStyle(isPC ? Color.orange : Color.primary)
                        .padding(.horizontal, 1)
                        .background(
                            isPC ? Color.orange.opacity(0.18) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 2)
                        )
                }
                Spacer()
            }
            .frame(width: 90, alignment: .leading)

            // ASCII representation
            Text(asciiString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isPC ? Color.orange.opacity(0.12) : Color.clear)
    }
}

#Preview("Memory Hex Dump - Stack") {
    @Previewable @StateObject var previewAppState = AppState()
    
    MemoryHexDumpView(segmentName: "STACK")
        .environmentObject(previewAppState)
        .onAppear {
            // Entries stored low → high; the view reverses them so SP appears near bottom.
            previewAppState.liveStackEntries = [
                (address: 0x16fdff000, value: 0x0000000016fdff020), // SP → saved FP
                (address: 0x16fdff008, value: 0x0000000100003f80),  // saved LR
                (address: 0x16fdff010, value: 0x0000000000000042),  // local var
                (address: 0x16fdff018, value: 0x0000000000000001),  // local var
            ]
            // Set preview SP to first entry so the indicator is visible
            previewAppState.memoryState.registers.indices.forEach { i in
                if previewAppState.memoryState.registers[i].name == "sp" {
                    previewAppState.memoryState.registers[i].value = 0x16fdff000
                }
            }
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


