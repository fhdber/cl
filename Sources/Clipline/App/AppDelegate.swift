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
            self.shelf.show()
        }
        if Prefs.notchHover { notchHover.start() }

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

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "list.clipboard", accessibilityDescription: "Clipline")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
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
        menu.addItem(NSMenuItem(title: "Clipline beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

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
