import SwiftUI

// MARK: - Memory Strip View (Registers | Stack | Heap)

/// Displays Registers, Stack, and Heap side-by-side in the bottom-right area.
/// All three views are always visible simultaneously.
struct MemoryStripView: View {
    var body: some View {
        HSplitView {
            RegisterPanelView()
                .frame(minWidth: 200)

            MemoryHexDumpView(segmentName: "STACK")
                .frame(minWidth: 200)

            MemoryHexDumpView(segmentName: "HEAP")
                .frame(minWidth: 200)
        }
    }
}

#Preview("Memory Strip") {
    @Previewable @StateObject var previewAppState = AppState()

    MemoryStripView()
        .environmentObject(previewAppState)
        .onAppear {
            previewAppState.liveStackEntries = [
                (address: 0x16fdff000, value: 0x0000000016fdff010),
                (address: 0x16fdff008, value: 0x0000000100003f80),
                (address: 0x16fdff010, value: 0x0000000000000042),
            ]
        }
        .frame(width: 900, height: 300)
}
