import AppKit
import SwiftUI

class PopupWindowController: NSObject {
    static let shared = PopupWindowController()

    private var panel: NSPanel?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var previousApp: NSRunningApplication?

    private override init() {}

    func show() {
        if panel == nil { createPanel() }

        previousApp = NSWorkspace.shared.frontmostApplication
        NavigationState.shared.reset()

        // Position near cursor
        let mouse = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let width: CGFloat = 520
        let height: CGFloat = 420
        var x = mouse.x - width / 2
        var y = mouse.y - height / 2
        x = max(screenFrame.minX + 8, min(x, screenFrame.maxX - width - 8))
        y = max(screenFrame.minY + 8, min(y, screenFrame.maxY - height - 8))

        panel?.setFrameOrigin(NSPoint(x: x, y: y))
        panel?.setContentSize(NSSize(width: width, height: height))

        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        animateIn()
        installEventMonitors()
    }

    func hide() {
        animateOut {
            self.panel?.orderOut(nil)
        }
        removeEventMonitors()
    }

    // MARK: - Paste item

    func pasteItem(_ item: ClipboardItem) {
        writeToClipboard(item)
        hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            self.previousApp?.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.simulatePaste()
            }
        }
    }

    // MARK: - Private

    private func createPanel() {
        let p = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled, .closable],
            backing: .buffered,
            defer: true
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = false

        let rootView = ClipboardListView()
            .environmentObject(ClipboardStore.shared)
            .environmentObject(NavigationState.shared)
            .environmentObject(AppSettings.shared)

        let host = NSHostingView(rootView: rootView)
        host.layer?.cornerRadius = 12
        host.layer?.masksToBounds = true
        p.contentView = host

        self.panel = p
    }

    private func animateIn() {
        panel?.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel?.animator().alphaValue = 1
        }
    }

    private func animateOut(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel?.animator().alphaValue = 0
        } completionHandler: {
            completion()
        }
    }

    private func installEventMonitors() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.hide()
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyDown(event)
        }
    }

    private func removeEventMonitors() {
        if let m = globalEventMonitor { NSEvent.removeMonitor(m); globalEventMonitor = nil }
        if let m = localEventMonitor  { NSEvent.removeMonitor(m); localEventMonitor  = nil }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let nav = NavigationState.shared
        let store = ClipboardStore.shared
        let filtered = filteredItems(store: store, nav: nav)

        switch event.keyCode {
        case 53: // Escape
            hide()
            return nil
        case 125: // Down arrow
            if nav.selectedIndex < filtered.count - 1 { nav.selectedIndex += 1 }
            return nil
        case 126: // Up arrow
            if nav.selectedIndex > 0 { nav.selectedIndex -= 1 }
            return nil
        case 36: // Return
            if nav.selectedIndex < filtered.count {
                pasteItem(filtered[nav.selectedIndex])
            }
            return nil
        case 51: // Delete
            if event.modifierFlags.contains(.command) {
                if event.modifierFlags.contains(.shift) {
                    store.clearAll()
                } else if nav.selectedIndex < filtered.count {
                    store.delete(filtered[nav.selectedIndex])
                    nav.selectedIndex = max(0, nav.selectedIndex - 1)
                }
                return nil
            }
        default:
            break
        }
        return event
    }

    private func filteredItems(store: ClipboardStore, nav: NavigationState) -> [ClipboardItem] {
        store.items.filter { item in
            let matchesFilter: Bool = {
                switch nav.activeFilter {
                case .all: return true
                case .image: return item.itemType == .image
                case .link: return item.clipType == .link
                case .email: return item.clipType == .email
                }
            }()
            let matchesSearch = nav.searchText.isEmpty ||
                (item.text?.localizedCaseInsensitiveContains(nav.searchText) ?? false)
            return matchesFilter && matchesSearch
        }
    }

    // MARK: - Clipboard & paste helpers

    func writeToClipboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.itemType {
        case .text:
            if let text = item.text { pb.setString(text, forType: .string) }
        case .image:
            if let path = item.imagePath, let img = NSImage(contentsOfFile: path) {
                pb.writeObjects([img])
            }
        }
        ClipboardMonitor.shared.syncAfterWrite()
    }

    private func simulatePaste() {
        guard AXIsProcessTrusted() else { return }
        let src = CGEventSource(stateID: .hidSystemState)
        let keyV: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyV, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: keyV, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}
