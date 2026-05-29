import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case shortcuts = "Shortcuts"
        case screenshots = "Screenshots"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                            .background(
                                VStack {
                                    Spacer()
                                    if selectedTab == tab {
                                        Rectangle()
                                            .fill(Color.accentColor)
                                            .frame(height: 2)
                                    } else {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(height: 2)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            Divider()

            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch selectedTab {
                    case .general:  GeneralTab(settings: settings)
                    case .shortcuts: ShortcutsTab(settings: settings)
                    case .screenshots: ScreenshotsTab(settings: settings)
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - General tab

private struct GeneralTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SettingsSection("App") {
                SettingsToggleRow(label: "Launch at login", value: $settings.launchAtLogin)
            }
            SettingsSection("History") {
                SettingsToggleRow(label: "Capture images", value: $settings.captureImages)
                SettingsToggleRow(label: "Persist across sessions", value: $settings.persistHistory)
                SettingsStepperRow(
                    label: "Max items",
                    value: $settings.maxItems,
                    range: 10...500,
                    step: 10
                )
            }
        }
    }
}

// MARK: - Shortcuts tab

private struct ShortcutsTab: View {
    @ObservedObject var settings: AppSettings

    // Detect duplicate keyCode+modifier combos across the 3 hotkey slots.
    // Returns label of the conflicting slot, or nil if unique.
    private func conflict(keyCode: Int, modifiers: Int, excluding: String) -> String? {
        guard keyCode >= 0 else { return nil }
        let combos: [(String, Int, Int)] = [
            ("Open panel",        settings.hotkeyKeyCode,      settings.hotkeyModifiers),
            ("Quick paste text",  settings.hotkeyTextKeyCode,  settings.hotkeyTextModifiers),
            ("Quick paste image", settings.hotkeyImageKeyCode, settings.hotkeyImageModifiers),
        ]
        for (name, kc, mods) in combos where name != excluding && kc == keyCode && mods == modifiers {
            return name
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SettingsSection("Keyboard Shortcuts") {
                ShortcutRow(
                    label: "Open panel",
                    description: "Shows the clipboard history panel",
                    keyCode: $settings.hotkeyKeyCode,
                    modifiers: $settings.hotkeyModifiers,
                    onSet: { HotkeyManager.shared.reregister() }
                )
                ShortcutRow(
                    label: "Quick paste text",
                    description: "Instantly pastes the last text item",
                    keyCode: $settings.hotkeyTextKeyCode,
                    modifiers: $settings.hotkeyTextModifiers,
                    onSet: { HotkeyManager.shared.reregister() }
                )
                ShortcutRow(
                    label: "Quick paste image",
                    description: "Instantly pastes the last image item",
                    keyCode: $settings.hotkeyImageKeyCode,
                    modifiers: $settings.hotkeyImageModifiers,
                    onSet: { HotkeyManager.shared.reregister() }
                )
            }

            // Inline collision warning if two slots share the same combo
            if let openConflict = conflict(
                keyCode: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers,
                excluding: "Open panel"
            ) {
                ConflictBanner(combo: AppSettings.displayString(
                    for: settings.hotkeyKeyCode, modifiers: settings.hotkeyModifiers
                ), other: openConflict)
            } else if let textConflict = conflict(
                keyCode: settings.hotkeyTextKeyCode, modifiers: settings.hotkeyTextModifiers,
                excluding: "Quick paste text"
            ) {
                ConflictBanner(combo: AppSettings.displayString(
                    for: settings.hotkeyTextKeyCode, modifiers: settings.hotkeyTextModifiers
                ), other: textConflict)
            } else if let imgConflict = conflict(
                keyCode: settings.hotkeyImageKeyCode, modifiers: settings.hotkeyImageModifiers,
                excluding: "Quick paste image"
            ) {
                ConflictBanner(combo: AppSettings.displayString(
                    for: settings.hotkeyImageKeyCode, modifiers: settings.hotkeyImageModifiers
                ), other: imgConflict)
            }
        }
    }
}

private struct ConflictBanner: View {
    let combo: String
    let other: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 11))
            Text("\(combo) is already assigned to \"\(other)\". One of them will not work.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
        .padding(.horizontal, 2)
    }
}

// MARK: - Screenshots tab

private struct ScreenshotsTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SettingsSection("Screenshot Folder") {
                SettingsToggleRow(
                    label: "Watch folder for new images",
                    value: $settings.screenshotFolderEnabled
                )
                FolderPickerRow(
                    label: "Folder",
                    path: $settings.screenshotFolderPath,
                    isEnabled: settings.screenshotFolderEnabled
                )
            }
            if settings.screenshotFolderEnabled {
                Text("New images dropped into this folder are automatically added to your clipboard history.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .padding(.horizontal, 2)
            }
        }
    }
}

// MARK: - Reusable components

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.top, 16)
                .padding(.bottom, 6)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
            )
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let trailing: Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

private struct SettingsToggleRow: View {
    let label: String
    @Binding var value: Bool

    var body: some View {
        SettingsRow(label: label) {
            Toggle("", isOn: $value).labelsHidden()
        }
    }
}

private struct SettingsStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        SettingsRow(label: label) {
            Stepper("\(value)", value: $value, in: range, step: step)
                .font(.system(size: 13))
        }
    }
}

// MARK: - Shortcut recorder row

private struct ShortcutRow: View {
    let label: String
    let description: String
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    let onSet: () -> Void

    // No longer flagging combos — CGEventTap intercepts before the input
    // system dead-key processing, so Option+letter combos work fine now.
    // Kept as `false` for now in case we need to re-enable specific warnings.
    private var isUnreliable: Bool { false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow(label: label) {
                KeyRecorderButton(keyCode: $keyCode, modifiers: $modifiers, onSet: onSet)
            }
            if isUnreliable {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 10))
                    Text("macOS intercetta questa combo per caratteri speciali. Aggiungi ⌘ (Cmd/Start) o ⌃ (Ctrl).")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
    }
}

// MARK: - Key recorder button

struct KeyRecorderButton: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    let onSet: () -> Void

    @State private var isRecording = false
    @State private var localMonitor: Any?

    private var displayText: String {
        isRecording ? "Press shortcut…" : AppSettings.displayString(for: keyCode, modifiers: modifiers)
    }

    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            Text(displayText)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isRecording ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isRecording ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: 1)
                        )
                )
                .foregroundColor(isRecording ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        // Cleanup: if user closes the settings window while still recording,
        // the local event monitor would leak and keep intercepting keystrokes.
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isRecording else { return event }

            if event.keyCode == 53 { // Escape — cancel
                self.stopRecording()
                return nil
            }

            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            NSLog("[CopyPaste KeyRecorder] keyCode=%d rawFlags=0x%X masked=0x%X chars=%@",
                  event.keyCode,
                  event.modifierFlags.rawValue,
                  mods.rawValue,
                  event.charactersIgnoringModifiers ?? "")
            PasteLog.log("KeyRecorder: keyCode=\(event.keyCode) rawFlags=0x\(String(event.modifierFlags.rawValue, radix: 16))")

            // Accept any combo with at least one modifier (Cmd / Ctrl / Option / Shift / Fn)
            let hasModifier = mods.contains(.command) ||
                              mods.contains(.control) ||
                              mods.contains(.option) ||
                              mods.contains(.shift) ||
                              mods.contains(.function)
            guard hasModifier else { return nil }

            // Convert NSEvent modifiers to our bitmask (Carbon-style + fnMask)
            var bits = 0
            if mods.contains(.command)  { bits |= Int(cmdKey) }
            if mods.contains(.shift)    { bits |= Int(shiftKey) }
            if mods.contains(.option)   { bits |= Int(optionKey) }
            if mods.contains(.control)  { bits |= Int(controlKey) }
            if mods.contains(.function) { bits |= fnMask }

            self.keyCode = Int(event.keyCode)
            self.modifiers = bits
            self.stopRecording()
            self.onSet()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }
}

// MARK: - Folder picker row

private struct FolderPickerRow: View {
    let label: String
    @Binding var path: String
    let isEnabled: Bool

    var body: some View {
        SettingsRow(label: label) {
            HStack(spacing: 6) {
                Text(displayPath)
                    .font(.system(size: 12))
                    .foregroundColor(isEnabled ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: 160, alignment: .trailing)
                    .help(path)

                Button("Choose…") {
                    pickFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!isEnabled)
            }
        }
    }

    private var displayPath: String {
        let expanded = (path as NSString).expandingTildeInPath
        let home = NSHomeDirectory()
        if expanded.hasPrefix(home) {
            return "~" + expanded.dropFirst(home.count)
        }
        return expanded
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        let expandedPath = (path as NSString).expandingTildeInPath
        panel.directoryURL = URL(fileURLWithPath: expandedPath)
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}
