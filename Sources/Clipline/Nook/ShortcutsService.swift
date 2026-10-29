import Combine
import Foundation

/// Lists and runs the user's Shortcuts via the `shortcuts` command-line tool.
final class ShortcutsService: ObservableObject {
    static let shared = ShortcutsService()

    @Published private(set) var all: [String] = []
    private var loaded = false

    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        DispatchQueue.global(qos: .utility).async {
            let names = Self.shortcuts(["list"])
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            DispatchQueue.main.async { self.all = names }
        }
    }

    /// Pinned in settings, else the first few – what the widget shows as buttons.
    var featured: [String] {
        let pinned = Prefs.pinnedShortcuts.filter { all.isEmpty || all.contains($0) }
        return Array((pinned.isEmpty ? all : pinned).prefix(4))
    }

    func run(_ name: String) {
        DispatchQueue.global(qos: .userInitiated).async { _ = Self.shortcuts(["run", name]) }
    }

    private static func shortcuts(_ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return "" }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
