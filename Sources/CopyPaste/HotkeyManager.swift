import AppKit
import Carbon  // Only used for cmdKey/shiftKey/optionKey/controlKey constants

// Notification names
extension Notification.Name {
    static let showCopyPaste   = Notification.Name("showCopyPaste")
    static let quickPasteText  = Notification.Name("quickPasteText")
    static let quickPasteImage = Notification.Name("quickPasteImage")
    static let tapInstallFailed = Notification.Name("tapInstallFailed")
}

// Hotkey IDs
private let kHKOpenPanel: UInt32 = 1
private let kHKQuickText: UInt32 = 2
private let kHKQuickImage: UInt32 = 3

// Custom modifier mask bit for Fn (unused by Carbon constants)
let fnMask: Int = 0x10000

class HotkeyManager {
    static let shared = HotkeyManager()

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isActive: Bool { tap != nil }

    // Stored hotkey list: (keyCode, modifierBitmask, id)
    private var hotkeys: [(CGKeyCode, Int, UInt32)] = []

    private init() {}

    // MARK: - Public API

    func register() {
        rebuildHotkeyList()
        installTap()
    }

    func reregister() {
        rebuildHotkeyList()
        if let t = tap {
            CGEvent.tapEnable(tap: t, enable: true)
            PasteLog.log("HotkeyManager: tap re-enabled")
        } else {
            installTap()
        }
    }

    func unregister() {
        uninstallTap()
        hotkeys = []
    }

    // MARK: - Internals

    private func rebuildHotkeyList() {
        let s = AppSettings.shared
        var list: [(CGKeyCode, Int, UInt32)] = []
        if s.hotkeyKeyCode >= 0 {
            list.append((CGKeyCode(s.hotkeyKeyCode), s.hotkeyModifiers, kHKOpenPanel))
        }
        if s.hotkeyTextKeyCode >= 0 {
            list.append((CGKeyCode(s.hotkeyTextKeyCode), s.hotkeyTextModifiers, kHKQuickText))
        }
        if s.hotkeyImageKeyCode >= 0 {
            list.append((CGKeyCode(s.hotkeyImageKeyCode), s.hotkeyImageModifiers, kHKQuickImage))
        }
        hotkeys = list
        PasteLog.log("HotkeyManager: rebuilt list — \(list.count) hotkeys")
        for (kc, mods, id) in list {
            PasteLog.log("  id=\(id) keyCode=\(kc) mods=0x\(String(mods, radix: 16))")
        }
    }

    private func installTap() {
        guard tap == nil else { return }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, _ -> Unmanaged<CGEvent>? in
            return HotkeyManager.shared.handleEvent(type: type, event: event)
        }

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: nil
        ) else {
            PasteLog.log("HotkeyManager: CGEventTap.tapCreate FAILED — Input Monitoring permission needed?")
            NSLog("[CopyPaste] CGEventTap creation failed. Grant Input Monitoring permission in System Settings → Privacy & Security.")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .tapInstallFailed, object: nil)
            }
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)

        self.tap = newTap
        self.runLoopSource = source
        PasteLog.log("HotkeyManager: CGEventTap installed ✓")
    }

    private func uninstallTap() {
        if let t = tap {
            CGEvent.tapEnable(tap: t, enable: false)
        }
        if let s = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), s, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Auto-recover if macOS disables the tap
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tap {
                CGEvent.tapEnable(tap: t, enable: true)
                PasteLog.log("HotkeyManager: tap auto-recovered from disabled state")
            }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Diagnostic for unmatched events with non-trivial modifiers
        let relevant: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate,
                                      .maskControl, .maskSecondaryFn]
        let actualMods = flags.intersection(relevant)
        if !actualMods.isEmpty {
            PasteLog.log("Tap keyDown keyCode=\(keyCode) flags=0x\(String(flags.rawValue, radix: 16)) modBits=0x\(String(actualMods.rawValue, radix: 16))")
        }

        for (hkCode, hkMods, hkID) in hotkeys {
            if keyCode == hkCode && modifiersMatch(actual: flags, expected: hkMods) {
                PasteLog.log("HotkeyManager: MATCHED id=\(hkID) keyCode=\(keyCode)")
                DispatchQueue.main.async {
                    switch hkID {
                    case kHKOpenPanel:
                        NotificationCenter.default.post(name: .showCopyPaste, object: nil)
                    case kHKQuickText:
                        NotificationCenter.default.post(name: .quickPasteText, object: nil)
                    case kHKQuickImage:
                        NotificationCenter.default.post(name: .quickPasteImage, object: nil)
                    default:
                        break
                    }
                }
                return nil  // consume — event won't reach other apps
            }
        }

        return Unmanaged.passUnretained(event)
    }

    /// Compare CGEvent flags against our Carbon-style + fnMask bitmask
    private func modifiersMatch(actual: CGEventFlags, expected ourMask: Int) -> Bool {
        var expected: CGEventFlags = []
        if (ourMask & Int(cmdKey))     != 0 { expected.insert(.maskCommand) }
        if (ourMask & Int(shiftKey))   != 0 { expected.insert(.maskShift) }
        if (ourMask & Int(optionKey))  != 0 { expected.insert(.maskAlternate) }
        if (ourMask & Int(controlKey)) != 0 { expected.insert(.maskControl) }
        if (ourMask & fnMask)          != 0 { expected.insert(.maskSecondaryFn) }

        let relevant: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate,
                                      .maskControl, .maskSecondaryFn]
        let actualRelevant = actual.intersection(relevant)
        return actualRelevant == expected
    }
}
