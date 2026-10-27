import AppKit
import Combine
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
        level = .popUpMenu // above the menu bar, so the shelf reads as an extension of the notch
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

enum Surface {
    /// Hangs from the notch, horizontal strip of cards.
    case shelf
    /// Compact grid that pops up at the pointer.
    case quickPaste
}

final class SurfaceController {
    let model: PanelModel
    private let surface: Surface
    private let panel = ClipPanel()
    private let store: ClipStore
    private let monitor: PasteboardMonitor
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var previewSubscription: AnyCancellable?
    private var screen: NSScreen?
    private(set) var isOpen = false

    init(surface: Surface, store: ClipStore, monitor: PasteboardMonitor) {
        self.surface = surface
        self.store = store
        self.monitor = monitor
        model = PanelModel(store: store)
        model.columns = surface == .quickPaste ? Layout.quickPasteColumns : 1
        model.onPaste = { [weak self] items in self?.deliver(items, paste: true) }
        model.onCopy = { [weak self] items in self?.deliver(items, paste: false) }
        model.onCopyText = { [weak self] text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            self?.monitor.skipCurrentChange()
        }

        let root: AnyView = surface == .shelf
            ? AnyView(ShelfView(model: model, store: store))
            : AnyView(QuickPasteView(model: model, store: store))
        let host = NSHostingView(rootView: root)
        host.sizingOptions = [] // the controller owns the panel frame
        panel.contentView = host

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in self?.hide() }

        if surface == .shelf {
            // The preview grows the shelf downwards.
            previewSubscription = model.$previewID
                .map { $0 != nil }
                .removeDuplicates()
                .sink { [weak self] _ in DispatchQueue.main.async { self?.relayout() } }
        }
    }

    func toggle() {
        isOpen ? hide() : show()
    }

    func show() {
        guard !isOpen else { return }
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return }
        self.screen = screen

        isOpen = true
        model.prepareForShow()
        let frame = targetFrame(on: screen, mouse: mouse)
        let start = surface == .shelf ? frame.offsetBy(dx: 0, dy: 18) : frame.offsetBy(dx: 0, dy: -8)
        panel.setFrame(start, display: false)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
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

    /// Closes without animation, e.g. before a synthetic ⌘V or a screen capture.
    func hideNow() {
        isOpen = false
        removeMonitors()
        panel.orderOut(nil)
    }

    private func targetFrame(on screen: NSScreen, mouse: NSPoint) -> NSRect {
        switch surface {
        case .shelf:
            let width = min(Layout.shelfWidth, screen.frame.width - 40)
            let height = Layout.shelfHeight + (model.previewID == nil ? 0 : Layout.detailGap + Layout.detailHeight)
            return NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        case .quickPaste:
            let size = Layout.quickPasteSize
            let visible = screen.visibleFrame
            let x = min(max(mouse.x - 24, visible.minX + 8), visible.maxX - size.width - 8)
            var y = mouse.y - size.height - 12
            if y < visible.minY + 8 { y = min(mouse.y + 12, visible.maxY - size.height - 8) }
            return NSRect(x: x, y: y, width: size.width, height: size.height)
        }
    }

    private func relayout() {
        guard isOpen, surface == .shelf, let screen else { return }
        let frame = targetFrame(on: screen, mouse: NSEvent.mouseLocation)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            self.panel.animator().setFrame(frame, display: true)
        }
    }

    private func deliver(_ items: [ClipItem], paste: Bool) {
        Paster.write(items, store: store)
        monitor.skipCurrentChange()
        if items.count == 1 { store.moveToTop(items.map(\.id)) }
        hideNow() // so the synthetic ⌘V reaches the target app, not this panel
        if paste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { Paster.sendPasteKeystroke() }
        }
    }

    // MARK: - Input

    private func installMonitors() {
        removeMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            let consumed = KeyRouter.handle(event, model: self.model,
                                            previewEnabled: self.surface == .shelf,
                                            close: { self.hide() })
            return consumed ? nil : event
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
}

/// Keyboard handling shared by all surfaces.
enum KeyRouter {
    /// Returns true when the event was consumed.
    static func handle(_ event: NSEvent, model: PanelModel, previewEnabled: Bool, close: () -> Void) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if model.isAddingCollection {
            if event.keyCode == 53 { model.cancelNewCollection(); return true }
            return false
        }

        switch event.keyCode {
        case 53: // esc
            if model.previewID != nil {
                model.previewID = nil
            } else if !model.query.isEmpty {
                model.query = ""
            } else {
                close()
            }
            return true
        case 123: // ←
            model.move(-1, extend: modifiers.contains(.shift))
            return true
        case 124: // →
            model.move(1, extend: modifiers.contains(.shift))
            return true
        case 125 where model.columns > 1: // ↓
            model.move(model.columns, extend: modifiers.contains(.shift))
            return true
        case 126 where model.columns > 1: // ↑
            model.move(-model.columns, extend: modifiers.contains(.shift))
            return true
        case 36, 76: // return
            model.pasteSelection()
            return true
        case 49 where previewEnabled && model.query.isEmpty && modifiers.isEmpty: // space
            model.togglePreview()
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
        case "f":
            model.focusToken += 1
            return true
        case ",":
            model.onOpenSettings?()
            return true
        default:
            return false
        }
    }
}

// MARK: - Library window

final class LibraryController: NSObject, NSWindowDelegate {
    let model: PanelModel
    private let store: ClipStore
    private let monitor: PasteboardMonitor
    private var window: NSWindow?
    private var keyMonitor: Any?

    init(store: ClipStore, monitor: PasteboardMonitor) {
        self.store = store
        self.monitor = monitor
        model = PanelModel(store: store)
        super.init()
        model.onPaste = { [weak self] items in self?.deliver(items, paste: true) }
        model.onCopy = { [weak self] items in self?.deliver(items, paste: false) }
        model.onCopyText = { [weak self] text in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            self?.monitor.skipCurrentChange()
        }
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1160, height: 720),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = "Clipline"
            window.backgroundColor = .black
            window.appearance = NSAppearance(named: .darkAqua)
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 720, height: 480)
            window.contentView = NSHostingView(rootView: LibraryView(model: model, store: store))
            window.delegate = self
            window.center()
            window.setFrameAutosaveName("ClipLibrary")
            self.window = window
        }
        model.prepareForShow()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func windowWillClose(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, window.isKeyWindow else { return event }
            let consumed = KeyRouter.handle(event, model: self.model, previewEnabled: false,
                                            close: { window.performClose(nil) })
            return consumed ? nil : event
        }
    }

    private func deliver(_ items: [ClipItem], paste: Bool) {
        Paster.write(items, store: store)
        monitor.skipCurrentChange()
        guard paste else { return }
        // Hand focus back to the previous app, then paste there.
        window?.orderOut(nil)
        NSApp.hide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { Paster.sendPasteKeystroke() }
    }
}
