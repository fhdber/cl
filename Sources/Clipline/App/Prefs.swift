import Foundation

/// Central place for user settings. Views bind to the same keys via @AppStorage.
enum Prefs {
    enum Key {
        static let historyLimit = "historyLimit"
        static let captureScreenshots = "captureScreenshots"
        static let ocrEnabled = "ocrEnabled"
        static let paused = "paused"
        static let notchHover = "notchHover"
        static let shelfSize = "shelfSize"
        static let shelfStartTab = "shelfStartTab"
        static let nookSecondary = "nookSecondary"
        static let liveActivity = "liveActivity"
        static let fileDragOpensTray = "fileDragOpensTray"
        static let pinnedShortcuts = "pinnedShortcuts"
        static let trayFiles = "trayFiles"
        static let claudeModel = "claudeModel"
        static let claudeEffort = "claudeEffort"
        static let dictationModel = "dictationModel"
        static let dictationEnabled = "dictationEnabled"
        static let dictationMode = "dictationMode"
        static let dictationLocale = "dictationLocale"
        static let dictationPolish = "dictationPolish"
        static let dictationStyle = "dictationStyle"
        static let captureCopies = "captureCopies"
        static let captureQuickAccess = "captureQuickAccess"
        static let captureSaveFolder = "captureSaveFolder"
        static let trayFolders = "trayFolders"
        static let trayApps = "trayApps"
        static let revealActionResults = "revealActionResults"
        static let ignoredApps = "ignoredApps"
        static let didPromptAccessibility = "didPromptAccessibility"
    }

    /// Password managers and keychain apps are never recorded.
    static let defaultIgnoredApps = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
    ].joined(separator: ",")

    private static var defaults: UserDefaults { .standard }

    static func register() {
        defaults.register(defaults: [
            Key.historyLimit: 1000,
            Key.captureScreenshots: true,
            Key.ocrEnabled: true,
            Key.paused: false,
            Key.notchHover: true,
            Key.shelfSize: "auto",
            Key.shelfStartTab: "clips",
            Key.liveActivity: true,
            Key.fileDragOpensTray: true,
            Key.pinnedShortcuts: "",
            Key.claudeModel: "claude-opus-5-5",
            Key.claudeEffort: "medium",
            Key.dictationModel: "",
            Key.dictationEnabled: true,
            Key.dictationMode: "hold",
            Key.dictationLocale: "de-DE",
            Key.dictationPolish: true,
            Key.dictationStyle: "neutral",
            Key.captureCopies: true,
            Key.captureQuickAccess: true,
            Key.captureSaveFolder: "~/Desktop",
            Key.revealActionResults: false,
            Key.ignoredApps: defaultIgnoredApps,
        ])
    }

    static var historyLimit: Int { defaults.integer(forKey: Key.historyLimit) }
    static var captureScreenshots: Bool { defaults.bool(forKey: Key.captureScreenshots) }
    static var ocrEnabled: Bool { defaults.bool(forKey: Key.ocrEnabled) }
    static var notchHover: Bool { defaults.bool(forKey: Key.notchHover) }
    /// "auto", "mini" or "full"
    static var shelfSize: String { defaults.string(forKey: Key.shelfSize) ?? "auto" }
    static var shelfStartTab: String { defaults.string(forKey: Key.shelfStartTab) ?? "clips" }
    static var liveActivity: Bool { defaults.bool(forKey: Key.liveActivity) }
    static var fileDragOpensTray: Bool { defaults.bool(forKey: Key.fileDragOpensTray) }
    static var pinnedShortcuts: [String] { split(defaults.string(forKey: Key.pinnedShortcuts) ?? "") }
    static var claudeModel: String { defaults.string(forKey: Key.claudeModel) ?? "claude-opus-5-5" }
    static var claudeEffort: String { defaults.string(forKey: Key.claudeEffort) ?? "medium" }
    /// Empty means "same model as Claude".
    static var dictationModel: String { defaults.string(forKey: Key.dictationModel) ?? "" }
    static var dictationEnabled: Bool { defaults.bool(forKey: Key.dictationEnabled) }
    /// "hold" (push-to-talk) or "toggle"
    static var dictationMode: String { defaults.string(forKey: Key.dictationMode) ?? "hold" }
    static var dictationLocale: String { defaults.string(forKey: Key.dictationLocale) ?? "de-DE" }
    static var dictationPolish: Bool { defaults.bool(forKey: Key.dictationPolish) }
    static var dictationStyle: String { defaults.string(forKey: Key.dictationStyle) ?? "neutral" }
    static var captureCopies: Bool { defaults.bool(forKey: Key.captureCopies) }
    static var captureQuickAccess: Bool { defaults.bool(forKey: Key.captureQuickAccess) }
    static var captureSaveFolder: String { defaults.string(forKey: Key.captureSaveFolder) ?? "~/Desktop" }
    static var revealActionResults: Bool { defaults.bool(forKey: Key.revealActionResults) }

    /// Destination folders and apps for the tray's action tiles.
    static var trayFolders: [String] {
        get { defaults.stringArray(forKey: Key.trayFolders) ?? [] }
        set { defaults.set(newValue, forKey: Key.trayFolders) }
    }

    static var trayApps: [String] {
        get { defaults.stringArray(forKey: Key.trayApps) ?? [] }
        set { defaults.set(newValue, forKey: Key.trayApps) }
    }

    static var paused: Bool {
        get { defaults.bool(forKey: Key.paused) }
        set { defaults.set(newValue, forKey: Key.paused) }
    }

    static var ignoredApps: [String] {
        get { split(defaults.string(forKey: Key.ignoredApps) ?? "") }
        set { defaults.set(newValue.joined(separator: ","), forKey: Key.ignoredApps) }
    }

    static func split(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
