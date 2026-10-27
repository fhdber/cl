import AppKit
import ApplicationServices

/// Writes clips back to the pasteboard and, with Accessibility access, types ⌘V into the frontmost app.
enum Paster {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func write(_ items: [ClipItem], store: ClipStore) {
        guard !items.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if items.count == 1, let item = items.first {
            writeSingle(item, to: pasteboard, store: store)
            return
        }

        // Multi-clip: text joins into one block, everything else goes over as files.
        let texts = items.filter(\.kind.isTextual).compactMap(\.text)
        if !texts.isEmpty {
            pasteboard.setString(texts.joined(separator: "\n\n"), forType: .string)
        } else {
            let urls = items.flatMap { item -> [URL] in
                if let url = store.imageURL(for: item) { return [url] }
                return item.fileURLs ?? []
            }
            pasteboard.writeObjects(urls as [NSURL])
        }
    }

    private static func writeSingle(_ item: ClipItem, to pasteboard: NSPasteboard, store: ClipStore) {
        switch item.kind {
        case .text, .link, .code, .color:
            pasteboard.setString(item.text ?? "", forType: .string)
        case .image, .screenshot:
            guard let url = store.imageURL(for: item), let data = try? Data(contentsOf: url) else { return }
            pasteboard.declareTypes([.png, .tiff], owner: nil)
            pasteboard.setData(data, forType: .png)
            if let tiff = NSImage(data: data)?.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        case .file:
            pasteboard.writeObjects((item.fileURLs ?? []) as [NSURL])
        }
    }

    static func sendPasteKeystroke() {
        guard isTrusted else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(9)
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
