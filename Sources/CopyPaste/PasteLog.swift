import Foundation

enum PasteLog {
    static let enabled = false

    static func log(_ message: String) {
        guard enabled else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let path = "/tmp/copypaste.log"
        if FileManager.default.fileExists(atPath: path) {
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }

    static func clear() {
        try? "".write(toFile: "/tmp/copypaste.log", atomically: true, encoding: .utf8)
    }
}
