import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Claude

/// Holds the key draft and test status outside the view (no @State in this project).
final class ClaudeKeyModel: ObservableObject {
    static let shared = ClaudeKeyModel()

    @Published var draft = ""
    @Published private(set) var status: String?
    @Published private(set) var isTesting = false

    var hasKey: Bool { ClaudeClient.shared.hasKey }

    func save() {
        let key = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        Keychain.write(key, account: ClaudeClient.apiKeyAccount)
        draft = ""
        status = "Gespeichert."
        test()
    }

    func remove() {
        Keychain.write(nil, account: ClaudeClient.apiKeyAccount)
        status = "Schlüssel entfernt."
        objectWillChange.send()
    }

    func test() {
        isTesting = true
        status = "Teste die Verbindung …"
        let request = ClaudeClient.Request(system: "Antworte nur mit: OK", parts: [.text("Test")],
                                           effort: "low", maxTokens: 512)
        Task { @MainActor in
            do {
                _ = try await ClaudeClient.shared.complete(request)
                self.status = "Verbunden mit \(ClaudeModel.preferred.title)."
            } catch {
                self.status = error.localizedDescription
            }
            self.isTesting = false
        }
    }
}

// MARK: - Tray targets

/// Re-renders after the folder/app lists change (they live in plain UserDefaults arrays).
final class TraySettingsModel: ObservableObject {
    static let shared = TraySettingsModel()
    var folders: [String] { Prefs.trayFolders }
    var apps: [String] { Prefs.trayApps }

    func addFolder() {
        guard let path = FolderPicker.choose() else { return }
        Prefs.trayFolders = Array(Set(folders + [path])).sorted()
        objectWillChange.send()
    }

    func addApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Prefs.trayApps = Array(Set(apps + [url.path])).sorted()
        objectWillChange.send()
    }

    func removeFolder(_ path: String) {
        Prefs.trayFolders = folders.filter { $0 != path }
        objectWillChange.send()
    }

    func removeApp(_ path: String) {
        Prefs.trayApps = apps.filter { $0 != path }
        objectWillChange.send()
    }
}

enum FolderPicker {
    static func choose() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path
    }
}

// MARK: - Views

struct ClaudeSettingsView: View {
    @ObservedObject var keys: ClaudeKeyModel
    @AppStorage(Prefs.Key.claudeModel) private var model = "claude-opus-5-5"
    @AppStorage(Prefs.Key.claudeEffort) private var effort = "medium"

    var body: some View {
        SettingsPage {
            SettingsSection(title: "Verbindung",
                            footer: "Den Schlüssel bekommst du in der Claude Console (platform.claude.com) unter „API Keys“. Er bleibt im Schlüsselbund deines Macs und geht nur an api.anthropic.com.") {
                if keys.hasKey {
                    SettingsRow(title: "API-Schlüssel", subtitle: "Im Schlüsselbund gespeichert.") {
                        HStack(spacing: 8) {
                            Button(keys.isTesting ? "Teste …" : "Testen") { keys.test() }
                                .disabled(keys.isTesting)
                            Button("Entfernen", role: .destructive) { keys.remove() }
                        }
                    }
                } else {
                    SettingsRow(title: "API-Schlüssel") {
                        HStack(spacing: 8) {
                            SecureField("", text: Binding(get: { keys.draft }, set: { keys.draft = $0 }),
                                        prompt: Text("sk-ant-…"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                            Button("Sichern") { keys.save() }
                                .disabled(keys.draft.isEmpty)
                        }
                    }
                }
                if let status = keys.status {
                    SettingsDivider()
                    HStack {
                        Text(status).font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 34)
                }
            }

            SettingsSection(title: "Modell") {
                SettingsRow(title: "Modell") {
                    Picker("", selection: $model) {
                        ForEach(ClaudeModel.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                SettingsDivider()
                SettingsRow(title: "Gründlichkeit", subtitle: "Schneller antwortet zügiger, gründlicher denkt länger nach.") {
                    Picker("", selection: $effort) {
                        Text("Schnell").tag("low")
                        Text("Ausgewogen").tag("medium")
                        Text("Gründlich").tag("high")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }

            SettingsSection(title: "So nutzt du Claude",
                            footer: "Rechtsklick auf einen Clip, der ✦-Button im Shelf, die Claude-Kachel in der Ablage oder „Claude“ auf der Screenshot-Karte.") {
                SettingsRow(title: "Markierten Text bearbeiten") { KeyCaps(keys: "⌃ ⌘ C") }
            }
        }
    }
}

struct DictationSettingsView: View {
    @AppStorage(Prefs.Key.dictationEnabled) private var enabled = true
    @AppStorage(Prefs.Key.dictationMode) private var mode = "hold"
    @AppStorage(Prefs.Key.dictationLocale) private var locale = "de-DE"
    @AppStorage(Prefs.Key.dictationPolish) private var polish = true
    @AppStorage(Prefs.Key.dictationStyle) private var style = "neutral"
    @AppStorage(Prefs.Key.dictationModel) private var model = ""

    var body: some View {
        SettingsPage {
            SettingsSection(title: "Diktat",
                            footer: "Der Text landet dort, wo dein Cursor steht. Es wird keine Audiodatei gespeichert; die Erkennung läuft wenn möglich direkt auf dem Mac.") {
                SettingsRow(title: "Diktat", subtitle: "Mit ⌃⌥D in jeder App.") { SettingsSwitch(isOn: $enabled) }
                SettingsDivider()
                SettingsRow(title: "Bedienung") {
                    Picker("", selection: $mode) {
                        Text("Halten").tag("hold")
                        Text("Start / Stopp").tag("toggle")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                SettingsDivider()
                SettingsRow(title: "Sprache") {
                    Picker("", selection: $locale) {
                        Text("Deutsch").tag("de-DE")
                        Text("Deutsch (Schweiz)").tag("de-CH")
                        Text("Deutsch (Österreich)").tag("de-AT")
                        Text("Englisch (US)").tag("en-US")
                        Text("Englisch (UK)").tag("en-GB")
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            SettingsSection(title: "Bereinigen",
                            footer: "Claude entfernt Füllwörter und Versprecher, setzt Satzzeichen und Absätze. Ohne API-Schlüssel wird der Rohtext eingefügt.") {
                SettingsRow(title: "Mit Claude bereinigen") { SettingsSwitch(isOn: $polish) }
                SettingsDivider()
                SettingsRow(title: "Stil") {
                    Picker("", selection: $style) {
                        Text("Wie gesprochen").tag("neutral")
                        Text("Professionell").tag("formal")
                        Text("Locker").tag("casual")
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .disabled(!polish)
                SettingsDivider()
                SettingsRow(title: "Modell") {
                    Picker("", selection: $model) {
                        Text("Wie bei Claude").tag("")
                        ForEach(ClaudeModel.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .disabled(!polish)
            }
        }
    }
}

struct CaptureSettingsView: View {
    @AppStorage(Prefs.Key.captureScreenshots) private var captureScreenshots = true
    @AppStorage(Prefs.Key.ocrEnabled) private var ocrEnabled = true
    @AppStorage(Prefs.Key.captureCopies) private var copies = true
    @AppStorage(Prefs.Key.captureQuickAccess) private var quickAccess = true
    @AppStorage(Prefs.Key.captureSaveFolder) private var saveFolder = "~/Desktop"

    var body: some View {
        SettingsPage {
            SettingsSection(title: "Erfassen", footer: "Gilt auch für Screenshots mit den macOS-Kürzeln ⇧⌘3 und ⇧⌘4.") {
                SettingsRow(title: "Gespeicherte Screenshots übernehmen") { SettingsSwitch(isOn: $captureScreenshots) }
                SettingsDivider()
                SettingsRow(title: "Text in Bildern erkennen", subtitle: "Macht Screenshots durchsuchbar.") {
                    SettingsSwitch(isOn: $ocrEnabled)
                }
            }

            SettingsSection(title: "Nach der Aufnahme") {
                SettingsRow(title: "In die Zwischenablage kopieren") { SettingsSwitch(isOn: $copies) }
                SettingsDivider()
                SettingsRow(title: "Schnellzugriff-Karte zeigen") { SettingsSwitch(isOn: $quickAccess) }
                SettingsDivider()
                SettingsRow(title: "Sichern in", subtitle: (saveFolder as NSString).abbreviatingWithTildeInPath) {
                    Button("Ändern …") {
                        if let path = FolderPicker.choose() { saveFolder = path }
                    }
                }
            }
        }
    }
}

struct TraySettingsView: View {
    @ObservedObject var model: TraySettingsModel = .shared
    @AppStorage(Prefs.Key.revealActionResults) private var reveal = false

    var body: some View {
        SettingsPage {
            SettingsSection(title: "Ordner-Ziele",
                            footer: "Erscheinen als Kachel in der Ablage. Dateien darauf ziehen kopiert sie, mit ⌥ werden sie verschoben.") {
                ForEach(model.folders, id: \.self) { path in
                    row(path) { model.removeFolder(path) }
                    SettingsDivider()
                }
                addRow("Ordner hinzufügen …") { model.addFolder() }
            }
            SettingsSection(title: "App-Ziel") {
                ForEach(model.apps, id: \.self) { path in
                    row(path) { model.removeApp(path) }
                    SettingsDivider()
                }
                addRow("App hinzufügen …") { model.addApp() }
            }
            SettingsSection {
                SettingsRow(title: "Ergebnisse im Finder zeigen", subtitle: "Nach ZIP, Verkleinern und Umwandeln.") {
                    SettingsSwitch(isOn: $reveal)
                }
            }
        }
    }

    private func row(_ path: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 20, height: 20)
            Text(FileManager.default.displayName(atPath: path)).font(.system(size: 13))
            Spacer()
            Button(action: remove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
                .help("Entfernen")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
    }

    private func addRow(_ title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Button(title, action: action)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
    }
}
