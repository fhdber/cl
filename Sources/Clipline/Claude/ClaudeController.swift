import AppKit
import SwiftUI

/// Floating Claude panel. Non-activating like the shelf, so "Einfügen" lands in the app you came from.
final class ClaudeController {
    let session = ClaudeSession()
    private let panel = ClipPanel()
    private let store: ClipStore
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    var onOpenSettings: (() -> Void)?

    private let size = CGSize(width: 620, height: 520)

    init(store: ClipStore) {
        self.store = store
        panel.level = .floating
        let view = ClaudeView(session: session,
                              onClose: { [weak self] in self?.hide() },
                              onPaste: { [weak self] in self?.paste() },
                              onCopy: { [weak self] in self?.copy() },
                              onSaveClip: { [weak self] in self?.saveClip() },
                              onOpenSettings: { [weak self] in
                                  self?.hide()
                                  self?.onOpenSettings?()
                              })
        let host = NSHostingView(rootView: view)
        host.sizingOptions = []
        panel.contentView = host
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in self?.hide() }
    }

    var isOpen: Bool { panel.isVisible }

    /// Opens with a context; a running answer for the same context keeps going.
    func show(context: ClaudeSession.Context?) {
        session.reset(with: context)
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrame(NSRect(x: visible.midX - size.width / 2,
                                  y: visible.minY + visible.height * 0.62 - size.height / 2,
                                  width: size.width, height: size.height), display: false)
        }
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            self.panel.animator().alphaValue = 1
        }
        installKeyMonitor()
    }

    func hide() {
        guard panel.isVisible else { return }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel.orderOut(nil)
    }

    // MARK: - Result actions

    private func paste() {
        let text = session.response
        guard !text.isEmpty else { return }
        hide()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        // Not skipped on purpose: the answer becomes a clip as well.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { Paster.sendPasteKeystroke() }
    }

    private func copy() {
        guard !session.response.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(session.response, forType: .string)
        Toast.show("Kopiert", symbol: "doc.on.doc")
    }

    private func saveClip() {
        guard !session.response.isEmpty else { return }
        store.ingestText(session.response, appName: "Claude", bundleID: nil)
        Toast.show("Als Clip gespeichert", symbol: "tray.and.arrow.down")
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            switch event.keyCode {
            case 53: // esc
                if self.session.isRunning { self.session.cancel() } else { self.hide() }
                return nil
            case 36 where modifiers.contains(.command): // ⌘↩
                self.paste()
                return nil
            default:
                return event
            }
        }
    }

    // MARK: - Context helpers

    /// A clip as Claude context: text as text, images as image data, files by name (text files by content).
    static func context(for item: ClipItem, store: ClipStore) -> ClaudeSession.Context? {
        switch item.kind {
        case .text, .link, .code, .color:
            return item.text.map { .text($0, source: item.sourceAppName) }
        case .image, .screenshot:
            guard let url = store.imageURL(for: item), let data = try? Data(contentsOf: url) else { return nil }
            return .image(data, title: item.title)
        case .file:
            guard let urls = item.fileURLs, !urls.isEmpty else { return nil }
            return context(forFiles: urls)
        }
    }

    static func context(forFiles urls: [URL]) -> ClaudeSession.Context? {
        if urls.count == 1, let url = urls.first {
            let ext = url.pathExtension.lowercased()
            if ["png", "jpg", "jpeg", "heic", "tiff", "gif", "webp"].contains(ext), let data = try? Data(contentsOf: url) {
                return .image(data, title: url.lastPathComponent)
            }
            if let text = try? String(contentsOf: url, encoding: .utf8), text.count < 200_000 {
                return .text(text, source: url.lastPathComponent)
            }
        }
        return .text(urls.map(\.lastPathComponent).joined(separator: "\n"), source: "Dateien")
    }
}
