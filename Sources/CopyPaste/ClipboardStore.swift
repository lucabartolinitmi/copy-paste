import Foundation
import AppKit

class ClipboardStore: ObservableObject {
    static let shared = ClipboardStore()

    @Published var items: [ClipboardItem] = []

    private let storageKey = "cp_clipboardHistory"
    private var appSupportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CopyPaste", isDirectory: true)
    }

    private init() {
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        load()
    }

    func add(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // Deduplicate: remove existing item with same text
        items.removeAll { $0.itemType == .text && $0.text == text && !$0.isPinned }
        let item = ClipboardItem(itemType: .text, text: text)
        insertAtTop(item)
    }

    func add(image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { return }
        let fileName = UUID().uuidString + ".png"
        let fileURL = appSupportDir.appendingPathComponent(fileName)
        guard (try? png.write(to: fileURL)) != nil else { return }
        let item = ClipboardItem(itemType: .image, imagePath: fileURL.path)
        insertAtTop(item)
    }

    private func insertAtTop(_ item: ClipboardItem) {
        let pinnedItems = items.filter { $0.isPinned }
        let unpinnedItems = items.filter { !$0.isPinned }
        items = pinnedItems + [item] + unpinnedItems
        trimUnpinned()
        save()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(of: item) else { return }
        items[idx].isPinned.toggle()
        let pinned = items.filter { $0.isPinned }
        let unpinned = items.filter { !$0.isPinned }
        items = pinned + unpinned
        save()
    }

    func delete(_ item: ClipboardItem) {
        if item.itemType == .image, let path = item.imagePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearAll() {
        let toDelete = items.filter { !$0.isPinned }
        for item in toDelete where item.itemType == .image {
            if let path = item.imagePath { try? FileManager.default.removeItem(atPath: path) }
        }
        items.removeAll { !$0.isPinned }
        save()
    }

    func lastTextItem() -> ClipboardItem? {
        items.first { $0.itemType == .text && !$0.isPinned }
    }

    func lastImageItem() -> ClipboardItem? {
        items.first { $0.itemType == .image && !$0.isPinned }
    }

    private func trimUnpinned() {
        let maxItems = AppSettings.shared.maxItems
        var unpinned = items.filter { !$0.isPinned }
        if unpinned.count > maxItems {
            let toRemove = unpinned.suffix(unpinned.count - maxItems)
            for item in toRemove where item.itemType == .image {
                if let path = item.imagePath { try? FileManager.default.removeItem(atPath: path) }
            }
            unpinned = Array(unpinned.prefix(maxItems))
            items = items.filter { $0.isPinned } + unpinned
        }
    }

    private func save() {
        guard AppSettings.shared.persistHistory else { return }
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard AppSettings.shared.persistHistory,
              let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([ClipboardItem].self, from: data)
        else { return }
        items = saved
    }
}
