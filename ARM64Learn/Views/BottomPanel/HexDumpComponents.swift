import SwiftUI

// MARK: - Hex Dump Content

struct HexDumpContent: View {
    let segment: MemorySegment
    let startAddress: UInt64
    let bytesPerRow: Int
    let rowCount: Int
    
    var body: some View {
        let data = generateSampleData()
        
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                ForEach(0..<rowCount, id: \.self) { row in
                    let address = startAddress + UInt64(row * bytesPerRow)
                    let rowStart = row * bytesPerRow
                    let rowEnd = min(rowStart + bytesPerRow, data.count)
                    
                    if rowStart < data.count {
                        HexDumpRow(
                            address: address,
                            data: Array(data[rowStart..<rowEnd]),
                            bytesPerRow: bytesPerRow
                        )
                        
                        if row < rowCount - 1 {
                            Divider()
                                .padding(.leading, 130)
                        }
                    }
                }
            } header: {
                HexDumpHeader(bytesPerRow: bytesPerRow)
            }
        }
        .padding(12)
    }
    
    // Generate sample memory data (in real app, this would come from actual memory)
    private func generateSampleData() -> [UInt8] {
        var data: [UInt8] = []
        let totalBytes = bytesPerRow * rowCount
        
        // Generate different patterns based on segment type
        switch segment.name {
        case "__TEXT":
            data = generateTextSegmentData(totalBytes: totalBytes)
        case "__DATA":
            data = generateDataSegmentData(totalBytes: totalBytes)
        case "STACK":
            data = generateStackData(totalBytes: totalBytes)
        case "HEAP":
            data = generateHeapData(totalBytes: totalBytes)
        default:
            // Generic data
            for i in 0..<totalBytes {
                data.append(UInt8(i % 256))
            }
        }
        
        return data
    }
    
    private func generateTextSegmentData(totalBytes: Int) -> [UInt8] {
        var data: [UInt8] = []
        
        // Simulate ARM64 instructions
        let instructions: [UInt32] = [
            0xD10043FF, // sub sp, sp, #16
            0xA9007BFD, // stp x29, x30, [sp]
            0x910003FD, // mov x29, sp
            0x90000000, // adrp x0, ...
            0x91000000, // add x0, x0, #...
            0x94000000, // bl _puts
            0xD2800000, // mov x0, #0
            0xA9407BFD, // ldp x29, x30, [sp]
            0x910043FF, // add sp, sp, #16
            0xD65F03C0, // ret
        ]
        
        for i in 0..<totalBytes {
            if i < instructions.count * 4 {
                let instIndex = i / 4
                let byteIndex = i % 4
                data.append(UInt8((instructions[instIndex] >> (byteIndex * 8)) & 0xFF))
            } else {
                // String data
                let str = "Hello, ARM64!\0"
                let strIndex = (i - instructions.count * 4) % str.count
                data.append(UInt8(str.utf8[str.utf8.index(str.utf8.startIndex, offsetBy: strIndex)]))
            }
        }
        
        return data
    }
    
    private func generateDataSegmentData(totalBytes: Int) -> [UInt8] {
        var data: [UInt8] = []
        
        for i in 0..<totalBytes {
            if i < 8 {
                // Global pointer
                data.append(UInt8((0x0000000100000000 >> (i * 8)) & 0xFF))
            } else if i < 16 {
                // Counter variable
                data.append(UInt8((42 >> ((i - 8) * 8)) & 0xFF))
            } else {
                data.append(0x00) // Zero-initialized
            }
        }
        
        return data
    }
    
    private func generateStackData(totalBytes: Int) -> [UInt8] {
        var data: [UInt8] = []
        
        for i in 0..<totalBytes {
            if i < 8 {
                // Saved frame pointer
                let fp: UInt64 = 0x16B9E3010
                data.append(UInt8((fp >> (i * 8)) & 0xFF))
            } else if i < 16 {
                // Saved link register
                let lr: UInt64 = 0x0000000100003F80
                data.append(UInt8((lr >> ((i - 8) * 8)) & 0xFF))
            } else if i < 24 {
                // Local variable
                data.append(UInt8(i - 16))
            } else {
                data.append(0xAA) // Uninitialized stack memory pattern
            }
        }
        
        return data
    }
    
    private func generateHeapData(totalBytes: Int) -> [UInt8] {
        var data: [UInt8] = []
        
        for i in 0..<totalBytes {
            if i % 32 == 0 && i + 8 <= totalBytes {
                // Heap metadata (size/flags)
                let size: UInt64 = 0x0000000000000020
                for j in 0..<8 {
                    data.append(UInt8((size >> (j * 8)) & 0xFF))
                }
            } else if data.count < totalBytes {
                // Heap content
                data.append(UInt8(i % 256))
            }
        }
        
        return data
    }
}

// MARK: - Hex Dump Header

struct HexDumpHeader: View {
    let bytesPerRow: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Address column header
            Text("ADDRESS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 110, alignment: .leading)
            
            // Hex column headers
            HStack(spacing: 4) {
                ForEach(0..<bytesPerRow, id: \.self) { i in
                    Text(String(format: "%X", i))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                }
            }
            
            Spacer()
            
            // ASCII column header
            Text("ASCII")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: CGFloat(bytesPerRow) * 7, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }
}

// MARK: - Hex Dump Row

struct HexDumpRow: View {
    let address: UInt64
    let data: [UInt8]
    let bytesPerRow: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Address
            Text(String(format: "%011X", address))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            
            // Hex bytes
            HStack(spacing: 4) {
                ForEach(0..<bytesPerRow, id: \.self) { i in
                    if i < data.count {
                        Text(String(format: "%02X", data[i]))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(colorForByte(data[i]))
                            .frame(width: 20)
                    } else {
                        Text("  ")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 20)
                    }
                    
                    // Add separator every 8 bytes
                    if i == 7 && bytesPerRow == 16 {
                        Text(" ")
                            .frame(width: 4)
                    }
                }
            }
            
            Spacer()
            
            // ASCII representation
            HStack(spacing: 0) {
                ForEach(0..<bytesPerRow, id: \.self) { i in
                    if i < data.count {
                        Text(asciiChar(data[i]))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(isPrintable(data[i]) ? .primary : .tertiary)
                            .frame(width: 7)
                    } else {
                        Text(" ")
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 7)
                    }
                    
                    // Add separator every 8 bytes
                    if i == 7 && bytesPerRow == 16 {
                        Text(" ")
                            .frame(width: 4)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
    }
    
    private func colorForByte(_ byte: UInt8) -> Color {
        if byte == 0x00 {
            return .secondary.opacity(0.5)
        } else if isPrintable(byte) {
            return .green
        } else {
            return .primary
        }
    }
    
    private func isPrintable(_ byte: UInt8) -> Bool {
        byte >= 0x20 && byte <= 0x7E
    }
    
    private func asciiChar(_ byte: UInt8) -> String {
        if isPrintable(byte) {
            return String(UnicodeScalar(byte))
        } else {
            return "."
        }
    }
}
