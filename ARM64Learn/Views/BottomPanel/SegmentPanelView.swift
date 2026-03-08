import SwiftUI

// MARK: - Segment Panel View (__DATA on top, __TEXT on bottom)

/// Displays __DATA and __TEXT hex dumps stacked vertically in the top-right area.
struct SegmentPanelView: View {
    var body: some View {
        VSplitView {
            MemoryHexDumpView(segmentName: "__DATA")
                .frame(minHeight: 80)

            MemoryHexDumpView(segmentName: "__TEXT")
                .frame(minHeight: 80)
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
            previewAppState.liveTextEntries = [
                (address: 0x100003f5c, value: 0xa9bf7bfd_d10043ff),
                (address: 0x100003f64, value: 0x910003fd_90000000),
            ]
        }
        .frame(width: 500, height: 500)
}
