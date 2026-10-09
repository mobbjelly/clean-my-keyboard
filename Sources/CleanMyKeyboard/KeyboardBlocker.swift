import AppKit
import Combine
import CoreGraphics

/// Blocks keyboard input at the session level using a CGEventTap.
/// Mouse input is never touched, so the on-screen button always works.
final class KeyboardBlocker: ObservableObject {
    @Published private(set) var isBlocking = false
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var isAccessibilityTrusted = AXIsProcessTrusted()
    @Published private(set) var lastMessage: String?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var statusTimer: Timer?
    private var startedAt: Date?

    private static let blockedEventMask: CGEventMask = {
        // NX_SYSDEFINED (14) covers media, brightness and other system keys.
        let types: [CGEventType] = [
            .keyDown,
            .keyUp,
            .flagsChanged,
            CGEventType(rawValue: 14) ?? .keyDown,
        ]
        return types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
    }()

    deinit {
        removeEventTap()
    }

    // MARK: - Permissions

    func refreshAccessibilityStatus() {
        isAccessibilityTrusted = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshAccessibilityStatus()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Toggle

    func toggleBlocking() {
        if isBlocking {
            stopBlocking()
        } else {
            startBlocking()
        }
    }

    @discardableResult
    func startBlocking() -> Bool {
        guard !isBlocking else { return true }
        refreshAccessibilityStatus()

        if installEventTap() {
            isBlocking = true
            elapsedSeconds = 0
            startedAt = Date()
            lastMessage = nil
            startTimers()
            playSound(named: "Tink")
            return true
        }

        lastMessage = isAccessibilityTrusted
            ? "Could not create the keyboard event tap. Please try again."
            : "Accessibility permission is required to block the keyboard."
        return false
    }

    func stopBlocking() {
        guard isBlocking else { return }
        removeEventTap()
        stopTimers()
        isBlocking = false
        startedAt = nil
        lastMessage = nil
        playSound(named: "Pop")
    }

    // MARK: - Event tap

    private func installEventTap() -> Bool {
        if eventTap != nil { return true }

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.blockedEventMask,
            callback: keyboardEventTapCallback,
            userInfo: context
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    private func removeEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return nil
        }

        guard isBlocking else { return Unmanaged.passUnretained(event) }

        // Every keyboard event is swallowed while cleaning; there is no bypass.
        return nil
    }

    // MARK: - Timers

    private func startTimers() {
        statusTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let startedAt = self.startedAt else { return }
            self.elapsedSeconds = Int(Date().timeIntervalSince(startedAt))
        }
        RunLoop.main.add(timer, forMode: .common)
        statusTimer = timer
    }

    private func stopTimers() {
        statusTimer?.invalidate()
        statusTimer = nil
    }

    // MARK: - Sound

    private func playSound(named name: String) {
        guard let sound = NSSound(named: name) else { return }
        sound.play()
    }

    var formattedElapsed: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private func keyboardEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let blocker = Unmanaged<KeyboardBlocker>.fromOpaque(userInfo).takeUnretainedValue()
    return blocker.handle(type: type, event: event)
}
