import AppKit
import Carbon.HIToolbox

// MARK: - Panel

/// Borderless floating window that can take keyboard focus.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Global hotkey (Carbon; needs no Accessibility permission)

final class HotKey {
    nonisolated(unsafe) static var handler: (() -> Void)?
    private var ref: EventHotKeyRef?

    init(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        HotKey.handler = handler
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.handler?() }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x434C4950), id: 1) // "CLIP"
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &ref)
    }
}

// MARK: - Double-tap Command

/// Calls `handler` when Command is tapped twice quickly, with no other key in between.
/// Seeing keys in other apps needs Accessibility permission.
@MainActor
final class DoubleTapCommand {
    private let handler: () -> Void
    private var monitors: [Any] = []
    private var downAt: TimeInterval = 0
    private var lastTapAt: TimeInterval = 0
    private var commandDown = false
    private let tapMax: TimeInterval = 0.25   // how long one tap may hold the key
    private let gapMax: TimeInterval = 0.35   // max time between the two taps

    init(handler: @escaping () -> Void) {
        self.handler = handler
        let flags: (NSEvent) -> Void = { [weak self] e in MainActor.assumeIsolated { self?.flagsChanged(e) } }
        let key: (NSEvent) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.reset() } }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flags) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: key) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { flags($0); return $0 }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { key($0); return $0 }) { monitors.append(m) }
    }

    static var hasPermission: Bool { AXIsProcessTrusted() }

    static func askPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private func reset() {
        lastTapAt = 0
        commandDown = false
    }

    private func flagsChanged(_ event: NSEvent) {
        let now = event.timestamp
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control, .function])
        if mods == .command && !commandDown {
            commandDown = true
            downAt = now
        } else if mods.isEmpty && commandDown {
            commandDown = false
            guard now - downAt <= tapMax else { lastTapAt = 0; return }
            if lastTapAt > 0 && now - lastTapAt <= gapMax {
                lastTapAt = 0
                handler()
            } else {
                lastTapAt = now
            }
        } else {
            // Another modifier joined in: this is a shortcut, not a tap.
            reset()
        }
    }
}
