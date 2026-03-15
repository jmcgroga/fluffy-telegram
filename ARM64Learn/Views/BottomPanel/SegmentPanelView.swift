import SwiftUI

// MARK: - Segment Panel View (Disassembly | __TEXT side-by-side)

/// Displays the disassembly view and the __TEXT hex dump side-by-side in the top-right area.
struct SegmentPanelView: View {
    var body: some View {
        HSplitView {
            DisassemblyView()
                .frame(minWidth: 200)

            MemoryHexDumpView(segmentName: "__TEXT")
                .frame(minWidth: 160)
        }
    }
}

#Preview("Segment Panel") {
    @Previewable @StateObject var previewAppState = AppState()

    SegmentPanelView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.liveDataEntries = [
                (address: 0x100008000, value: 0x41202c6f6c6c6548),
                (address: 0x100008008, value: 0x726f572034364d52),
            ]
            previewAppState.liveDisassembly = [
                DisassemblyLine(address: 0x100003f58, offset: 0,  text: "stp    x29, x30, [sp, #-0x10]!", sourceLine: 5),
                DisassemblyLine(address: 0x100003f5c, offset: 4,  text: "mov    x29, sp",                   sourceLine: 5),
                DisassemblyLine(address: 0x100003f60, offset: 8,  text: "adrp   x0, 1",                     sourceLine: 6),
                DisassemblyLine(address: 0x100003f64, offset: 12, text: "add    x0, x0, #0x0",              sourceLine: 6),
            ]
            previewAppState.currentExecutionAddress = 0x100003f5c
        }
        .frame(width: 500, height: 500)
}
