import Foundation

enum ItemType: String, Codable {
    case text
    case image
}

enum ClipType: String, CaseIterable {
    case all = "All"
    case link = "Links"
    case email = "Emails"
    case image = "Images"
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    var isPinned: Bool
    let itemType: ItemType
    let text: String?
    let imagePath: String?

    init(id: UUID = UUID(), timestamp: Date = Date(), isPinned: Bool = false,
         itemType: ItemType, text: String? = nil, imagePath: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.itemType = itemType
        self.text = text
        self.imagePath = imagePath
    }

    // Backward-compatible decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        itemType = try container.decodeIfPresent(ItemType.self, forKey: .itemType) ?? .text
        text = try container.decodeIfPresent(String.self, forKey: .text)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
    }

    var clipType: ClipType {
        guard itemType == .text, let text = text else { return .image }
        let urlPrefixes = ["http://", "https://", "ftp://", "www."]
        if urlPrefixes.contains(where: { text.lowercased().hasPrefix($0) }) { return .link }
        let emailRegex = try? NSRegularExpression(
            pattern: "^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$"
        )
        if emailRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return .email
        }
        return .all
    }

    var preview: String {
        switch itemType {
        case .text:
            let t = text ?? ""
            return t.count > 60 ? String(t.prefix(60)) + "…" : t
        case .image:
            return "[Image]"
        }
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}
