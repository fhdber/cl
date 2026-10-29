import AppKit
import AVFoundation
import Combine
import Speech

/// Wispr-Flow-style dictation: hold the shortcut, speak, let go – the (Claude-polished) text is
/// typed into whatever app you're in.
final class Dictation: ObservableObject {
    static let shared = Dictation()

    enum State: Equatable { case idle, listening, polishing }

    @Published private(set) var state: State = .idle
    @Published private(set) var transcript = ""
    /// Recent input levels 0…1 for the waveform.
    @Published private(set) var levels: [CGFloat] = Array(repeating: 0, count: 24)
    @Published private(set) var message: String?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var delivered = false
    private var wantsStop = false

    // MARK: - Control

    func toggle() {
        state == .idle ? start() : stop()
    }

    func start() {
        guard state == .idle else { return }
        wantsStop = false
        message = nil
        Self.requestPermissions { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.flash("Mikrofon oder Spracherkennung nicht erlaubt")
                return
            }
            // Released before the permission prompts were answered – nothing to record.
            guard !self.wantsStop else { return }
            self.begin()
        }
    }

    func stop() {
        wantsStop = true
        guard state == .listening else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        state = .polishing
        // The final result usually follows endAudio within a moment; don't wait forever.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.deliver() }
    }

    // MARK: - Recording

    private func begin() {
        let locale = Locale(identifier: Prefs.dictationLocale)
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            flash("Spracherkennung für \(locale.identifier) nicht verfügbar")
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let level = Self.level(of: buffer)
            DispatchQueue.main.async { self?.push(level) }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            flash("Mikrofon lässt sich nicht starten")
            return
        }

        transcript = ""
        delivered = false
        state = .listening
        recognition = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self.deliver() }
                } else if error != nil, self.state == .polishing {
                    self.deliver()
                }
            }
        }
    }

    private func push(_ level: CGFloat) {
        levels.removeFirst()
        levels.append(level)
    }

    private static func level(of buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let samples = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<count { sum += samples[index] * samples[index] }
        let rms = sqrt(sum / Float(count))
        // Speech sits roughly between -50 dB and -10 dB.
        let db = 20 * log10(max(rms, 0.000_01))
        return CGFloat(min(1, max(0, (db + 50) / 40)))
    }

    // MARK: - Delivery

    private func deliver() {
        guard state == .polishing, !delivered else { return }
        delivered = true
        recognition?.cancel()
        recognition = nil
        request = nil

        let raw = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            state = .idle
            return
        }
        guard Prefs.dictationPolish, ClaudeClient.shared.hasKey else {
            insert(raw)
            return
        }
        Task { @MainActor in
            let polished = try? await ClaudeClient.shared.complete(Self.polishRequest(for: raw))
            self.insert((polished?.isEmpty == false ? polished : nil) ?? raw)
        }
    }

    /// Puts the text on the clipboard and presses ⌘V in the frontmost app. It also becomes a clip.
    private func insert(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        Paster.sendPasteKeystroke()
        state = .idle
        if !Paster.isTrusted { flash("In der Zwischenablage – ⌘V zum Einfügen") }
    }

    private func flash(_ text: String) {
        state = .idle
        message = text
        Toast.show(text, symbol: "mic.slash")
    }

    private static func polishRequest(for transcript: String) -> ClaudeClient.Request {
        let style: String
        switch Prefs.dictationStyle {
        case "formal": style = "Formuliere klar und professionell."
        case "casual": style = "Behalte einen lockeren, persönlichen Ton."
        default: style = "Behalte Ton und Wortwahl des Sprechers bei."
        }
        let system = """
        Du bereinigst gesprochene Diktate, bevor sie in eine App eingefügt werden. \
        Entferne Füllwörter (äh, ähm, also, halt, sozusagen), Wiederholungen und Versprecher. \
        Bei Selbstkorrekturen („nein, ich meine …“) behalte nur die korrigierte Fassung. \
        Setze Satzzeichen und sinnvolle Absätze, mach aus aufgezählten Punkten eine Liste. \
        \(style) Füge nichts hinzu, beantworte keine Fragen aus dem Diktat und übersetze nicht. \
        Antworte ausschließlich mit dem bereinigten Text.
        """
        return ClaudeClient.Request(model: .dictation, system: system,
                                    parts: [.text("<diktat>\n\(transcript)\n</diktat>")],
                                    effort: "low", maxTokens: 4000)
    }

    // MARK: - Permissions

    private static func requestPermissions(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }
}
