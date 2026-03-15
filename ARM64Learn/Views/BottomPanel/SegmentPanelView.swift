import SwiftUI

// MARK: - Segment Panel View

/// Displays the merged Disassembly + __TEXT machine-code panel in the top-right area.
struct SegmentPanelView: View {
    var body: some View {
        DisassemblyView()
    }
}

#Preview("Segment Panel") {
    @Previewable @StateObject var previewAppState = AppState()

    SegmentPanelView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.liveDisassembly = [
                DisassemblyLine(address: 0x100003f58, offset: 0,  text: "stp    x29, x30, [sp, #-0x10]!", sourceLine: 5),
                DisassemblyLine(address: 0x100003f5c, offset: 4,  text: "mov    x29, sp",                   sourceLine: 5),
                DisassemblyLine(address: 0x100003f60, offset: 8,  text: "adrp   x0, 1",                     sourceLine: 6),
                DisassemblyLine(address: 0x100003f64, offset: 12, text: "add    x0, x0, #0x0",              sourceLine: 6),
            ]
            // liveTextEntries provide the raw bytes shown inline beside each instruction
            previewAppState.liveTextEntries = [
                (address: 0x100003f58, value: 0xa9bf7bfd_d10043ff),
                (address: 0x100003f60, value: 0x910003fd_90000000),
            ]
            previewAppState.currentExecutionAddress = 0x100003f5c
        }
        .frame(width: 600, height: 300)
}
