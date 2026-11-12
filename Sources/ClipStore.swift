import AppKit
import CryptoKit

// MARK: - Model

struct ClipItem: Codable, Identifiable, Equatable {
    let id: UUID
    var text: String
    var imageFile: String?   // file name inside the images folder; nil for text items
    var date: Date
    var pinned: Bool

    var isImage: Bool { imageFile != nil }
}

@MainActor
final class ClipStore: ObservableObject {
    @Published var items: [ClipItem] = []
    private let maxItems = 200
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private let fileURL: URL
    let imagesDir: URL
    private let thumbCache = NSCache<NSString, NSImage>()

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cliptap", isDirectory: true)
        ClipStore.migrateOldFolder(to: dir)
        imagesDir = dir.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        fileURL = dir.appendingPathComponent("history.json")
        lastChangeCount = pasteboard.changeCount
        load()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    /// Early builds were called "Clipboard History" and stored data in a different folder.
    private static func migrateOldFolder(to dir: URL) {
        let fm = FileManager.default
        let old = dir.deletingLastPathComponent().appendingPathComponent("ClipboardHistory", isDirectory: true)
        guard fm.fileExists(atPath: old.path), !fm.fileExists(atPath: dir.path) else { return }
        try? fm.moveItem(at: old, to: dir)
    }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        let types = pasteboard.types ?? []
        // Skip secrets that password managers mark as concealed or transient.
        let skip: Set<String> = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
        if types.contains(where: { skip.contains($0.rawValue) }) { return }

        // Prefer text when present (rich text and Finder file copies also carry an image).
        if let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            addText(text)
        } else if let image = NSImage(pasteboard: pasteboard) {
            addImage(image)
        }
    }

    private func addText(_ text: String) {
        insert(matching: { !$0.isImage && $0.text == text }) {
            ClipItem(id: UUID(), text: text, imageFile: nil, date: Date(), pinned: $0)
        }
    }

    private func addImage(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        let hash = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        let name = "\(hash.prefix(32)).png"
        let url = imagesDir.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? png.write(to: url, options: [.atomic])
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
        let label = "Image \(rep.pixelsWide)×\(rep.pixelsHigh)"
        insert(matching: { $0.imageFile == name }) {
            ClipItem(id: UUID(), text: label, imageFile: name, date: Date(), pinned: $0)
        }
    }

    /// Moves a matching item to the top, or adds a new one.
    private func insert(matching: (ClipItem) -> Bool, make: (Bool) -> ClipItem) {
        var pinned = false
        if let i = items.firstIndex(where: matching) {
            pinned = items[i].pinned
            items.remove(at: i)
        }
        items.insert(make(pinned), at: 0)
        trim()
        save()
    }

    func copy(_ item: ClipItem) {
        pasteboard.clearContents()
        if let name = item.imageFile {
            guard let image = NSImage(contentsOf: imagesDir.appendingPathComponent(name)) else { return }
            pasteboard.writeObjects([image])
        } else {
            pasteboard.setString(item.text, forType: .string)
        }
        lastChangeCount = pasteboard.changeCount
        if let i = items.firstIndex(where: { $0.id == item.id }) {
            var moved = items.remove(at: i)
            moved.date = Date()
            items.insert(moved, at: 0)
            save()
        }
    }

    func thumbnail(for item: ClipItem) -> NSImage? {
        guard let name = item.imageFile else { return nil }
        if let cached = thumbCache.object(forKey: name as NSString) { return cached }
        guard let image = NSImage(contentsOf: imagesDir.appendingPathComponent(name)) else { return nil }
        thumbCache.setObject(image, forKey: name as NSString)
        return image
    }

    func togglePin(_ item: ClipItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].pinned.toggle()
        save()
    }

    func delete(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        removeImageFile(of: item)
        save()
    }

    func clearUnpinned() {
        let removed = items.filter { !$0.pinned }
        items.removeAll { !$0.pinned }
        removed.forEach(removeImageFile)
        save()
    }

    private func removeImageFile(of item: ClipItem) {
        guard let name = item.imageFile else { return }
        thumbCache.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(name))
    }

    private func trim() {
        while items.count > maxItems, let i = items.lastIndex(where: { !$0.pinned }) {
            removeImageFile(of: items.remove(at: i))
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: [.atomic])
        // History may hold private text, so only the user can read the file.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
