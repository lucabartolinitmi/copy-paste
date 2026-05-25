import Foundation
import ServiceManagement
import Carbon

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - General

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "cp_launchAtLogin")
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }

    // MARK: - History

    @Published var captureImages: Bool {
        didSet { UserDefaults.standard.set(captureImages, forKey: "cp_captureImages") }
    }

    @Published var persistHistory: Bool {
        didSet {
            UserDefaults.standard.set(persistHistory, forKey: "cp_persistHistory")
            // When disabling persistence, clear the stored history blob so it
            // doesn't linger in UserDefaults until the next save() overwrite.
            if !persistHistory {
                UserDefaults.standard.removeObject(forKey: "cp_clipboardHistory")
            }
        }
    }

    @Published var maxItems: Int {
        didSet { UserDefaults.standard.set(maxItems, forKey: "cp_maxItems") }
    }

    // MARK: - Hotkey 1: Open panel

    @Published var hotkeyKeyCode: Int {
        didSet { UserDefaults.standard.set(hotkeyKeyCode, forKey: "cp_hotkeyKeyCode") }
    }
    @Published var hotkeyModifiers: Int {
        didSet { UserDefaults.standard.set(hotkeyModifiers, forKey: "cp_hotkeyModifiers") }
    }

    // MARK: - Hotkey 2: Quick paste last text (-1 = not set)

    @Published var hotkeyTextKeyCode: Int {
        didSet { UserDefaults.standard.set(hotkeyTextKeyCode, forKey: "cp_hotkeyTextKeyCode") }
    }
    @Published var hotkeyTextModifiers: Int {
        didSet { UserDefaults.standard.set(hotkeyTextModifiers, forKey: "cp_hotkeyTextModifiers") }
    }

    // MARK: - Hotkey 3: Quick paste last image (-1 = not set)

    @Published var hotkeyImageKeyCode: Int {
        didSet { UserDefaults.standard.set(hotkeyImageKeyCode, forKey: "cp_hotkeyImageKeyCode") }
    }
    @Published var hotkeyImageModifiers: Int {
        didSet { UserDefaults.standard.set(hotkeyImageModifiers, forKey: "cp_hotkeyImageModifiers") }
    }

    // MARK: - Screenshot folder

    @Published var screenshotFolderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(screenshotFolderEnabled, forKey: "cp_screenshotFolderEnabled")
            if screenshotFolderEnabled {
                ScreenshotFolderMonitor.shared.start()
            } else {
                ScreenshotFolderMonitor.shared.stop()
            }
        }
    }

    @Published var screenshotFolderPath: String {
        didSet {
            UserDefaults.standard.set(screenshotFolderPath, forKey: "cp_screenshotFolderPath")
            if screenshotFolderEnabled {
                ScreenshotFolderMonitor.shared.restart()
            }
        }
    }

    // MARK: - Init

    private init() {
        launchAtLogin = UserDefaults.standard.bool(forKey: "cp_launchAtLogin")
        captureImages = UserDefaults.standard.object(forKey: "cp_captureImages") as? Bool ?? true
        persistHistory = UserDefaults.standard.object(forKey: "cp_persistHistory") as? Bool ?? true
        maxItems = UserDefaults.standard.object(forKey: "cp_maxItems") as? Int ?? 50

        // Open panel: ⌘⇧V
        hotkeyKeyCode = UserDefaults.standard.object(forKey: "cp_hotkeyKeyCode") as? Int ?? 9
        hotkeyModifiers = UserDefaults.standard.object(forKey: "cp_hotkeyModifiers") as? Int
            ?? (Int(cmdKey) | Int(shiftKey))

        // Quick text: not set by default
        hotkeyTextKeyCode = UserDefaults.standard.object(forKey: "cp_hotkeyTextKeyCode") as? Int ?? -1
        hotkeyTextModifiers = UserDefaults.standard.object(forKey: "cp_hotkeyTextModifiers") as? Int ?? 0

        // Quick image: not set by default
        hotkeyImageKeyCode = UserDefaults.standard.object(forKey: "cp_hotkeyImageKeyCode") as? Int ?? -1
        hotkeyImageModifiers = UserDefaults.standard.object(forKey: "cp_hotkeyImageModifiers") as? Int ?? 0

        screenshotFolderEnabled = UserDefaults.standard.bool(forKey: "cp_screenshotFolderEnabled")
        let defaultPath = (NSHomeDirectory() as NSString).appendingPathComponent("Desktop")
        screenshotFolderPath = UserDefaults.standard.string(forKey: "cp_screenshotFolderPath") ?? defaultPath
    }

    // MARK: - Display helpers

    static func displayString(for keyCode: Int, modifiers: Int) -> String {
        guard keyCode >= 0 else { return "Not Set" }
        var s = ""
        if modifiers & fnMask          != 0 { s += "fn " }
        if modifiers & Int(controlKey) != 0 { s += "⌃" }
        if modifiers & Int(optionKey)  != 0 { s += "⌥" }
        if modifiers & Int(shiftKey)   != 0 { s += "⇧" }
        if modifiers & Int(cmdKey)     != 0 { s += "⌘" }
        s += keyName(for: keyCode)
        return s
    }

    static func keyName(for keyCode: Int) -> String {
        switch keyCode {
        case 0: return "A"; case 1: return "S"; case 2: return "D"; case 3: return "F"
        case 4: return "H"; case 5: return "G"; case 6: return "Z"; case 7: return "X"
        case 8: return "C"; case 9: return "V"; case 11: return "B"; case 12: return "Q"
        case 13: return "W"; case 14: return "E"; case 15: return "R"; case 16: return "Y"
        case 17: return "T"; case 18: return "1"; case 19: return "2"; case 20: return "3"
        case 21: return "4"; case 22: return "6"; case 23: return "5"; case 24: return "="
        case 25: return "9"; case 26: return "7"; case 27: return "-"; case 28: return "8"
        case 29: return "0"; case 30: return "]"; case 31: return "O"; case 32: return "U"
        case 33: return "["; case 34: return "I"; case 35: return "P"; case 36: return "↩"
        case 37: return "L"; case 38: return "J"; case 39: return "'"; case 40: return "K"
        case 41: return ";"; case 42: return "\\"; case 43: return ","; case 44: return "/"
        case 45: return "N"; case 46: return "M"; case 47: return "."; case 48: return "⇥"
        case 49: return "Space"; case 50: return "`"; case 51: return "⌫"; case 53: return "⎋"
        case 96: return "F5"; case 97: return "F6"; case 98: return "F7"; case 99: return "F3"
        case 100: return "F8"; case 101: return "F9"; case 103: return "F11"
        case 109: return "F10"; case 111: return "F12"; case 118: return "F4"
        case 120: return "F2"; case 122: return "F1"
        default: return "(\(keyCode))"
        }
    }
}
