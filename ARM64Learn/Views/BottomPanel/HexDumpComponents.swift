import SwiftUI

// MARK: - Hex Dump Content

struct HexDumpContent: View {
    var body: some View {
        // Show placeholder message instead of sample data
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 4) {
                Text("No Live Data")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Start debugging to view memory contents")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
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
