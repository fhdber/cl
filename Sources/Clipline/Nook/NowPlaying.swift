import AppKit
import Combine

/// What's playing in Music or Spotify, read and controlled via AppleScript.
/// (The private MediaRemote framework that covers every player is closed to third-party apps
/// since macOS 15.4, so we talk to the two big players directly.)
final class NowPlaying: ObservableObject {
    static let shared = NowPlaying()

    enum Source: String {
        case music = "Music"
        case spotify = "Spotify"

        var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
    }

    struct Track: Equatable {
        var title: String
        var artist: String
        var album: String
        var duration: Double
    }

    @Published private(set) var source: Source?
    @Published private(set) var track: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var artwork: NSImage?

    private let queue = DispatchQueue(label: "clipline.nowplaying")
    private var timer: Timer?
    private var consumers = 0
    private var artworkKey: String?
    private static let separator = "|~|"

    // MARK: - Polling

    /// Each consumer (open nook, live activity) calls start/stop; polling runs while anyone listens.
    func start() {
        consumers += 1
        guard timer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        consumers = max(0, consumers - 1)
        guard consumers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        // Only ask apps that are already running – never launch a player by querying it.
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let candidates = [Source.spotify, .music].filter { running.contains($0.bundleID) }
        guard !candidates.isEmpty else {
            apply(nil)
            return
        }
        queue.async {
            var best: (Source, [String])?
            for source in candidates {
                guard let fields = Self.query(source) else { continue }
                if fields.first == "playing" { best = (source, fields); break }
                if best == nil { best = (source, fields) }
            }
            let result = best
            DispatchQueue.main.async { self.apply(result) }
        }
    }

    private func apply(_ result: (Source, [String])?) {
        guard let result, result.1.count >= 6 else {
            if track != nil { track = nil }
            if isPlaying { isPlaying = false }
            if self.source != nil { self.source = nil }
            if artwork != nil { artwork = nil }
            artworkKey = nil
            return
        }
        let (source, fields) = result
        let duration = Self.number(fields[5]) / (source == .spotify ? 1000 : 1)
        let newTrack = Track(title: fields[1], artist: fields[2], album: fields[3], duration: duration)
        if track != newTrack { track = newTrack }
        if self.source != source { self.source = source }
        let playing = fields[0] == "playing"
        if isPlaying != playing { isPlaying = playing }
        // Publish only real changes – every assignment would redraw all observers.
        let newPosition = Self.number(fields[4])
        if abs(newPosition - position) >= 0.5 { position = newPosition }

        let key = "\(source.rawValue)|\(newTrack.title)|\(newTrack.artist)|\(newTrack.album)"
        if key != artworkKey {
            artworkKey = key
            artwork = nil
            loadArtwork(for: source, artworkURL: fields.count > 6 ? fields[6] : nil, key: key)
        }
    }

    // MARK: - Commands

    func playPause() { command("playpause") }
    func next() { command("next track") }
    func previous() { command("previous track") }

    private func command(_ verb: String) {
        guard let source else { return }
        queue.async {
            _ = Self.run("tell application \"\(source.rawValue)\" to \(verb)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.refresh() }
        }
    }

    // MARK: - AppleScript

    private static func query(_ source: Source) -> [String]? {
        let sep = separator
        let script: String
        switch source {
        case .music:
            script = """
            tell application "Music"
                if player state is stopped then return "stopped"
                set t to current track
                return (player state as text) & "\(sep)" & (name of t) & "\(sep)" & (artist of t) & "\(sep)" & (album of t) & "\(sep)" & (player position as text) & "\(sep)" & (duration of t as text)
            end tell
            """
        case .spotify:
            script = """
            tell application "Spotify"
                if player state is stopped then return "stopped"
                set t to current track
                return (player state as text) & "\(sep)" & (name of t) & "\(sep)" & (artist of t) & "\(sep)" & (album of t) & "\(sep)" & (player position as text) & "\(sep)" & (duration of t as text) & "\(sep)" & (artwork url of t)
            end tell
            """
        }
        guard let output = run(script)?.stringValue, output != "stopped" else { return nil }
        return output.components(separatedBy: sep)
    }

    @discardableResult
    private static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        return NSAppleScript(source: source)?.executeAndReturnError(&error)
    }

    /// AppleScript formats reals with the system locale ("12,5" in German).
    private static func number(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private func loadArtwork(for source: Source, artworkURL: String?, key: String) {
        switch source {
        case .spotify:
            guard let artworkURL, let url = URL(string: artworkURL) else { return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data, let image = NSImage(data: data) else { return }
                DispatchQueue.main.async { if self.artworkKey == key { self.artwork = image } }
            }.resume()
        case .music:
            queue.async {
                let descriptor = Self.run("tell application \"Music\" to get raw data of artwork 1 of current track")
                    ?? Self.run("tell application \"Music\" to get data of artwork 1 of current track")
                guard let data = descriptor?.data, let image = NSImage(data: data) else { return }
                DispatchQueue.main.async { if self.artworkKey == key { self.artwork = image } }
            }
        }
    }
}
