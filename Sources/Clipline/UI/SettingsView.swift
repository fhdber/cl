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

    static let contentSize = CGSize(width: 600, height: 620)

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
            // The content fills whatever the window gives it; the window size is set explicitly below,
            // so the tab controller can't shrink it to the toolbar's width.
            let host = NSHostingController(rootView: view.frame(maxWidth: .infinity, maxHeight: .infinity))
            host.sizingOptions = []
            host.preferredContentSize = Self.contentSize
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

        tabs.preferredContentSize = Self.contentSize
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.setContentSize(Self.contentSize)
        window.contentMinSize = Self.contentSize
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
        SettingsPage {
            SettingsSection {
                SettingsRow(title: "Beim Anmelden starten") { SettingsSwitch(isOn: launchAtLogin) }
            }

            SettingsSection(title: "Verlauf") {
                SettingsRow(title: "Aufbewahren") {
                    Picker("", selection: $historyLimit) {
                        Text("200 Clips").tag(200)
                        Text("1.000 Clips").tag(1000)
                        Text("5.000 Clips").tag(5000)
                        Text("20.000 Clips").tag(20000)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                SettingsDivider()
                SettingsRow(title: "Aufnahme pausieren", subtitle: "Neue Kopien werden nicht gespeichert.") {
                    SettingsSwitch(isOn: $paused)
                }
                SettingsDivider()
                SettingsRow(title: "Gesamten Verlauf löschen", subtitle: "Favoriten und Kategorien bleiben.") {
                    Button("Löschen …", role: .destructive, action: confirmClearHistory)
                }
            }

            SettingsSection(title: "Datenschutz",
                            footer: "Aus diesen Apps wird nichts aufgenommen. Inhalte, die Passwort-Manager als vertraulich markieren, werden immer ignoriert.") {
                ForEach(installedIgnoredApps, id: \.self) { bundleID in
                    HStack(spacing: 10) {
                        if let icon = AppIcons.icon(for: bundleID) {
                            Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                        }
                        Text(appName(for: bundleID)).font(.system(size: 13))
                        Spacer()
                        Button {
                            ignoredAppsRaw = ignoredApps.filter { $0 != bundleID }.joined(separator: ",")
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Entfernen")
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    SettingsDivider()
                }
                HStack {
                    Button("App hinzufügen …", action: addIgnoredApp)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
            }

            SettingsSection(title: "Berechtigungen") {
                SettingsRow(title: "Bedienungshilfen",
                            subtitle: "Damit Clipline für dich einfügen und markierten Text an Claude geben kann.") {
                    if trusted {
                        Label("Erlaubt", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.green)
                    } else {
                        Button("Erlauben …") { Paster.requestAccess() }
                    }
                }
            }
        }
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
        SettingsPage {
            SettingsSection(title: "Shelf",
                            footer: "„Automatisch“ nimmt auf Bildschirmen unter 1600 pt – etwa dem MacBook Pro 14\" – das Mini-Shelf.") {
                SettingsRow(title: "Öffnen, wenn die Maus an die Notch fährt") { SettingsSwitch(isOn: $notchHover) }
                SettingsDivider()
                SettingsRow(title: "Größe") {
                    Picker("", selection: $shelfSize) {
                        Text("Automatisch").tag("auto")
                        Text("Mini").tag("mini")
                        Text("Groß").tag("full")
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                SettingsDivider()
                SettingsRow(title: "Startet mit") {
                    Picker("", selection: $shelfStartTab) {
                        Text("Clips").tag("clips")
                        Text("Nook").tag("nook")
                        Text("Ablage").tag("tray")
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SettingsSection(title: "Nook & Ablage",
                            footer: "Medien funktionieren mit Musik und Spotify. Beim ersten Mal fragt macOS, ob Clipline sie steuern darf.") {
                SettingsRow(title: "Live-Aktivität", subtitle: "Cover und Equalizer an der Notch, wenn Musik läuft.") {
                    SettingsSwitch(isOn: $liveActivity)
                }
                SettingsDivider()
                SettingsRow(title: "Dateien zur Notch ziehen öffnet die Ablage") {
                    SettingsSwitch(isOn: $fileDragOpensTray)
                }
                SettingsDivider()
                SettingsRow(title: "Kurzbefehle im Nook", subtitle: "Namen, durch Komma getrennt.") {
                    TextField("", text: $pinnedShortcuts, prompt: Text("z. B. Fokus, Timer"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
            }
        }
    }
}

// MARK: - Kurzbefehle

struct ShortcutsSettingsView: View {
    var body: some View {
        SettingsPage {
            SettingsSection(title: "Zwischenablage") {
                SettingsRow(title: "Quick Paste") { KeyCaps(keys: "⌃ ⌘ V") }
                SettingsDivider()
                SettingsRow(title: "Shelf") { KeyCaps(keys: "⌥ ⌘ V") }
                SettingsDivider()
                SettingsRow(title: "Bibliothek") { KeyCaps(keys: "⌃ ⌘ L") }
                SettingsDivider()
                SettingsRow(title: "Einen der letzten 10 Clips einfügen") { KeyCaps(keys: "⌃ ⌘ 0 … 9") }
            }
            SettingsSection(title: "Claude & Diktat") {
                SettingsRow(title: "Claude fragen", subtitle: "Mit dem Text, den du gerade markiert hast.") {
                    KeyCaps(keys: "⌃ ⌘ C")
                }
                SettingsDivider()
                SettingsRow(title: "Diktat", subtitle: "Halten und sprechen.") { KeyCaps(keys: "⌃ ⌥ D") }
            }
            SettingsSection(title: "Aufnahme") {
                SettingsRow(title: "Bereich") { KeyCaps(keys: "⌃ ⌥ ⌘ 4") }
                SettingsDivider()
                SettingsRow(title: "Fenster") { KeyCaps(keys: "⌃ ⌥ ⌘ 5") }
                SettingsDivider()
                SettingsRow(title: "Bildschirm") { KeyCaps(keys: "⌃ ⌥ ⌘ 3") }
                SettingsDivider()
                SettingsRow(title: "Text erkennen") { KeyCaps(keys: "⌃ ⌥ ⌘ T") }
            }
            SettingsSection(title: "Im Shelf") {
                SettingsRow(title: "Clips · Nook · Ablage") { KeyCaps(keys: "⌘ 1 · 2 · 3") }
                SettingsDivider()
                SettingsRow(title: "Vorschau") { KeyCaps(keys: "Leertaste") }
                SettingsDivider()
                SettingsRow(title: "Einfügen") { KeyCaps(keys: "↩") }
            }
        }
    }
}
