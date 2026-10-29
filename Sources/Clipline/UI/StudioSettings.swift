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

struct ClaudeSettingsView: View {
    @ObservedObject var keys: ClaudeKeyModel
    @AppStorage(Prefs.Key.claudeModel) private var model = "claude-opus-5-5"
    @AppStorage(Prefs.Key.claudeEffort) private var effort = "medium"

    var body: some View {
        Form {
            Section {
                if keys.hasKey {
                    LabeledContent("API-Schlüssel") {
                        HStack {
                            Text("•••••••• im Schlüsselbund").foregroundStyle(.secondary)
                            Button("Entfernen", role: .destructive) { keys.remove() }
                        }
                    }
                } else {
                    SecureField("API-Schlüssel", text: Binding(get: { keys.draft }, set: { keys.draft = $0 }),
                                prompt: Text("sk-ant-…"))
                    Button("Speichern") { keys.save() }
                        .disabled(keys.draft.isEmpty)
                }
                if keys.hasKey {
                    Button(keys.isTesting ? "Teste …" : "Verbindung testen") { keys.test() }
                        .disabled(keys.isTesting)
                }
                if let status = keys.status {
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text("Verbindung")
            } footer: {
                Text("Einen Schlüssel bekommst du in der Claude Console (platform.claude.com) unter „API Keys“. Er bleibt im Schlüsselbund deines Macs; Clipline schickt ihn nur an api.anthropic.com.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Modell") {
                Picker("Modell", selection: $model) {
                    ForEach(ClaudeModel.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                Picker("Gründlichkeit", selection: $effort) {
                    Text("Schnell").tag("low")
                    Text("Ausgewogen").tag("medium")
                    Text("Gründlich").tag("high")
                }
            }

            Section {
                Text("⌃⌘C mit markiertem Text, Rechtsklick auf einen Clip, der ✦-Button im Shelf, die Claude-Kachel in der Ablage oder „Claude“ auf der Screenshot-Karte.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("So nutzt du Claude")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Dictation

struct DictationSettingsView: View {
    @AppStorage(Prefs.Key.dictationEnabled) private var enabled = true
    @AppStorage(Prefs.Key.dictationMode) private var mode = "hold"
    @AppStorage(Prefs.Key.dictationLocale) private var locale = "de-DE"
    @AppStorage(Prefs.Key.dictationPolish) private var polish = true
    @AppStorage(Prefs.Key.dictationStyle) private var style = "neutral"
    @AppStorage(Prefs.Key.dictationModel) private var model = ""

    var body: some View {
        Form {
            Section {
                Toggle("Diktat mit ⌃⌥D", isOn: $enabled)
                Picker("Bedienung", selection: $mode) {
                    Text("Gedrückt halten zum Sprechen").tag("hold")
                    Text("Einmal drücken: Start / Stopp").tag("toggle")
                }
                Picker("Sprache", selection: $locale) {
                    Text("Deutsch").tag("de-DE")
                    Text("Deutsch (Schweiz)").tag("de-CH")
                    Text("Deutsch (Österreich)").tag("de-AT")
                    Text("Englisch (US)").tag("en-US")
                    Text("Englisch (UK)").tag("en-GB")
                }
            } header: {
                Text("Diktat")
            } footer: {
                Text("Sprich in jeder App – der Text wird dort eingefügt, wo dein Cursor steht. Die Erkennung läuft wenn möglich direkt auf dem Mac.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Mit Claude bereinigen", isOn: $polish)
                Picker("Stil", selection: $style) {
                    Text("Wie gesprochen").tag("neutral")
                    Text("Professionell").tag("formal")
                    Text("Locker").tag("casual")
                }
                .disabled(!polish)
                Picker("Modell", selection: $model) {
                    Text("Wie in „Claude“").tag("")
                    ForEach(ClaudeModel.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                .disabled(!polish)
            } header: {
                Text("Bereinigen")
            } footer: {
                Text("Claude entfernt Füllwörter und Versprecher, setzt Satzzeichen und Absätze. Ohne API-Schlüssel wird der Rohtext eingefügt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Capture

struct CaptureSettingsView: View {
    @AppStorage(Prefs.Key.captureScreenshots) private var captureScreenshots = true
    @AppStorage(Prefs.Key.ocrEnabled) private var ocrEnabled = true
    @AppStorage(Prefs.Key.captureCopies) private var copies = true
    @AppStorage(Prefs.Key.captureQuickAccess) private var quickAccess = true
    @AppStorage(Prefs.Key.captureSaveFolder) private var saveFolder = "~/Desktop"

    var body: some View {
        Form {
            Section("Nach der Aufnahme") {
                Toggle("In die Zwischenablage kopieren", isOn: $copies)
                Toggle("Schnellzugriff-Karte zeigen", isOn: $quickAccess)
                LabeledContent("Sichern in") {
                    HStack {
                        Text((saveFolder as NSString).abbreviatingWithTildeInPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Button("Ändern …") {
                            if let path = FolderPicker.choose() { saveFolder = path }
                        }
                    }
                }
            }
            Section {
                Toggle("Gespeicherte Screenshots in den Verlauf übernehmen", isOn: $captureScreenshots)
                Toggle("Text in Bildern erkennen (OCR)", isOn: $ocrEnabled)
            } header: {
                Text("Erfassen")
            } footer: {
                Text("Gilt auch für Screenshots mit den macOS-Kürzeln ⇧⌘3 und ⇧⌘4.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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

struct TraySettingsView: View {
    @ObservedObject var model: TraySettingsModel = .shared
    @AppStorage(Prefs.Key.revealActionResults) private var reveal = false

    var body: some View {
        Form {
            Section {
                ForEach(model.folders, id: \.self) { path in
                    row(path) { model.removeFolder(path) }
                }
                Button("Ordner hinzufügen …") { model.addFolder() }
            } header: {
                Text("Ordner-Ziele")
            } footer: {
                Text("Erscheinen als Kachel in der Ablage. Dateien darauf ziehen kopiert sie, mit ⌥ werden sie verschoben.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("App-Ziel") {
                ForEach(model.apps, id: \.self) { path in
                    row(path) { model.removeApp(path) }
                }
                Button("App hinzufügen …") { model.addApp() }
            }
            Section {
                Toggle("Ergebnisse im Finder zeigen (ZIP, Verkleinern, Umwandeln)", isOn: $reveal)
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ path: String, remove: @escaping () -> Void) -> some View {
        HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 18, height: 18)
            Text(FileManager.default.displayName(atPath: path))
            Spacer()
            Button(action: remove) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
        }
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
