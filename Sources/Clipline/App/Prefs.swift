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
            Key.ignoredApps: defaultIgnoredApps,
        ])
    }

    static var historyLimit: Int { defaults.integer(forKey: Key.historyLimit) }
    static var captureScreenshots: Bool { defaults.bool(forKey: Key.captureScreenshots) }
    static var ocrEnabled: Bool { defaults.bool(forKey: Key.ocrEnabled) }
    static var notchHover: Bool { defaults.bool(forKey: Key.notchHover) }
    /// "auto", "mini" or "full"
    static var shelfSize: String { defaults.string(forKey: Key.shelfSize) ?? "auto" }

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
