import AppKit
import ApplicationServices

/// Writes clips back to the pasteboard and, with Accessibility access, types ⌘V into the frontmost app.
enum Paster {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccess() {
        let key = "AXTrustedCheckOptionPrompt" // kAXTrustedCheckOptionPrompt
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
            // Images copied from Finder keep their file, so pasting into Finder/Mail still yields the file.
            let original = item.fileURLs?.first
            pasteboard.declareTypes(original == nil ? [.png, .tiff] : [.fileURL, .png, .tiff], owner: nil)
            if let original { pasteboard.setString(original.absoluteString, forType: .fileURL) }
            pasteboard.setData(data, forType: .png)
            if let tiff = NSImage(data: data)?.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        case .file:
            pasteboard.writeObjects((item.fileURLs ?? []) as [NSURL])
        }
    }

    /// ⌘C into the frontmost app – grabs the current selection (needs Accessibility, like paste).
    static func sendCopyKeystroke() {
        guard isTrusted else { return }
        let source = CGEventSource(stateID: .combinedSessionState)
        let cKey = CGKeyCode(8)
        let down = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
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
