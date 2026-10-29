import AppKit

/// "Pin to screen": the image floats above everything, can be moved and resized.
/// Double-click or Esc closes it; right-click for copy and close.
final class PinController {
    private var panels: [NSPanel] = []

    func pin(_ image: NSImage) {
        let maxSide: CGFloat = 520
        var size = image.size
        let scale = min(1, maxSide / max(size.width, size.height, 1))
        size = CGSize(width: size.width * scale, height: size.height * scale)

        let mouse = NSEvent.mouseLocation
        let panel = PinPanel(contentRect: NSRect(x: mouse.x - size.width / 2, y: mouse.y - size.height / 2,
                                                 width: size.width, height: size.height),
                             styleMask: [.borderless, .resizable, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentAspectRatio = size
        panel.minSize = NSSize(width: 80, height: 80 * size.height / max(size.width, 1))
        panel.onClose = { [weak self, weak panel] in
            guard let panel else { return }
            panel.orderOut(nil)
            self?.panels.removeAll { $0 === panel }
        }
        panel.contentView = PinImageView(image: image, panel: panel)
        panels.append(panel)
        panel.makeKeyAndOrderFront(nil)
    }
}

private final class PinPanel: NSPanel {
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onClose?() } else { super.keyDown(with: event) }
    }
}

private final class PinImageView: NSImageView {
    private weak var pinPanel: PinPanel?

    init(image: NSImage, panel: PinPanel) {
        pinPanel = panel
        super.init(frame: .zero)
        self.image = image
        imageScaling = .scaleProportionallyUpOrDown
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor

        let menu = NSMenu()
        menu.addItem(withTitle: "Kopieren", action: #selector(copyImage), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Schließen", action: #selector(closePin), keyEquivalent: "").target = self
        self.menu = menu
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            pinPanel?.onClose?()
        } else {
            window?.performDrag(with: event)
        }
    }

    @objc private func copyImage() {
        guard let image else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        Toast.show("Kopiert", symbol: "doc.on.doc")
    }

    @objc private func closePin() {
        pinPanel?.onClose?()
    }
}
