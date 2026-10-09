import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var blocker: KeyboardBlocker

    var body: some View {
        VStack(spacing: 14) {
            header
            if !blocker.isAccessibilityTrusted { permissionCard }
            toggleButton
            if !blocker.isBlocking, let message = blocker.lastMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            footer
        }
        .padding(20)
        .frame(width: 360)
        .background(backgroundGradient)
        .onAppear {
            blocker.refreshAccessibilityStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            blocker.refreshAccessibilityStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(blocker.isBlocking ? Color.red.opacity(0.85) : Color.accentColor.opacity(0.85))
                    .frame(width: 38, height: 38)
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Clean My Keyboard")
                    .font(.headline)
                Text(blocker.isBlocking ? "Keyboard input is blocked" : "Block the keyboard to clean it")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var toggleButton: some View {
        Button {
            blocker.toggleBlocking()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: blocker.isBlocking ? "lock.slash" : "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                Text(blocker.isBlocking ? "Stop and restore keyboard" : "Start cleaning")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(blocker.isBlocking ? Color.red : Color.green)
            )
        }
        .buttonStyle(.plain)
        .shadow(color: (blocker.isBlocking ? Color.red : Color.green).opacity(0.35), radius: 8, y: 3)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Accessibility permission needed", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text("macOS requires Accessibility permission before this app can block the keyboard. Grant it, then click the button again.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Button("Request") { blocker.requestAccessibilityPermission() }
                Button("Open Settings") { blocker.openAccessibilitySettings() }
                Button("Recheck") { blocker.refreshAccessibilityStatus() }
            }
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Quit") {
                blocker.stopBlocking()
                NSApp.terminate(nil)
            }
            .controlSize(.small)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: blocker.isBlocking
                ? [Color.red.opacity(0.12), Color(nsColor: .windowBackgroundColor)]
                : [Color.accentColor.opacity(0.08), Color(nsColor: .windowBackgroundColor)],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }
}
