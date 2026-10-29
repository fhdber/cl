import AppKit

/// CleanShot-style capture on top of macOS' own `screencapture`: area, window, screen or the
/// system toolbar. Every capture lands in the history, optionally on the clipboard, and opens
/// the quick-access card.
final class CaptureService {
    enum Mode {
        case area, window, screen, toolbar

        var title: String {
            switch self {
            case .area: return "Bereich aufnehmen"
            case .window: return "Fenster aufnehmen"
            case .screen: return "Bildschirm aufnehmen"
            case .toolbar: return "Aufnahme-Werkzeugleiste …"
            }
        }
    }

    private let store: ClipStore
    private let monitor: PasteboardMonitor
    var onCaptured: ((URL) -> Void)?
    /// Called right before capturing, so floating panels get out of the way.
    var onWillCapture: (() -> Void)?

    static let folder: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = support.appendingPathComponent("Clipline/captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static let nameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd 'um' HH.mm.ss"
        return formatter
    }()

    init(store: ClipStore, monitor: PasteboardMonitor) {
        self.store = store
        self.monitor = monitor
    }

    static func newFileURL(prefix: String = "Clipline") -> URL {
        folder.appendingPathComponent("\(prefix) \(nameFormatter.string(from: Date())).png")
    }

    func capture(_ mode: Mode) {
        onWillCapture?()
        let url = Self.newFileURL()
        var arguments: [String]
        switch mode {
        case .area:
            arguments = ["-i", "-x"]
        case .window:
            arguments = ["-i", "-W", "-x"]
        case .screen:
            // The display under the pointer (screencapture counts displays from 1).
            let mouse = NSEvent.mouseLocation
            let index = (NSScreen.screens.firstIndex { NSMouseInRect(mouse, $0.frame, false) } ?? 0) + 1
            arguments = ["-x", "-D", "\(index)"]
        case .toolbar:
            arguments = ["-i", "-U"]
        }
        arguments.append(url.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.finish(url) }
        }
        // A short pause lets panels fade away before the screen is grabbed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { try? process.run() }
    }

    private func finish(_ url: URL) {
        // Esc during selection leaves no file – that's a cancel, not an error.
        guard FileManager.default.fileExists(atPath: url.path), let data = try? Data(contentsOf: url) else { return }
        store.ingestImage(data, kind: .screenshot, title: url.deletingPathExtension().lastPathComponent,
                          appName: "Clipline", bundleID: Bundle.main.bundleIdentifier)
        if Prefs.captureCopies {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setData(data, forType: .png)
            monitor.skipCurrentChange()
        }
        onCaptured?(url)
    }

    /// Copies a capture to the save folder (Desktop by default) with a readable name.
    static func save(_ url: URL) -> URL? {
        let folder = URL(fileURLWithPath: (Prefs.captureSaveFolder as NSString).expandingTildeInPath, isDirectory: true)
        var target = folder.appendingPathComponent(url.lastPathComponent)
        var counter = 2
        while FileManager.default.fileExists(atPath: target.path) {
            target = folder.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent) \(counter).png")
            counter += 1
        }
        do {
            try FileManager.default.copyItem(at: url, to: target)
            return target
        } catch {
            return nil
        }
    }

    static func writeImage(_ data: Data) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: .png)
    }
}
