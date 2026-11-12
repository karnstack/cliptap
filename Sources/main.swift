import AppKit
import SwiftUI
import Carbon.HIToolbox
import Sparkle

// MARK: - App

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private let store = ClipStore()
    private let state = PanelState()
    private var hotKey: HotKey?
    private var doubleTap: DoubleTapCommand?
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?
    private let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Cliptap")
            button.action = #selector(toggle)
            button.target = self
        }

        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 780, height: 500),
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.delegate = self
        let host = NSHostingView(rootView: HistoryView(
            store: store, state: state,
            onPick: { [weak self] in self?.pick($0) },
            onDelete: { [weak self] in self?.delete($0) },
            onCheckForUpdates: { [weak self] in
                self?.hide(restoreFocus: false)
                self?.updater.checkForUpdates(nil)
            }))
        host.safeAreaRegions = []
        panel.contentView = host

        // Control + Command + V opens the history from anywhere.
        hotKey = HotKey(keyCode: kVK_ANSI_V, modifiers: controlKey | cmdKey) { [weak self] in
            MainActor.assumeIsolated { self?.toggle() }
        }

        // Tapping Command twice also opens the history.
        doubleTap = DoubleTapCommand { [weak self] in self?.toggle() }
        if !DoubleTapCommand.hasPermission { DoubleTapCommand.askPermission() }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    @objc private func toggle() {
        panel.isVisible ? hide() : show()
    }

    private func show() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier { previousApp = front }
        state.query = ""
        state.selection = HistoryView.filter(store.items, "").first?.id
        // Center on the screen that has the mouse pointer.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2,
                                         y: visible.midY - size.height / 2 + visible.height * 0.08))
        }
        NSApp.activate()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = reduceMotion ? 1 : 0
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }
        state.focusToken += 1
    }

    private func hide(restoreFocus: Bool = true) {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        if restoreFocus { previousApp?.activate() }
    }

    private func pick(_ item: ClipItem) {
        store.copy(item)
        state.copiedID = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.state.copiedID = nil
            self?.hide()
        }
    }

    private func delete(_ item: ClipItem) {
        let list = HistoryView.filter(store.items, state.query)
        let i = list.firstIndex { $0.id == item.id } ?? 0
        store.delete(item)
        let after = HistoryView.filter(store.items, state.query)
        state.selection = after.isEmpty ? nil : after[min(i, after.count - 1)].id
    }

    /// Returns true when the key was handled.
    private func handleKey(_ event: NSEvent) -> Bool {
        let list = HistoryView.filter(store.items, state.query)
        let index = list.firstIndex { $0.id == state.selection }
        let command = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
        if command, let digit = Int(event.charactersIgnoringModifiers ?? ""), (1...9).contains(digit) {
            if digit <= list.count { pick(list[digit - 1]) }
            return true
        }
        if command, event.keyCode == UInt16(kVK_ANSI_P) {
            if let i = index { store.togglePin(list[i]) }
            return true
        }
        if command, event.keyCode == UInt16(kVK_Delete) {
            if let i = index { delete(list[i]) }
            return true
        }
        switch Int(event.keyCode) {
        case kVK_Escape:
            hide(); return true
        case kVK_DownArrow:
            guard !list.isEmpty else { return true }
            state.selection = list[min((index ?? -1) + 1, list.count - 1)].id
            return true
        case kVK_UpArrow:
            guard !list.isEmpty else { return true }
            state.selection = list[max((index ?? 1) - 1, 0)].id
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let i = index ?? (list.isEmpty ? nil : 0) { pick(list[i]) }
            return true
        default:
            // Typing changes the list, so jump back to the first result.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let fresh = HistoryView.filter(self.store.items, self.state.query)
                if !fresh.contains(where: { $0.id == self.state.selection }) {
                    self.state.selection = fresh.first?.id
                }
            }
            return false
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        // Clicking somewhere else closes the panel, and focus stays where the user clicked.
        guard panel.attachedSheet == nil, !state.confirmClear else { return }
        hide(restoreFocus: false)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
