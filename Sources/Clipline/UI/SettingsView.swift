import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// Re-renders settings when values outside SwiftUI change (login item, Accessibility).
final class SettingsRefresher: ObservableObject {
    static let shared = SettingsRefresher()
    func refresh() { objectWillChange.send() }
}

/// Native preferences window: icon tabs in the toolbar, one calm grouped form per tab.
final class SettingsWindowController {
    private var window: NSWindow?
    private let store: ClipStore

    static let contentSize = CGSize(width: 560, height: 540)

    init(store: ClipStore) {
        self.store = store
    }

    func show() {
        if window == nil { window = makeWindow() }
        SettingsRefresher.shared.refresh()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = true

        func add<Content: View>(_ title: String, _ symbol: String, _ view: Content) {
            let host = NSHostingController(rootView: view.frame(width: Self.contentSize.width,
                                                                height: Self.contentSize.height))
            host.title = title
            let item = NSTabViewItem(viewController: host)
            item.label = title
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            tabs.addTabViewItem(item)
        }

        add("Allgemein", "gearshape", GeneralSettingsView(store: store, refresher: .shared))
        add("Notch", "rectangle.topthird.inset.filled", NotchSettingsView())
        add("Claude", "sparkle", ClaudeSettingsView(keys: .shared))
        add("Diktat", "mic", DictationSettingsView())
        add("Aufnahme", "camera.viewfinder", CaptureSettingsView())
        add("Ablage", "tray.full", TraySettingsView())
        add("Kurzbefehle", "command", ShortcutsSettingsView())

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

// MARK: - Allgemein

struct GeneralSettingsView: View {
    let store: ClipStore
    @ObservedObject var refresher: SettingsRefresher

    @AppStorage(Prefs.Key.historyLimit) private var historyLimit = 1000
    @AppStorage(Prefs.Key.paused) private var paused = false
    @AppStorage(Prefs.Key.ignoredApps) private var ignoredAppsRaw = Prefs.defaultIgnoredApps

    var body: some View {
        Form {
            Section {
                Toggle("Beim Anmelden starten", isOn: launchAtLogin)
            }

            Section("Verlauf") {
                Picker("Aufbewahren", selection: $historyLimit) {
                    Text("200 Clips").tag(200)
                    Text("1.000 Clips").tag(1000)
                    Text("5.000 Clips").tag(5000)
                    Text("20.000 Clips").tag(20000)
                }
                Toggle("Aufnahme pausieren", isOn: $paused)
                LabeledContent("Gesamten Verlauf") {
                    Button("Löschen …", role: .destructive, action: confirmClearHistory)
                }
            }

            Section {
                ForEach(installedIgnoredApps, id: \.self) { bundleID in
                    HStack(spacing: 8) {
                        if let icon = AppIcons.icon(for: bundleID) {
                            Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                        }
                        Text(appName(for: bundleID))
                        Spacer()
                        Button {
                            ignoredAppsRaw = ignoredApps.filter { $0 != bundleID }.joined(separator: ",")
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button("App hinzufügen …", action: addIgnoredApp)
            } header: {
                Text("Datenschutz")
            } footer: {
                Text("Aus diesen Apps wird nichts aufgenommen. Inhalte, die Passwort-Manager als vertraulich markieren, werden immer ignoriert.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent {
                    if trusted {
                        Label("Erlaubt", systemImage: "checkmark.circle.fill").foregroundStyle(Color.green)
                    } else {
                        Button("Erlauben …") { Paster.requestAccess() }
                    }
                } label: {
                    Text("Bedienungshilfen")
                    Text("Nötig, damit Clipline für dich einfügen und markierten Text an Claude geben kann.")
                }
            } header: {
                Text("Berechtigungen")
            }
        }
        .formStyle(.grouped)
    }

    private var trusted: Bool { Paster.isTrusted }

    /// Reads the real login-item status, so a failed registration never shows as "on".
    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { enabled in
                if enabled {
                    try? SMAppService.mainApp.register()
                } else {
                    try? SMAppService.mainApp.unregister()
                }
                refresher.refresh()
            }
        )
    }

    private func confirmClearHistory() {
        let alert = NSAlert()
        alert.messageText = "Gesamten Verlauf löschen?"
        alert.informativeText = "Favoriten und Clips in Kategorien bleiben erhalten."
        alert.addButton(withTitle: "Löschen")
        alert.addButton(withTitle: "Abbrechen")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn { store.clearHistory() }
    }

    private var ignoredApps: [String] { Prefs.split(ignoredAppsRaw) }

    /// Defaults cover password managers you may not have; only list what's actually installed.
    private var installedIgnoredApps: [String] {
        ignoredApps.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    private func appName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func addIgnoredApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        ignoredAppsRaw = Array(Set(ignoredApps + ids)).sorted().joined(separator: ",")
    }
}

// MARK: - Notch

struct NotchSettingsView: View {
    @AppStorage(Prefs.Key.notchHover) private var notchHover = true
    @AppStorage(Prefs.Key.shelfSize) private var shelfSize = "auto"
    @AppStorage(Prefs.Key.shelfStartTab) private var shelfStartTab = "clips"
    @AppStorage(Prefs.Key.liveActivity) private var liveActivity = true
    @AppStorage(Prefs.Key.fileDragOpensTray) private var fileDragOpensTray = true
    @AppStorage(Prefs.Key.pinnedShortcuts) private var pinnedShortcuts = ""

    var body: some View {
        Form {
            Section("Shelf") {
                Toggle("Öffnen, wenn die Maus an die Notch fährt", isOn: $notchHover)
                Picker("Größe", selection: $shelfSize) {
                    Text("Automatisch").tag("auto")
                    Text("Mini").tag("mini")
                    Text("Groß").tag("full")
                }
                Picker("Startet mit", selection: $shelfStartTab) {
                    Text("Clips").tag("clips")
                    Text("Nook").tag("nook")
                    Text("Ablage").tag("tray")
                }
            }

            Section {
                Toggle("Live-Aktivität, wenn Musik läuft", isOn: $liveActivity)
                Toggle("Dateien zur Notch ziehen öffnet die Ablage", isOn: $fileDragOpensTray)
                TextField("Kurzbefehle", text: $pinnedShortcuts, prompt: Text("Namen, durch Komma getrennt"))
            } header: {
                Text("Nook & Ablage")
            } footer: {
                Text("„Automatisch“ nimmt auf Bildschirmen unter 1600 pt das Mini-Shelf. Medien funktionieren mit Musik und Spotify.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Kurzbefehle

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Zwischenablage") {
                row("Quick Paste", "⌃ ⌘ V")
                row("Shelf", "⌥ ⌘ V")
                row("Bibliothek", "⌃ ⌘ L")
                row("Einen der letzten 10 Clips einfügen", "⌃ ⌘ 0 … 9")
            }
            Section("Claude & Diktat") {
                row("Claude fragen (mit Markierung)", "⌃ ⌘ C")
                row("Diktat – halten und sprechen", "⌃ ⌥ D")
            }
            Section("Aufnahme") {
                row("Bereich", "⌃ ⌥ ⌘ 4")
                row("Fenster", "⌃ ⌥ ⌘ 5")
                row("Bildschirm", "⌃ ⌥ ⌘ 3")
                row("Text erkennen", "⌃ ⌥ ⌘ T")
            }
            Section("Im Shelf") {
                row("Tabs Clips · Nook · Ablage", "⌘ 1 · 2 · 3")
                row("Vorschau", "Leertaste")
                row("Einfügen", "↩")
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ title: String, _ keys: String) -> some View {
        LabeledContent(title) {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}
