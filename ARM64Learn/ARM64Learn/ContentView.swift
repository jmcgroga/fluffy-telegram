import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .environmentObject(appState)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            MainWorkspaceView()
                .environmentObject(appState)
        }
        .navigationSplitViewStyle(.balanced)
        .onReceive(NotificationCenter.default.publisher(for: .compileCode)) { _ in
            Task { await appState.compileCode() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .compileAndDebug)) { _ in
            Task { await appState.compileAndDebug() }
        }
    }
}
