import AppKit
import Combine

/// Files parked in the notch. Only references are kept; the files stay where they are.
final class TrayStore: ObservableObject {
    static let shared = TrayStore()

    @Published private(set) var files: [URL] = []

    init() {
        files = (UserDefaults.standard.stringArray(forKey: Prefs.Key.trayFiles) ?? [])
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func add(_ urls: [URL]) {
        let new = urls.filter { url in url.isFileURL && !files.contains(url) }
        guard !new.isEmpty else { return }
        files.append(contentsOf: new)
        save()
    }

    func remove(_ url: URL) {
        files.removeAll { $0 == url }
        save()
    }

    func clear() {
        files = []
        save()
    }

    func airDrop(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
    }

    private func save() {
        UserDefaults.standard.set(files.map(\.path), forKey: Prefs.Key.trayFiles)
    }

    /// Reads file URLs from dropped item providers.
    static func loadURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        // A reference box instead of a captured `var`, so strict concurrency checking stays quiet.
        final class Collected { var urls: [URL] = []; let lock = NSLock() }
        let collected = Collected()
        let group = DispatchGroup()
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    collected.lock.lock()
                    collected.urls.append(url)
                    collected.lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(collected.urls) }
    }
}
