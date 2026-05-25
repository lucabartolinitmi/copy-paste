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
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow(label: label) {
                KeyRecorderButton(keyCode: $keyCode, modifiers: $modifiers, onSet: onSet)
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
    }

    private func startRecording() {
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard self.isRecording else { return event }

            if event.keyCode == 53 { // Escape — cancel
                self.stopRecording()
                return nil
            }

            let mods = event.modifierFlags
            let hasRequired = mods.contains(.command) || mods.contains(.control) || mods.contains(.option)
            guard hasRequired else { return nil }

            // Convert NSEvent modifiers to Carbon modifiers
            var carbonMods = 0
            if mods.contains(.command) { carbonMods |= Int(cmdKey) }
            if mods.contains(.shift)   { carbonMods |= Int(shiftKey) }
            if mods.contains(.option)  { carbonMods |= Int(optionKey) }
            if mods.contains(.control) { carbonMods |= Int(controlKey) }

            self.keyCode = Int(event.keyCode)
            self.modifiers = carbonMods
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
                Text((path as NSString).lastPathComponent)
                    .font(.system(size: 12))
                    .foregroundColor(isEnabled ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 140, alignment: .trailing)

                Button("Choose…") {
                    pickFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!isEnabled)
            }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}
