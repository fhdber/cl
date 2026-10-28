import AppKit
import Carbon
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ClipStore()
    private var monitor: PasteboardMonitor!
    private var screenshots: ScreenshotWatcher!
    private var shelf: SurfaceController!
    private var quickPaste: SurfaceController!
    private var library: LibraryController!
    private var notchHover: NotchHover!
    private var hotKeys: [HotKey] = []
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var defaultsObserver: NSObjectProtocol?

    /// kVK_ANSI_0 … kVK_ANSI_9
    private static let digitKeyCodes = [kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
                                        kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.register()

        monitor = PasteboardMonitor(store: store)
        monitor.start()

        screenshots = ScreenshotWatcher(store: store)
        if Prefs.captureScreenshots { screenshots.start() }

        shelf = SurfaceController(surface: .shelf, store: store, monitor: monitor)
        quickPaste = SurfaceController(surface: .quickPaste, store: store, monitor: monitor)
        library = LibraryController(store: store, monitor: monitor)

        for model in [shelf.model, quickPaste.model, library.model] {
            model.onOpenSettings = { [weak self] in self?.openSettings() }
            model.onOpenLibrary = { [weak self] in self?.openLibrary() }
        }
        shelf.model.onCaptureText = { [weak self] in self?.captureText() }
        shelf.model.onPickColor = { [weak self] in self?.pickColor() }

        registerHotKeys()

        notchHover = NotchHover { [weak self] in
            guard let self, !self.shelf.isOpen else { return }
            self.quickPaste.hideNow()
            self.shelf.show(openedByHover: true)
        }
        if Prefs.notchHover { notchHover.start() }

        setupMainMenu()
        setupStatusItem()
        observeDefaults()

        if !Paster.isTrusted && !UserDefaults.standard.bool(forKey: Prefs.Key.didPromptAccessibility) {
            UserDefaults.standard.set(true, forKey: Prefs.Key.didPromptAccessibility)
            Paster.requestAccess()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.saveNow()
    }

    // MARK: - Shortcuts

    private func registerHotKeys() {
        let controlCommand = UInt32(controlKey | cmdKey)
        // ⌃⌘V quick paste · ⌥⌘V shelf · ⌃⌘L library
        hotKeys.append(HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: controlCommand) { [weak self] in
            self?.toggleQuickPaste()
        })
        hotKeys.append(HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey | cmdKey)) { [weak self] in
            self?.toggleShelf()
        })
        hotKeys.append(HotKey(keyCode: UInt32(kVK_ANSI_L), modifiers: controlCommand) { [weak self] in
            self?.openLibrary()
        })
        // ⌃⌘0 … ⌃⌘9 paste one of the ten newest clips straight away.
        for (index, keyCode) in Self.digitKeyCodes.enumerated() {
            hotKeys.append(HotKey(keyCode: UInt32(keyCode), modifiers: controlCommand) { [weak self] in
                self?.pasteRecent(index)
            })
        }
    }

    @objc private func toggleQuickPaste() {
        shelf.hideNow()
        quickPaste.toggle()
    }

    @objc private func toggleShelf() {
        quickPaste.hideNow()
        shelf.toggle()
    }

    @objc private func openLibrary() {
        shelf.hideNow()
        quickPaste.hideNow()
        library.show()
    }

    private func pasteRecent(_ index: Int) {
        guard store.items.indices.contains(index) else { return }
        shelf.hideNow()
        quickPaste.hideNow()
        Paster.write([store.items[index]], store: store)
        monitor.skipCurrentChange()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { Paster.sendPasteKeystroke() }
    }

    // MARK: - Shelf tools

    /// Select a screen area: it's stored as a screenshot and its text lands on the clipboard.
    private func captureText() {
        shelf.hideNow()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clipline-capture-\(UUID().uuidString).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", url.path]
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, let data = try? Data(contentsOf: url) else { return }
                self.store.ingestImage(data, kind: .screenshot, title: "Textaufnahme", appName: "Screenshot",
                                       bundleID: "com.apple.screenshot.launcher")
                TextRecognizer.recognize(imageAt: url) { text in
                    try? FileManager.default.removeItem(at: url)
                    guard let text else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
        }
        try? process.run()
    }

    private func pickColor() {
        shelf.hideNow()
        let sampler = NSColorSampler()
        sampler.show { color in
            _ = sampler
            guard let color = color?.usingColorSpace(.sRGB) else { return }
            let hex = String(format: "#%02X%02X%02X",
                             Int(round(color.redComponent * 255)),
                             Int(round(color.greenComponent * 255)),
                             Int(round(color.blueComponent * 255)))
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)
        }
    }

    // MARK: - Status item

    @objc func quit() {
        store.saveNow()
        NSApp.terminate(nil)
    }

    /// A menu-bar-only app has no main menu, so ⌘Q and the edit shortcuts (⌘C, ⌘V, ⌘A in text
    /// fields) would do nothing while Settings or the Library is in front. This adds them.
    private func setupMainMenu() {
        let main = NSMenu()

        let appMenu = NSMenu(title: "Clipline")
        addItem(to: appMenu, "Einstellungen …", #selector(openSettings), key: ",", modifiers: [.command])
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Clipline ausblenden", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(.separator())
        addItem(to: appMenu, "Clipline beenden", #selector(quit), key: "q", modifiers: [.command])
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editMenu = NSMenu(title: "Bearbeiten")
        editMenu.addItem(NSMenuItem(title: "Widerrufen", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Wiederholen", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Ausschneiden", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Kopieren", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Einsetzen", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        main.addItem(editItem)

        let windowMenu = NSMenu(title: "Fenster")
        windowMenu.addItem(NSMenuItem(title: "Schließen", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        windowMenu.addItem(NSMenuItem(title: "Im Dock ablegen", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        let windowItem = NSMenuItem()
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.menuBarIcon()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// The app icon's paper clip as a template image, so it follows the menu bar's light/dark tint.
    /// Same geometry as Resources/Icon/E-clip.svg, drawn upright for crisp pixels.
    private static func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            // Wire in icon units (y up): outer loop, long right leg, small bend, inner leg.
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 0, y: 156))
            path.line(to: NSPoint(x: 0, y: 374))
            path.appendArc(withCenter: NSPoint(x: 112, y: 374), radius: 112, startAngle: 180, endAngle: 0, clockwise: true)
            path.line(to: NSPoint(x: 224, y: 56))
            path.appendArc(withCenter: NSPoint(x: 168, y: 56), radius: 56, startAngle: 0, endAngle: 180, clockwise: true)
            path.line(to: NSPoint(x: 112, y: 296))

            let scale: CGFloat = 13.5 / 486
            path.transform(using: AffineTransform(m11: scale, m12: 0, m21: 0, m22: scale,
                                                  tX: (rect.width - 224 * scale) / 2,
                                                  tY: (rect.height - 486 * scale) / 2))
            path.lineWidth = 1.7
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Clipline"
        return image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        addItem(to: menu, "Bibliothek öffnen", #selector(openLibraryFromMenu), key: "l", modifiers: [.control, .command])
        addItem(to: menu, "Quick Paste …", #selector(openQuickPasteFromMenu), key: "v", modifiers: [.control, .command])
        addItem(to: menu, "Shelf öffnen", #selector(openShelfFromMenu), key: "v", modifiers: [.option, .command])

        let history = NSMenu()
        for (index, item) in store.items.prefix(10).enumerated() {
            let entry = NSMenuItem(title: item.menuTitle, action: #selector(pasteFromMenu(_:)), keyEquivalent: "\(index)")
            entry.keyEquivalentModifierMask = [.control, .command]
            entry.representedObject = index
            entry.image = AppIcons.icon(for: item.sourceBundleID).map { icon in
                let small = icon.copy() as? NSImage ?? icon
                small.size = NSSize(width: 16, height: 16)
                return small
            }
            entry.target = self
            history.addItem(entry)
        }
        if history.items.isEmpty {
            let empty = NSMenuItem(title: "Noch leer", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            history.addItem(empty)
        }
        let historyItem = NSMenuItem(title: "Verlauf", action: nil, keyEquivalent: "")
        historyItem.submenu = history
        menu.addItem(historyItem)
        menu.addItem(.separator())

        addItem(to: menu, "Einstellungen …", #selector(openSettings), key: ",", modifiers: [.command])
        addItem(to: menu, Prefs.paused ? "Aufnahme fortsetzen" : "Aufnahme pausieren", #selector(togglePause))
        addItem(to: menu, "Verlauf löschen …", #selector(confirmClearHistory))
        menu.addItem(.separator())
        addItem(to: menu, "Clipline beenden", #selector(quit), key: "q", modifiers: [.command])

        statusItem.button?.appearsDisabled = Prefs.paused
    }

    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector,
                         key: String = "", modifiers: NSEvent.ModifierFlags = []) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        menu.addItem(item)
    }

    // Let the menu finish closing before a panel takes key focus.
    @objc private func openLibraryFromMenu() { DispatchQueue.main.async { self.openLibrary() } }
    @objc private func openQuickPasteFromMenu() { DispatchQueue.main.async { self.toggleQuickPaste() } }
    @objc private func openShelfFromMenu() { DispatchQueue.main.async { self.toggleShelf() } }

    @objc private func pasteFromMenu(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        DispatchQueue.main.async { self.pasteRecent(index) }
    }

    @objc private func togglePause() {
        Prefs.paused.toggle()
        statusItem.button?.appearsDisabled = Prefs.paused
    }

    @objc private func confirmClearHistory() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Gesamten Verlauf löschen?"
        alert.informativeText = "Favoriten und Clips in Kategorien bleiben erhalten."
        alert.addButton(withTitle: "Löschen")
        alert.addButton(withTitle: "Abbrechen")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn { store.clearHistory() }
    }

    @objc func openSettings() {
        shelf.hideNow()
        quickPaste.hideNow()
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(store: store, refresher: SettingsRefresher()))
            let window = NSWindow(contentViewController: host)
            window.title = "Clipline"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Settings changes

    private func observeDefaults() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            if Prefs.captureScreenshots { self.screenshots.start() } else { self.screenshots.stop() }
            if Prefs.notchHover { self.notchHover.start() } else { self.notchHover.stop() }
            self.store.prune()
        }
    }
}
