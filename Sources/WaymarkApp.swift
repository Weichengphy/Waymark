import SwiftUI
import AppKit

@main
struct WaymarkApp: App {
    @State private var store = DataStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("在访达中显示数据文件夹") {
                    NSWorkspace.shared.activateFileViewerSelecting([DataStore.appFolder])
                }
            }
        }
    }
}

/// A SwiftPM-built binary isn't launched the way a bundled app is, so without
/// this it starts as a background process with no menu bar and no focused
/// window. Promoting it to `.regular` and activating gives normal app behavior.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
