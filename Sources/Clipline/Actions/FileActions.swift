import AppKit

/// Dropzone-style file actions. Results are written next to the originals; nothing is overwritten.
enum FileActions {
    private static let queue = DispatchQueue(label: "clipline.fileactions", qos: .userInitiated)
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "tif", "gif", "bmp", "webp"]

    static func zip(_ urls: [URL]) {
        guard let first = urls.first else { return }
        queue.async {
            let folder = first.deletingLastPathComponent()
            let name = urls.count == 1 ? first.deletingPathExtension().lastPathComponent : "Archiv"
            let target = unique(folder.appendingPathComponent("\(name).zip"))
            var ok: Bool
            if urls.count == 1 {
                ok = run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", first.path, target.path])
            } else {
                // Several items: stage them in one folder, then zip its contents.
                let staging = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                ok = (try? FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)) != nil
                for url in urls where ok {
                    ok = (try? FileManager.default.copyItem(at: url, to: staging.appendingPathComponent(url.lastPathComponent))) != nil
                }
                if ok { ok = run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", staging.path, target.path]) }
                try? FileManager.default.removeItem(at: staging)
            }
            finish(ok, success: "ZIP erstellt", failure: "ZIP fehlgeschlagen", reveal: ok ? [target] : [])
        }
    }

    static func resize(_ urls: [URL], maxPixel: Int = 1600) {
        let images = urls.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
        guard !images.isEmpty else { return Toast.show("Keine Bilder dabei", symbol: "photo") }
        queue.async {
            var outputs: [URL] = []
            for url in images {
                let name = "\(url.deletingPathExtension().lastPathComponent) \(maxPixel)px.\(url.pathExtension)"
                let target = unique(url.deletingLastPathComponent().appendingPathComponent(name))
                if run("/usr/bin/sips", ["-Z", "\(maxPixel)", url.path, "--out", target.path]) { outputs.append(target) }
            }
            finish(!outputs.isEmpty, success: "\(outputs.count) verkleinert", failure: "Verkleinern fehlgeschlagen",
                   reveal: outputs)
        }
    }

    static func convert(_ urls: [URL], to format: String) {
        let images = urls.filter { imageExtensions.contains($0.pathExtension.lowercased()) }
        guard !images.isEmpty else { return Toast.show("Keine Bilder dabei", symbol: "photo") }
        let ext = format == "jpeg" ? "jpg" : format
        queue.async {
            var outputs: [URL] = []
            for url in images {
                let target = unique(url.deletingPathExtension().appendingPathExtension(ext))
                if run("/usr/bin/sips", ["-s", "format", format, url.path, "--out", target.path]) { outputs.append(target) }
            }
            finish(!outputs.isEmpty, success: "In \(ext.uppercased()) umgewandelt", failure: "Umwandeln fehlgeschlagen",
                   reveal: outputs)
        }
    }

    /// Copies (or with ⌥ held, moves) into a destination folder.
    static func send(_ urls: [URL], to folder: URL) {
        let move = NSEvent.modifierFlags.contains(.option)
        queue.async {
            var count = 0
            for url in urls {
                let target = unique(folder.appendingPathComponent(url.lastPathComponent))
                do {
                    if move { try FileManager.default.moveItem(at: url, to: target) }
                    else { try FileManager.default.copyItem(at: url, to: target) }
                    count += 1
                } catch {}
            }
            finish(count > 0, success: "\(count) nach \(folder.lastPathComponent) \(move ? "verschoben" : "kopiert")",
                   failure: "Kopieren fehlgeschlagen", reveal: [])
        }
    }

    static func open(_ urls: [URL], withApplicationAt app: URL) {
        NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Helpers

    private static func finish(_ ok: Bool, success: String, failure: String, reveal: [URL]) {
        DispatchQueue.main.async {
            Toast.show(ok ? success : failure, symbol: ok ? "checkmark" : "exclamationmark.triangle")
            if ok && !reveal.isEmpty && Prefs.revealActionResults {
                NSWorkspace.shared.activateFileViewerSelecting(reveal)
            }
        }
    }

    private static func unique(_ url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var counter = 2
        var candidate = url
        repeat {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = url.deletingLastPathComponent().appendingPathComponent(name)
            counter += 1
        } while FileManager.default.fileExists(atPath: candidate.path)
        return candidate
    }

    @discardableResult
    private static func run(_ tool: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
