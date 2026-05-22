import Foundation
import AppKit

// Watches a configurable folder for new image files and adds them to ClipboardStore.
class ScreenshotFolderMonitor {
    static let shared = ScreenshotFolderMonitor()

    private var source: DispatchSourceFileSystemObject?
    private var folderDescriptor: Int32 = -1
    private var knownFiles: Set<String> = []
    private var watchedPath: String = ""

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "tiff", "tif", "heic", "heif", "gif", "bmp", "webp"
    ]

    private init() {}

    func start() {
        guard AppSettings.shared.screenshotFolderEnabled else { return }
        let raw = AppSettings.shared.screenshotFolderPath
        let path = (raw as NSString).expandingTildeInPath
        guard !path.isEmpty else { return }
        startWatching(path: path)
    }

    func stop() {
        source?.cancel()
        source = nil
        // fd is closed in cancelHandler
    }

    func restart() {
        stop()
        start()
    }

    private func startWatching(path: String) {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            PasteLog.log("ScreenshotFolderMonitor: cannot open \(path)")
            return
        }
        folderDescriptor = fd
        watchedPath = path
        knownFiles = currentImageFiles(at: path)

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            self.checkForNewFiles()
        }

        src.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.folderDescriptor >= 0 {
                close(self.folderDescriptor)
                self.folderDescriptor = -1
            }
        }

        src.resume()
        source = src
        PasteLog.log("ScreenshotFolderMonitor: watching \(path)")
    }

    private func currentImageFiles(at path: String) -> Set<String> {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        return Set(
            contents
                .filter { Self.imageExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
                .map { (path as NSString).appendingPathComponent($0) }
        )
    }

    private func checkForNewFiles() {
        let current = currentImageFiles(at: watchedPath)
        let newFiles = current.subtracting(knownFiles)
        knownFiles = current

        for filePath in newFiles.sorted() {
            ingestImageFile(at: filePath)
        }
    }

    private func ingestImageFile(at path: String) {
        // Small delay to ensure the file has finished writing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard let image = NSImage(contentsOfFile: path) else { return }
            ClipboardStore.shared.add(image: image)
            PasteLog.log("ScreenshotFolderMonitor: ingested \(path)")
        }
    }
}
