import AppKit
import Carbon
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ClipStore()
    private var monitor: PasteboardMonitor!
    private var screenshots: ScreenshotWatcher!
    private var panel: PanelController!
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var defaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.register()

        monitor = PasteboardMonitor(store: store)
        monitor.start()

        screenshots = ScreenshotWatcher(store: store)
        if Prefs.captureScreenshots { screenshots.start() }

        panel = PanelController(store: store, monitor: monitor)
        panel.onOpenSettings = { [weak self] in self?.openSettings() }

        // ⌃⌘V opens the timeline from anywhere.
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | cmdKey)) { [weak self] in
            self?.panel.toggle()
        }

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

        let open = NSMenuItem(title: "Verlauf öffnen", action: #selector(openPanel), keyEquivalent: "v")
        open.keyEquivalentModifierMask = [.control, .command]
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        let recent = store.items.prefix(5)
        if !recent.isEmpty {
            let header = NSMenuItem(title: "Zuletzt kopiert", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for item in recent {
                let entry = NSMenuItem(title: item.menuTitle, action: #selector(copyRecent(_:)), keyEquivalent: "")
                entry.representedObject = item.id
                entry.image = NSImage(systemSymbolName: item.kind.symbol, accessibilityDescription: nil)
                entry.target = self
                menu.addItem(entry)
            }
            menu.addItem(.separator())
        }

        let pause = NSMenuItem(title: Prefs.paused ? "Aufnahme fortsetzen" : "Aufnahme pausieren",
                               action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)

        let settings = NSMenuItem(title: "Einstellungen …", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Clipline beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.button?.appearsDisabled = Prefs.paused
    }

    @objc private func openPanel() {
        // Let the menu finish closing before the panel takes key focus.
        DispatchQueue.main.async { self.panel.show() }
    }

    @objc private func copyRecent(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = store.items.first(where: { $0.id == id }) else { return }
        Paster.write([item], store: store)
        monitor.skipCurrentChange()
        store.moveToTop([id])
    }

    @objc private func togglePause() {
        Prefs.paused.toggle()
        statusItem.button?.appearsDisabled = Prefs.paused
    }

    @objc func openSettings() {
        panel.hide()
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(store: store))
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
            self.store.prune()
        }
    }
}
