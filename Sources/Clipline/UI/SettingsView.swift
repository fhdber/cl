import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// Re-renders the settings when values outside SwiftUI change (login item, Accessibility).
final class SettingsRefresher: ObservableObject {
    func refresh() { objectWillChange.send() }
}

struct SettingsView: View {
    let store: ClipStore
    @ObservedObject var refresher: SettingsRefresher

    @AppStorage(Prefs.Key.historyLimit) private var historyLimit = 1000
    @AppStorage(Prefs.Key.captureScreenshots) private var captureScreenshots = true
    @AppStorage(Prefs.Key.ocrEnabled) private var ocrEnabled = true
    @AppStorage(Prefs.Key.ignoredApps) private var ignoredAppsRaw = Prefs.defaultIgnoredApps

    var body: some View {
        Form {
            Section("Allgemein") {
                Toggle("Beim Anmelden starten", isOn: launchAtLogin)
                LabeledContent("Verlauf öffnen") { KeyHint(text: "⌃ ⌘ V") }
                Picker("Verlauf behalten", selection: $historyLimit) {
                    Text("200 Clips").tag(200)
                    Text("1.000 Clips").tag(1000)
                    Text("5.000 Clips").tag(5000)
                    Text("20.000 Clips").tag(20000)
                }
            }

            Section("Erfassen") {
                Toggle("Gespeicherte Screenshots übernehmen", isOn: $captureScreenshots)
                Toggle("Text in Bildern erkennen (OCR)", isOn: $ocrEnabled)
            }

            Section {
                ForEach(ignoredApps, id: \.self) { bundleID in
                    HStack {
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
                Text("Nie aufnehmen aus")
            } footer: {
                Text("Inhalte, die Passwort-Manager als vertraulich markieren, werden immer ignoriert.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Bedienungshilfen") {
                HStack {
                    Label(trusted ? "Auto-Einfügen aktiv" : "Nur Kopieren – ⌘V drückst du selbst",
                          systemImage: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle")
                        .foregroundStyle(trusted ? Color.green : Color.orange)
                    Spacer()
                    if !trusted {
                        Button("Zugriff erlauben") { Paster.requestAccess() }
                    }
                }
            }

            Section {
                Button("Verlauf löschen", role: .destructive, action: confirmClearHistory)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 600)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresher.refresh()
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
        alert.informativeText = "Angeheftete Clips und Sammlungen bleiben erhalten."
        alert.addButton(withTitle: "Löschen")
        alert.addButton(withTitle: "Abbrechen")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn { store.clearHistory() }
    }

    private var ignoredApps: [String] { Prefs.split(ignoredAppsRaw) }

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
