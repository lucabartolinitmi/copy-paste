import AppKit
import SwiftUI
import IOKit
import IOKit.hid

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var hotkeyObserver: NSObjectProtocol?
    private var quickTextObserver: NSObjectProtocol?
    private var quickImageObserver: NSObjectProtocol?
    private var tapFailedObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var permissionMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PasteLog.clear()
        PasteLog.log("App launched")

        requestAccessibility()
        setupStatusItem()
        ClipboardMonitor.shared.start()
        HotkeyManager.shared.register()

        if !HotkeyManager.shared.isActive {
            showPermissionWarning()
        }

        if AppSettings.shared.screenshotFolderEnabled {
            ScreenshotFolderMonitor.shared.start()
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            HotkeyManager.shared.reregister()
            if HotkeyManager.shared.isActive {
                self?.permissionMenuItem?.isHidden = true
            }
        }

        tapFailedObserver = NotificationCenter.default.addObserver(
            forName: .tapInstallFailed, object: nil, queue: .main
        ) { [weak self] _ in
            self?.showPermissionWarning()
        }

        // Show panel hotkey
        hotkeyObserver = NotificationCenter.default.addObserver(
            forName: .showCopyPaste, object: nil, queue: .main
        ) { _ in
            PopupWindowController.shared.show()
        }

        // Quick paste last text
        quickTextObserver = NotificationCenter.default.addObserver(
            forName: .quickPasteText, object: nil, queue: .main
        ) { [weak self] _ in
            self?.quickPaste(type: .text)
        }

        // Quick paste last image
        quickImageObserver = NotificationCenter.default.addObserver(
            forName: .quickPasteImage, object: nil, queue: .main
        ) { [weak self] _ in
            self?.quickPaste(type: .image)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stop()
        ScreenshotFolderMonitor.shared.stop()
        HotkeyManager.shared.unregister()
        [hotkeyObserver, quickTextObserver, quickImageObserver, tapFailedObserver].forEach {
            if let obs = $0 { NotificationCenter.default.removeObserver(obs) }
        }
        if let obs = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    // MARK: - Quick paste (without opening panel)

    private func quickPaste(type: ItemType) {
        PasteLog.log("quickPaste called type=\(type)")
        let item: ClipboardItem? = type == .text
            ? ClipboardStore.shared.lastTextItem()
            : ClipboardStore.shared.lastImageItem()
        guard let item else {
            PasteLog.log("quickPaste: no item found for type=\(type)")
            return
        }
        PasteLog.log("quickPaste: found item id=\(item.id) preview=\(item.preview)")
        let previousApp = NSWorkspace.shared.frontmostApplication
        PasteLog.log("quickPaste: previousApp=\(previousApp?.localizedName ?? "nil")")
        PopupWindowController.shared.writeToClipboard(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            previousApp?.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.simulatePaste()
            }
        }
    }

    private func simulatePaste() {
        let trusted = AXIsProcessTrusted()
        PasteLog.log("simulatePaste: AXIsProcessTrusted=\(trusted)")
        guard trusted else {
            PasteLog.log("simulatePaste: BLOCKED — accessibility not granted")
            return
        }
        let src = CGEventSource(stateID: .hidSystemState)
        let keyV: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyV, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: keyV, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Copy & Paste")
            button.image?.size = NSSize(width: 17, height: 17)
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        let menu = NSMenu()

        let permItem = NSMenuItem(
            title: "⚠️ Shortcuts disabled — grant Input Monitoring",
            action: #selector(openInputMonitoringSettings),
            keyEquivalent: ""
        )
        permItem.isHidden = true
        menu.addItem(permItem)
        menu.addItem(NSMenuItem.separator())
        permissionMenuItem = permItem

        menu.addItem(NSMenuItem(title: "Show History", action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Clear All", action: #selector(clearAll), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Copy & Paste", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func statusItemClicked() {
        PopupWindowController.shared.show()
    }

    @objc private func showHistory() {
        PopupWindowController.shared.show()
    }

    @objc private func openSettings() {
        if settingsWindow == nil { createSettingsWindow() }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func clearAll() {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "Pinned items will be kept. This cannot be undone."
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            ClipboardStore.shared.clearAll()
        }
    }

    // MARK: - Standalone settings window

    private func createSettingsWindow() {
        let view = SettingsView()
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Copy & Paste — Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 460, height: 400))
        window.center()
        window.isReleasedWhenClosed = false
        self.settingsWindow = window
    }

    // MARK: - Permissions

    private func requestAccessibility() {
        // Accessibility is needed for simulatePaste() — prompt only if missing
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        let axTrusted = AXIsProcessTrustedWithOptions(opts)
        PasteLog.log("Accessibility trusted: \(axTrusted)")

        // Input Monitoring: only log — tap failure posts .tapInstallFailed which shows menu item
        let inputAccess = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        PasteLog.log("Input Monitoring access: \(inputAccess.rawValue) (0=granted, 1=denied, 2=unknown)")
    }

    private func showPermissionWarning() {
        permissionMenuItem?.isHidden = false
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        )
    }

    @objc private func openInputMonitoringSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            HotkeyManager.shared.reregister()
            if HotkeyManager.shared.isActive {
                self?.permissionMenuItem?.isHidden = true
            }
        }
    }
}
