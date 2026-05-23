import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var eventMonitor: Any?
    private let hotKey = GlobalHotKey()
    nonisolated(unsafe) private var appState: AppState!
    private var currentContentSize: CGSize = CGSize(width: 320, height: 520)

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            appState = AppState()
            NSApp.setActivationPolicy(.accessory)

            // Status bar label
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem.button?.action = #selector(togglePanel)
            statusItem.button?.target = self
            updateIcon()

            // NSPanel — flush against the menu bar, no arrow, no popover offset
            let hostVC = NSHostingController(rootView: ContentView().environmentObject(appState))
            hostVC.view.frame = NSRect(x: 0, y: 0, width: 320, height: 520)

            panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 520),
                styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: true
            )
            panel.contentViewController = hostVC
            panel.level = .popUpMenu
            panel.isFloatingPanel = true
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.isMovable = false

            NotificationCenter.default.addObserver(
                self, selector: #selector(stateChanged),
                name: .duoSoundStateChanged, object: nil
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(handleSizeChange),
                name: .popoverSizeChanged, object: nil
            )

            NSApp.windows.filter { $0 !== panel }.forEach { $0.orderOut(nil) }

            // ⌥⌘D global hotkey — toggle multi-output without opening the popover
            hotKey.action = { [weak self] in
                guard let self else { return }
                MainActor.assumeIsolated {
                    if self.appState.aggregate != nil {
                        Task { await self.appState.reset() }
                    } else if self.appState.canFuse {
                        Task { await self.appState.fuse() }
                    } else {
                        self.showPanel()   // can't fuse yet, show UI so user can select
                    }
                }
            }
            hotKey.register()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey.unregister()
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
        MainActor.assumeIsolated { appState.handleTermination() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Panel show/hide

    @objc private func togglePanel(_ sender: AnyObject?) {
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        repositionPanel()
        panel.orderFrontRegardless()

        // Delay monitor registration so the opening click isn't caught and
        // doesn't immediately close the panel.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.panel.isVisible else { return }
            self.eventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                guard let self else { return }
                if !self.panel.frame.contains(NSEvent.mouseLocation) {
                    self.closePanel()
                }
            }
        }
    }

    private func closePanel() {
        panel.orderOut(nil)
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }

    private func repositionPanel() {
        guard let btn = statusItem.button, let btnWindow = btn.window else { return }

        let btnRectInWindow = btn.convert(btn.bounds, to: nil)
        let btnScreenRect = btnWindow.convertToScreen(btnRectInWindow)

        let panelW: CGFloat = currentContentSize.width
        let panelH: CGFloat = currentContentSize.height

        var x = btnScreenRect.maxX - panelW
        // Match the Wi-Fi menu exactly: it drops ~4 points below the status item bounds
        let y = btnScreenRect.minY - panelH - 4

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            x = max(sf.minX + 6, min(x, sf.maxX - panelW - 6))
        }

        panel.setFrame(NSRect(x: x, y: y, width: panelW, height: panelH), display: true)
    }

    @objc private func handleSizeChange(_ notification: Notification) {
        guard let size = notification.object as? CGSize else { return }
        MainActor.assumeIsolated {
            currentContentSize = size
            if panel.isVisible {
                repositionPanel()
            }
        }
    }

    // MARK: - Icon

    @objc private func stateChanged() {
        MainActor.assumeIsolated { updateIcon() }
    }

    @MainActor private func updateIcon() {
        let active = appState.aggregate != nil
        let label = active ? "DUO ●" : "DUO"
        var attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        ]
        if active {
            attrs[.foregroundColor] = NSColor.systemGreen
        }
        statusItem.button?.attributedTitle = NSAttributedString(string: label, attributes: attrs)
    }
}

extension Notification.Name {
    static let duoSoundStateChanged = Notification.Name("DuoSoundStateChanged")
    static let popoverSizeChanged = Notification.Name("PopoverSizeChanged")
}
