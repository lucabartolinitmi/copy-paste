import SwiftUI
import AppKit

struct ClipboardListView: View {
    @EnvironmentObject var store: ClipboardStore
    @EnvironmentObject var nav: NavigationState
    @EnvironmentObject var settings: AppSettings

    @State private var showSettings = false

    var filteredItems: [ClipboardItem] {
        store.items.filter { item in
            let matchesFilter: Bool = {
                switch nav.activeFilter {
                case .all:   return true
                case .image: return item.itemType == .image
                case .link:  return item.clipType == .link
                case .email: return item.clipType == .email
                }
            }()
            let matchesSearch = nav.searchText.isEmpty ||
                (item.text?.localizedCaseInsensitiveContains(nav.searchText) ?? false)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    TextField("Search…", text: $nav.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .onChange(of: nav.searchText) { _ in nav.selectedIndex = 0 }
                    Spacer()
                    Button { showSettings.toggle() } label: {
                        Image(systemName: showSettings ? "xmark.circle.fill" : "gear")
                            .foregroundColor(.secondary)
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider()

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ClipType.allCases, id: \.self) { type in
                            FilterChip(label: type.rawValue, isActive: nav.activeFilter == type) {
                                nav.activeFilter = type
                                nav.selectedIndex = 0
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }

                Divider()

                if showSettings {
                    SettingsView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    if filteredItems.isEmpty {
                        Spacer()
                        Text("No items")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Spacer()
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { idx, item in
                                        ClipboardRowView(
                                            item: item,
                                            isSelected: nav.selectedIndex == idx
                                        ) {
                                            PopupWindowController.shared.pasteItem(item)
                                        }
                                        .id(idx)
                                        .onTapGesture {
                                            nav.selectedIndex = idx
                                        }
                                    }
                                }
                            }
                            .onChange(of: nav.selectedIndex) { idx in
                                withAnimation { proxy.scrollTo(idx, anchor: .center) }
                            }
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: showSettings)
    }
}

// MARK: - Row

struct ClipboardRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onPaste: () -> Void

    @EnvironmentObject var store: ClipboardStore
    @State private var isHovered = false

    var body: some View {
        Group {
            if item.itemType == .image {
                ImageRowContent(item: item, isSelected: isSelected, isHovered: isHovered, onPaste: onPaste)
            } else {
                TextRowContent(item: item, isSelected: isSelected, isHovered: isHovered)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, item.itemType == .image ? 6 : 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                .padding(.horizontal, 4)
        )
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { onPaste() }
        .contentShape(Rectangle())
        .overlay(alignment: .trailing) {
            if isHovered {
                rowActions
                    .padding(.trailing, 18)
            } else if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.6) : .secondary.opacity(0.5))
                    .padding(.trailing, 18)
            }
        }
    }

    private var rowActions: some View {
        HStack(spacing: 8) {
            Button { store.togglePin(item) } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
            }
            .buttonStyle(.plain)

            if !item.isPinned {
                Button { store.delete(item) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Image row

private struct ImageRowContent: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isHovered: Bool
    let onPaste: () -> Void

    @State private var thumbnailHovered = false
    @State private var showPreview = false

    private var loadedImage: NSImage? {
        item.imagePath.flatMap { NSImage(contentsOfFile: $0) }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Thumbnail
            thumbnailView

            // Metadata
            VStack(alignment: .leading, spacing: 3) {
                Text("Image")
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .white : .primary)
                if let img = loadedImage {
                    Text("\(Int(img.size.width)) × \(Int(img.size.height))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(isSelected ? .white.opacity(0.6) : .secondary)
                }
                Text(relativeTime(item.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            }

            // Reserve space for overlay actions — prevents text jumping on hover
            Spacer()
            Color.clear.frame(width: isHovered ? 48 : 0)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let img = loadedImage {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                )
                .onHover { hovering in
                    thumbnailHovered = hovering
                    if hovering {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            if thumbnailHovered { showPreview = true }
                        }
                    } else {
                        showPreview = false
                    }
                }
                .popover(isPresented: $showPreview, arrowEdge: .trailing) {
                    ImagePreviewPopover(image: img)
                }
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 96, height: 60)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                )
        }
    }
}

// MARK: - Image preview popover

private struct ImagePreviewPopover: View {
    let image: NSImage

    // Compute display size preserving aspect ratio, capped at 360×260
    private var displaySize: CGSize {
        let maxW: CGFloat = 360
        let maxH: CGFloat = 260
        let ratio = image.size.width / max(image.size.height, 1)
        if ratio > maxW / maxH {
            return CGSize(width: maxW, height: maxW / ratio)
        } else {
            return CGSize(width: maxH * ratio, height: maxH)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: displaySize.width, height: displaySize.height)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack {
                Image(systemName: "photo")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("\(Int(image.size.width)) × \(Int(image.size.height)) px")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .frame(minWidth: 120)
    }
}

// MARK: - Text row

private struct TextRowContent: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            typeIcon
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundColor(isSelected ? .white : .primary)
                Text(relativeTime(item.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            }

            Spacer()
            // Reserve space for overlay actions
            Color.clear.frame(width: isHovered ? 48 : 0)
        }
    }

    @ViewBuilder
    private var typeIcon: some View {
        switch item.clipType {
        case .link:
            Image(systemName: "link")
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .blue)
        case .email:
            Image(systemName: "envelope")
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .orange)
        default:
            Image(systemName: "doc.text")
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
        }
    }
}

// MARK: - Filter chip

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isActive ? Color.accentColor : Color.primary.opacity(0.1))
                )
                .foregroundColor(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Visual effect background

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.state = .active
        v.material = .popover
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Time helper

private func relativeTime(_ date: Date) -> String {
    let diff = Date().timeIntervalSince(date)
    switch diff {
    case ..<60:       return "Just now"
    case ..<3600:     return "\(Int(diff / 60))m ago"
    case ..<86400:    return "\(Int(diff / 3600))h ago"
    case ..<172800:   return "Yesterday"
    default:
        let f = DateFormatter()
        f.dateStyle = .short
        return f.string(from: date)
    }
}
