import AppKit
import Carbon
import Carbon.HIToolbox

// Notification names
extension Notification.Name {
    static let showCopyPaste   = Notification.Name("showCopyPaste")
    static let quickPasteText  = Notification.Name("quickPasteText")
    static let quickPasteImage = Notification.Name("quickPasteImage")
    static let tapInstallFailed = Notification.Name("tapInstallFailed")  // kept for API compat
}

// Hotkey IDs
private let kHKOpenPanel: UInt32 = 1
private let kHKQuickText: UInt32 = 2
private let kHKQuickImage: UInt32 = 3

// Custom modifier mask bit for Fn (not supported by RegisterEventHotKey, ignored)
let fnMask: Int = 0x10000

class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?
    private var _registered = false

    var isActive: Bool { _registered }

    // Stored hotkey list: (keyCode, modifierBitmask, id)
    private var hotkeys: [(CGKeyCode, Int, UInt32)] = []

    private init() {}

    // MARK: - Public API

    func register() {
        rebuildHotkeyList()
        installHotKeys()
    }

    func reregister() {
        rebuildHotkeyList()
        uninstallHotKeys()
        installHotKeys()
    }

    func unregister() {
        uninstallHotKeys()
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

    private func installHotKeys() {
        guard !hotkeys.isEmpty else { return }

        // Install Carbon event handler once per instance lifetime
        if eventHandlerRef == nil {
            var eventSpec = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let selfPtr = Unmanaged.passUnretained(self).toOpaque()
            let status = InstallEventHandler(
                GetEventDispatcherTarget(),
                { (_, event, userData) -> OSStatus in
                    guard let event = event, let userData = userData else { return noErr }
                    var hkID = EventHotKeyID()
                    GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hkID
                    )
                    Unmanaged<HotkeyManager>.fromOpaque(userData)
                        .takeUnretainedValue()
                        .handleHotKey(id: hkID.id)
                    return noErr
                },
                1,
                &eventSpec,
                selfPtr,
                &eventHandlerRef
            )
            PasteLog.log("HotkeyManager: event handler installed status=\(status)")
        }

        // Register each hotkey with Carbon — no TCC / Input Monitoring required
        var anyRegistered = false
        for (keyCode, mods, id) in hotkeys {
            var ref: EventHotKeyRef?
            var hkID = EventHotKeyID()
            hkID.signature = fourCC("CoPa")
            hkID.id = id

            // Strip fnMask — RegisterEventHotKey uses Carbon modifier flags (cmdKey/shiftKey/…)
            let carbonMods = UInt32(mods & ~fnMask)
            let status = RegisterEventHotKey(
                UInt32(keyCode),
                carbonMods,
                hkID,
                GetEventDispatcherTarget(),
                0,
                &ref
            )
            hotKeyRefs.append(ref)
            let ok = status == noErr && ref != nil
            PasteLog.log("HotkeyManager: RegisterEventHotKey id=\(id) keyCode=\(keyCode) mods=0x\(String(carbonMods, radix:16)) → \(ok ? "✓" : "FAILED status=\(status)")")
            if ok { anyRegistered = true }
        }
        _registered = anyRegistered
        PasteLog.log("HotkeyManager: isActive=\(_registered)")
    }

    private func uninstallHotKeys() {
        for ref in hotKeyRefs {
            if let ref = ref { UnregisterEventHotKey(ref) }
        }
        hotKeyRefs = []
        if let h = eventHandlerRef {
            RemoveEventHandler(h)
            eventHandlerRef = nil
        }
        _registered = false
    }

    // Called from C event handler — must be internal/public
    func handleHotKey(id: UInt32) {
        PasteLog.log("HotkeyManager: MATCHED id=\(id)")
        DispatchQueue.main.async {
            switch id {
            case kHKOpenPanel:  NotificationCenter.default.post(name: .showCopyPaste,   object: nil)
            case kHKQuickText:  NotificationCenter.default.post(name: .quickPasteText,  object: nil)
            case kHKQuickImage: NotificationCenter.default.post(name: .quickPasteImage, object: nil)
            default: break
            }
        }
    }

    private func fourCC(_ s: String) -> OSType {
        var result: OSType = 0
        for c in s.prefix(4).unicodeScalars { result = (result << 8) + OSType(c.value) }
        return result
    }
}
