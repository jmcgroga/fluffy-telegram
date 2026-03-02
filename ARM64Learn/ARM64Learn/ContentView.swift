import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var showSidebar = false

    var body: some View {
        ZStack(alignment: .leading) {
            // Main workspace (always visible)
            MainWorkspaceView()
                .environmentObject(appState)
            
            // Sliding sidebar overlay
            if showSidebar {
                // Dimmed background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSidebar = false
                        }
                    }
                
                // Sidebar panel
                SidebarView(isPresented: $showSidebar)
                    .environmentObject(appState)
                    .frame(width: 280)
                    .background(.regularMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 5, y: 0)
                    .transition(.move(edge: .leading))
            }
        }
        .environmentObject(appState)
        .environment(\.sidebarToggle, SidebarToggle(isShowing: $showSidebar))
        .onReceive(NotificationCenter.default.publisher(for: .compileCode)) { _ in
            Task { await appState.compileCode() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .compileAndDebug)) { _ in
            Task { await appState.compileAndDebug() }
        }
    }
}

// MARK: - Sidebar Toggle Environment

struct SidebarToggle {
    var isShowing: Binding<Bool>
    
    func toggle() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isShowing.wrappedValue.toggle()
        }
    }
}

struct SidebarToggleKey: EnvironmentKey {
    static let defaultValue = SidebarToggle(isShowing: .constant(false))
}

extension EnvironmentValues {
    var sidebarToggle: SidebarToggle {
        get { self[SidebarToggleKey.self] }
        set { self[SidebarToggleKey.self] = newValue }
    }
}
