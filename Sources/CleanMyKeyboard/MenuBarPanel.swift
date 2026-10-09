import AppKit
import SwiftUI

struct MenuBarPanel: View {
    @EnvironmentObject private var blocker: KeyboardBlocker
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(blocker.isBlocking ? "Cleaning \u{00B7} \(blocker.formattedElapsed)" : "Keyboard active")
        Button(blocker.isBlocking ? "Stop and restore keyboard" : "Start cleaning") {
            blocker.toggleBlocking()
        }
        Divider()
        Button("Open main window") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        Button("Quit") {
            blocker.stopBlocking()
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
