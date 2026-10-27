import AppKit
import QuartzCore
import SwiftUI

/// Borderless, non-activating panel: it takes keyboard focus without stealing activation
/// from the app you're working in, so ⌘V lands right back there.
final class ClipPanel: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PanelController {
    private let panel = ClipPanel()
    private let store: ClipStore
    private let monitor: PasteboardMonitor
    private let model: PanelModel
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var isOpen = false
    var onOpenSettings: (() -> Void)?

    private let panelHeight: CGFloat = 340
    private let margin: CGFloat = 10

    init(store: ClipStore, monitor: PasteboardMonitor) {
        self.store = store
        self.monitor = monitor
        model = PanelModel(store: store)
        model.onPaste = { [weak self] items in self?.deliver(items, paste: true) }
        model.onCopy = { [weak self] items in self?.deliver(items, paste: false) }
        model.onCopyText = { [weak self] text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            self?.monitor.skipCurrentChange()
        }
        model.onOpenSettings = { [weak self] in self?.onOpenSettings?() }

        let root = PanelView(model: model, store: store)
        let host = NSHostingView(rootView: root)
        host.sizingOptions = [] // the controller owns the panel frame
        panel.contentView = host

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in self?.hide() }
    }

    var isVisible: Bool { isOpen }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return }

        let visible = screen.visibleFrame
        let frame = NSRect(x: visible.minX + margin, y: visible.minY + margin,
                           width: visible.width - margin * 2, height: panelHeight)

        isOpen = true
        model.prepareForShow()
        panel.setFrame(frame.offsetBy(dx: 0, dy: -28), display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            self.panel.animator().setFrame(frame, display: true)
            self.panel.animator().alphaValue = 1
        }
        installMonitors()
    }

    func hide() {
        guard isOpen else { return }
        isOpen = false
        removeMonitors()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            self.panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !self.isOpen else { return }
            self.panel.orderOut(nil)
        })
    }

    private func deliver(_ items: [ClipItem], paste: Bool) {
        Paster.write(items, store: store)
        monitor.skipCurrentChange()
        if items.count == 1 { store.moveToTop(items.map(\.id)) }
        // Close instantly so the synthetic ⌘V reaches the target app, not this panel.
        isOpen = false
        removeMonitors()
        panel.orderOut(nil)
        if paste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { Paster.sendPasteKeystroke() }
        }
    }

    // MARK: - Keyboard

    private func installMonitors() {
        removeMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handle(event) ? nil : event
        }
        // Clicks in other apps close the panel.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        keyMonitor = nil
        clickMonitor = nil
    }

    /// Returns true when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if model.isAddingCollection {
            if event.keyCode == 53 { model.cancelNewCollection(); return true }
            return false
        }

        switch event.keyCode {
        case 53: // esc
            if model.query.isEmpty { hide() } else { model.query = "" }
            return true
        case 123: // ←
            model.move(-1, extend: modifiers.contains(.shift))
            return true
        case 124: // →
            model.move(1, extend: modifiers.contains(.shift))
            return true
        case 36, 76: // return
            model.pasteSelection()
            return true
        case 48: // tab
            model.cycleFilter(modifiers.contains(.shift) ? -1 : 1)
            return true
        case 51 where modifiers.contains(.command): // ⌘⌫
            model.deleteSelection()
            return true
        default:
            break
        }

        guard modifiers.contains(.command), let key = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }
        switch key {
        case "c" where !model.selection.isEmpty:
            model.copy(model.selectedItems)
            return true
        case "p":
            model.togglePinSelection()
            return true
        case ",":
            onOpenSettings?()
            return true
        default:
            // ⌘1 … ⌘9, ⌘0 → paste one of the last ten clips.
            if key.count == 1, let digit = Int(key) {
                model.paste(at: digit == 0 ? 9 : digit - 1)
                return true
            }
            return false
        }
    }
}
