import Foundation

/// Picks up screenshots saved to disk (⇧⌘3 / ⇧⌘4 / ⇧⌘5) via Spotlight's kMDItemIsScreenCapture flag,
/// so it works wherever the user has pointed their screenshot location.
final class ScreenshotWatcher {
    private let store: ClipStore
    private var query: NSMetadataQuery?
    private var observer: NSObjectProtocol?
    private var seen = Set<String>()
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff"]

    init(store: ClipStore) {
        self.store = store
    }

    func start() {
        guard query == nil else { return }
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1 AND kMDItemFSCreationDate >= %@",
                                      Date() as NSDate)
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate, object: query, queue: .main
        ) { [weak self] note in self?.handle(note) }
        query.start()
        self.query = query
    }

    func stop() {
        query?.stop()
        query = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    private func handle(_ note: Notification) {
        let added = note.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
        for item in added {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !seen.contains(path),
                  Self.imageExtensions.contains((path as NSString).pathExtension.lowercased()) else { continue }
            seen.insert(path)
            let url = URL(fileURLWithPath: path)
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let data = try? Data(contentsOf: url) else { return }
                DispatchQueue.main.async {
                    self?.store.ingestImage(data, kind: .screenshot, appName: "Screenshot",
                                            bundleID: "com.apple.screenshot.launcher")
                }
            }
        }
    }
}
