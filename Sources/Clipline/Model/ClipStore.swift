import AppKit
import Combine
import CryptoKit
import ImageIO

/// Local-first library: a JSON index plus PNG files in ~/Library/Application Support/Clipline.
final class ClipStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []
    @Published private(set) var collections: [String] = []

    let imagesURL: URL
    private let indexURL: URL
    private var pendingSave: DispatchWorkItem?
    private let thumbnails = NSCache<NSString, NSImage>()

    private struct Library: Codable {
        var items: [ClipItem]
        var collections: [String]
    }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let base = support.appendingPathComponent("Clipline", isDirectory: true)
        imagesURL = base.appendingPathComponent("images", isDirectory: true)
        indexURL = base.appendingPathComponent("library.json")
        try? FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        load()
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Ingest

    /// If identical content already exists, move it to the top instead of duplicating it.
    @discardableResult
    func bump(hash: String, appName: String?, bundleID: String?) -> Bool {
        guard let index = items.firstIndex(where: { $0.contentHash == hash }) else { return false }
        var item = items.remove(at: index)
        item.createdAt = Date()
        if appName != nil { item.sourceAppName = appName; item.sourceBundleID = bundleID }
        items.insert(item, at: 0)
        scheduleSave()
        return true
    }

    func add(_ item: ClipItem) {
        items.insert(item, at: 0)
        prune()
        scheduleSave()
    }

    func ingestText(_ string: String, appName: String?, bundleID: String?) {
        let hash = Self.hash(Data(string.utf8))
        if bump(hash: hash, appName: appName, bundleID: bundleID) { return }
        add(ClipItem(kind: ContentClassifier.classify(string), text: string,
                     sourceAppName: appName, sourceBundleID: bundleID, contentHash: hash))
    }

    func ingestFiles(_ urls: [URL], appName: String?, bundleID: String?) {
        let hash = Self.hash(Data(urls.map(\.path).joined(separator: "\n").utf8))
        if bump(hash: hash, appName: appName, bundleID: bundleID) { return }
        add(ClipItem(kind: .file, fileURLs: urls,
                     sourceAppName: appName, sourceBundleID: bundleID, contentHash: hash))
    }

    /// Normalises any image data to PNG, stores it and runs OCR in the background.
    func ingestImage(_ data: Data, kind: ClipKind, appName: String?, bundleID: String?) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self,
                  let rep = NSBitmapImageRep(data: data),
                  let png = rep.representation(using: .png, properties: [:]) else { return }
            let hash = Self.hash(png)
            let size = CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            let file = "\(UUID().uuidString).png"
            let url = self.imagesURL.appendingPathComponent(file)

            DispatchQueue.main.async {
                if self.bump(hash: hash, appName: appName, bundleID: bundleID) { return }
                DispatchQueue.global(qos: .utility).async {
                    guard (try? png.write(to: url)) != nil else { return }
                    DispatchQueue.main.async {
                        let item = ClipItem(kind: kind, imageFile: file, imageSize: size,
                                            sourceAppName: appName, sourceBundleID: bundleID, contentHash: hash)
                        self.add(item)
                        guard Prefs.ocrEnabled else { return }
                        TextRecognizer.recognize(imageAt: url) { text in
                            self.update(item.id) { $0.ocrText = text }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Editing

    func update(_ id: UUID, _ change: (inout ClipItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
        scheduleSave()
    }

    func moveToTop(_ ids: [UUID]) {
        for id in ids.reversed() {
            guard let index = items.firstIndex(where: { $0.id == id }) else { continue }
            var item = items.remove(at: index)
            item.createdAt = Date()
            items.insert(item, at: 0)
        }
        scheduleSave()
    }

    func togglePin(_ ids: [UUID]) {
        let shouldPin = items.contains { ids.contains($0.id) && !$0.pinned }
        for id in ids { update(id) { $0.pinned = shouldPin } }
    }

    func delete(_ ids: Set<UUID>) {
        let removed = items.filter { ids.contains($0.id) }
        items.removeAll { ids.contains($0.id) }
        removed.forEach { removeFiles(of: $0) }
        scheduleSave()
    }

    func clearHistory() {
        delete(Set(items.filter { !$0.pinned && $0.collection == nil }.map(\.id)))
    }

    /// Drops the oldest clips beyond the history limit. Pinned clips and clips in a collection stay.
    func prune() {
        let limit = max(Prefs.historyLimit, 50)
        var kept = 0
        var overflow = Set<UUID>()
        for item in items {
            if item.pinned || item.collection != nil { continue }
            kept += 1
            if kept > limit { overflow.insert(item.id) }
        }
        if !overflow.isEmpty { delete(overflow) }
    }

    // MARK: - Collections

    func addCollection(_ name: String) {
        guard !collections.contains(name) else { return }
        collections.append(name)
        scheduleSave()
    }

    func removeCollection(_ name: String) {
        collections.removeAll { $0 == name }
        for item in items where item.collection == name {
            update(item.id) { $0.collection = nil }
        }
        scheduleSave()
    }

    func setCollection(_ name: String?, for ids: [UUID]) {
        for id in ids { update(id) { $0.collection = name } }
    }

    // MARK: - Files

    func imageURL(for item: ClipItem) -> URL? {
        item.imageFile.map { imagesURL.appendingPathComponent($0) }
    }

    func thumbnail(for item: ClipItem) -> NSImage? {
        guard let file = item.imageFile else { return nil }
        if let cached = thumbnails.object(forKey: file as NSString) { return cached }
        let url = imagesURL.appendingPathComponent(file)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 640,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        thumbnails.setObject(image, forKey: file as NSString)
        return image
    }

    func itemProvider(for item: ClipItem) -> NSItemProvider {
        switch item.kind {
        case .image, .screenshot:
            if let url = imageURL(for: item), let provider = NSItemProvider(contentsOf: url) { return provider }
        case .file:
            if let url = item.fileURLs?.first, let provider = NSItemProvider(contentsOf: url) { return provider }
        case .link:
            if let url = URL(string: item.text ?? "") { return NSItemProvider(object: url as NSURL) }
        default:
            break
        }
        return NSItemProvider(object: (item.text ?? "") as NSString)
    }

    private func removeFiles(of item: ClipItem) {
        guard let file = item.imageFile else { return }
        thumbnails.removeObject(forKey: file as NSString)
        try? FileManager.default.removeItem(at: imagesURL.appendingPathComponent(file))
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let library = try? decoder.decode(Library.self, from: data) else {
            // Never overwrite an unreadable library: keep it aside for recovery.
            let backup = indexURL.deletingLastPathComponent()
                .appendingPathComponent("library.unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: indexURL, to: backup)
            return
        }
        items = library.items
        collections = library.collections
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let snapshot = Library(items: items, collections: collections)
        let url = indexURL
        let work = DispatchWorkItem { Self.write(snapshot, to: url) }
        pendingSave = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        pendingSave?.cancel()
        Self.write(Library(items: items, collections: collections), to: indexURL)
    }

    private static func write(_ library: Library, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(library) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
