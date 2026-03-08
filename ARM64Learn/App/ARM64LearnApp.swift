import SwiftUI
import AppKit

@main
struct ARM64LearnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appState)
                .frame(minWidth: 1280, minHeight: 800)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Build") {
                Button("Compile") {
                    NotificationCenter.default.post(name: .compileCode, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Compile & Debug") {
                    NotificationCenter.default.post(name: .compileAndDebug, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
            }
        }

        Window("Output", id: "output-window") {
            OutputWindowView()
                .environmentObject(appState)
                .frame(minWidth: 600, minHeight: 300)
        }
        .defaultSize(width: 800, height: 400)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension Notification.Name {
    static let compileCode = Notification.Name("compileCode")
    static let compileAndDebug = Notification.Name("compileAndDebug")
}
