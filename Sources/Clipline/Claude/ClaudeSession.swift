import AppKit
import Combine
import ImageIO

/// One conversation turn in the Claude panel: a context (text or image), a task, a streamed answer.
final class ClaudeSession: ObservableObject {
    enum Context {
        case text(String, source: String?)
        case image(Data, title: String?)

        var isImage: Bool {
            if case .image = self { return true }
            return false
        }
    }

    @Published var context: Context?
    @Published var prompt = ""
    @Published private(set) var response = ""
    @Published private(set) var isRunning = false
    @Published private(set) var error: String?
    @Published private(set) var lastTask: String?
    @Published var focusToken = 0

    private var task: Task<Void, Never>?

    var actions: [ClaudeAction] {
        context?.isImage == true ? ClaudeAction.imageActions : ClaudeAction.textActions
    }

    func reset(with context: Context?) {
        cancel()
        self.context = context
        prompt = ""
        response = ""
        error = nil
        lastTask = nil
        focusToken += 1
    }

    func run(_ action: ClaudeAction) {
        send(instruction: action.instruction, label: action.title)
    }

    func submit() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        prompt = ""
        send(instruction: text, label: text)
    }

    func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    private func send(instruction: String, label: String) {
        cancel()
        response = ""
        error = nil
        lastTask = label
        isRunning = true

        var parts: [ClaudeClient.Part] = []
        var text: String?
        switch context {
        case .text(let value, _):
            text = value
        case .image(let data, _):
            if let image = ImageEncoding.forClaude(data) { parts.append(.image(image.data, mediaType: image.mediaType)) }
        case nil:
            break
        }
        parts.append(.text(ClaudeAction.prompt(instruction: instruction, text: text)))
        let request = ClaudeClient.Request(system: ClaudeAction.system, parts: parts, effort: Prefs.claudeEffort)

        task = Task { @MainActor [weak self] in
            do {
                for try await event in ClaudeClient.shared.stream(request) {
                    guard let self else { return }
                    switch event {
                    case .text(let delta): self.response += delta
                    case .restart: self.response = ""
                    }
                }
            } catch {
                self?.error = error.localizedDescription
            }
            self?.isRunning = false
        }
    }
}

/// Screenshots can be several MB; Claude reads images up to ~1568 px best, so send a scaled JPEG.
enum ImageEncoding {
    static func forClaude(_ data: Data, maxPixel: Int = 1568) -> (data: Data, mediaType: String)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let jpeg = NSBitmapImageRep(cgImage: cg).representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        else { return nil }
        return (jpeg, "image/jpeg")
    }
}
