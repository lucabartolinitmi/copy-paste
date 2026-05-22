import AppKit

class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let store: ClipboardStore

    private init(store: ClipboardStore = .shared) {
        self.store = store
    }

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // Call after programmatic paste to avoid capturing our own write
    func syncAfterWrite() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func poll() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        // Images take priority (screenshots have both image and text)
        if AppSettings.shared.captureImages {
            if let tiff = NSPasteboard.general.data(forType: .tiff) ??
                          NSPasteboard.general.data(forType: NSPasteboard.PasteboardType("public.png")) {
                if let image = NSImage(data: tiff) {
                    store.add(image: image)
                    return
                }
            }
        }

        if let text = NSPasteboard.general.string(forType: .string) {
            store.add(text: text)
        }
    }
}
