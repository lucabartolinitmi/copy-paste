import Carbon
import AppKit

// Notification names
extension Notification.Name {
    static let showCopyPaste = Notification.Name("showCopyPaste")
    static let quickPasteText = Notification.Name("quickPasteText")
    static let quickPasteImage = Notification.Name("quickPasteImage")
}

// Hotkey IDs
private let kHKOpenPanel: UInt32 = 1
private let kHKQuickText: UInt32 = 2
private let kHKQuickImage: UInt32 = 3
private let kHKSignature: OSType = 0x4350_5748  // CPWH

// Top-level C-style callback (captures nothing — required for EventHandlerUPP)
private func hotkeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
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
    switch hkID.id {
    case kHKOpenPanel:
        NotificationCenter.default.post(name: .showCopyPaste, object: nil)
    case kHKQuickText:
        NotificationCenter.default.post(name: .quickPasteText, object: nil)
    case kHKQuickImage:
        NotificationCenter.default.post(name: .quickPasteImage, object: nil)
    default:
        break
    }
    return noErr
}

class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventHandler: EventHandlerRef?
    private var hotkey1: EventHotKeyRef?  // Open panel
    private var hotkey2: EventHotKeyRef?  // Quick paste text
    private var hotkey3: EventHotKeyRef?  // Quick paste image

    private init() {}

    func register() {
        installHandler()
        registerAll()
    }

    func reregister() {
        unregisterHotkeys()
        registerAll()
    }

    func unregister() {
        unregisterHotkeys()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    // MARK: - Private

    private func installHandler() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventCallback,
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }

    private func registerAll() {
        let s = AppSettings.shared

        // 1. Open panel
        registerHotkey(
            keyCode: s.hotkeyKeyCode,
            modifiers: s.hotkeyModifiers,
            id: kHKOpenPanel,
            ref: &hotkey1
        )

        // 2. Quick text (optional)
        if s.hotkeyTextKeyCode >= 0 {
            registerHotkey(
                keyCode: s.hotkeyTextKeyCode,
                modifiers: s.hotkeyTextModifiers,
                id: kHKQuickText,
                ref: &hotkey2
            )
        }

        // 3. Quick image (optional)
        if s.hotkeyImageKeyCode >= 0 {
            registerHotkey(
                keyCode: s.hotkeyImageKeyCode,
                modifiers: s.hotkeyImageModifiers,
                id: kHKQuickImage,
                ref: &hotkey3
            )
        }
    }

    /// Returns true on success. Logs collision/error to console.
    @discardableResult
    private func registerHotkey(
        keyCode: Int, modifiers: Int, id: UInt32, ref: inout EventHotKeyRef?
    ) -> Bool {
        let hkID = EventHotKeyID(signature: kHKSignature, id: id)
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hkID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status != noErr {
            // eventHotKeyExistsErr = -9878 (same combo already taken,
            // either by us or by another app)
            let combo = AppSettings.displayString(for: keyCode, modifiers: modifiers)
            PasteLog.log("HotkeyManager: failed to register \(combo) for id \(id) (status \(status))")
            NSLog("[CopyPaste] Hotkey conflict: '\(combo)' already in use (status=\(status))")
            return false
        }
        return true
    }

    private func unregisterHotkeys() {
        if let hk = hotkey1 { UnregisterEventHotKey(hk); hotkey1 = nil }
        if let hk = hotkey2 { UnregisterEventHotKey(hk); hotkey2 = nil }
        if let hk = hotkey3 { UnregisterEventHotKey(hk); hotkey3 = nil }
    }
}
