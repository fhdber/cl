import Foundation

enum ClaudeModel: String, CaseIterable, Identifiable {
    case opus = "claude-opus-5-5"
    case sonnet = "claude-sonnet-5-5"
    case haiku = "claude-haiku-5-5"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .opus: return "Claude Opus 5.5"
        case .sonnet: return "Claude Sonnet 5.5"
        case .haiku: return "Claude Haiku 5.5"
        }
    }

    var shortTitle: String {
        switch self {
        case .opus: return "Opus 5.5"
        case .sonnet: return "Sonnet 5.5"
        case .haiku: return "Haiku 5.5"
        }
    }

    /// Haiku has no server-side refusal fallback.
    var supportsFallback: Bool { self != .haiku }

    static var preferred: ClaudeModel { ClaudeModel(rawValue: Prefs.claudeModel) ?? .opus }
    static var dictation: ClaudeModel { ClaudeModel(rawValue: Prefs.dictationModel) ?? preferred }
}

struct ClaudeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Minimal Messages API client over URLSession (there is no official Swift SDK).
final class ClaudeClient {
    static let shared = ClaudeClient()

    static let apiKeyAccount = "anthropic-api-key"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2026-10-21"
    private static let fallbackBeta = "server-side-fallback-2026-07-01"

    enum Part {
        case text(String)
        case image(Data, mediaType: String)
    }

    struct Request {
        var model: ClaudeModel = .preferred
        var system: String
        var parts: [Part]
        /// low · medium · high – Opus 5.5 defaults to medium.
        var effort = "medium"
        var maxTokens = 16000
    }

    enum Event {
        case text(String)
        /// A refused draft was replaced by the fallback model – drop what streamed so far.
        case restart
    }

    var apiKey: String? { Keychain.read(Self.apiKeyAccount) }
    var hasKey: Bool { !(apiKey ?? "").isEmpty }

    /// Streams the answer as text deltas. Retries rate limits and overloads before any output.
    func stream(_ request: Request) -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let key = apiKey, !key.isEmpty else {
                        throw ClaudeError(message: "Kein API-Schlüssel – trag ihn in den Einstellungen unter „Claude“ ein.")
                    }
                    let urlRequest = try Self.makeURLRequest(request, key: key)
                    var attempt = 0
                    while true {
                        do {
                            try await Self.run(urlRequest, continuation: continuation)
                            break
                        } catch let retry as RetryableError where attempt < 2 {
                            attempt += 1
                            try await Task.sleep(nanoseconds: UInt64(retry.delay * 1_000_000_000))
                        } catch let retry as RetryableError {
                            throw ClaudeError(message: retry.message)
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as URLError where error.code == .cancelled {
                    continuation.finish()
                } catch let error as URLError {
                    continuation.finish(throwing: ClaudeError(message: "Keine Verbindung zu Claude (\(error.localizedDescription))."))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Whole answer at once.
    func complete(_ request: Request) async throws -> String {
        var text = ""
        for try await event in stream(request) {
            switch event {
            case .text(let delta): text += delta
            case .restart: text = ""
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - HTTP

    private struct RetryableError: Error {
        let delay: Double
        let message: String
    }

    private static func makeURLRequest(_ request: Request, key: String) throws -> URLRequest {
        // Images before text, as the API recommends.
        var content: [[String: Any]] = []
        for part in request.parts {
            if case .image(let data, let mediaType) = part {
                content.append([
                    "type": "image",
                    "source": ["type": "base64", "media_type": mediaType, "data": data.base64EncodedString()],
                ])
            }
        }
        for part in request.parts {
            if case .text(let text) = part { content.append(["type": "text", "text": text]) }
        }

        var body: [String: Any] = [
            "model": request.model.rawValue,
            "max_tokens": request.maxTokens,
            "stream": true,
            "system": request.system,
            "messages": [["role": "user", "content": content]],
            "output_config": ["effort": request.effort],
        ]
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 300
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(key, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        if request.model.supportsFallback {
            // On a safety decline the API re-runs the request on Anthropic's recommended model.
            body["fallbacks"] = "default"
            urlRequest.setValue(fallbackBeta, forHTTPHeaderField: "anthropic-beta")
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlRequest
    }

    private static func run(_ request: URLRequest,
                            continuation: AsyncThrowingStream<Event, Error>.Continuation) async throws {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError(message: "Unerwartete Antwort von Claude.")
        }
        guard http.statusCode == 200 else {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            throw failure(status: http.statusCode, body: data,
                          retryAfter: http.value(forHTTPHeaderField: "retry-after"))
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = payload.data(using: .utf8),
                  let event = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            switch type {
            case "content_block_start":
                if let block = event["content_block"] as? [String: Any], block["type"] as? String == "fallback" {
                    continuation.yield(.restart)
                }
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    continuation.yield(.text(text))
                }
            case "message_delta":
                if let delta = event["delta"] as? [String: Any], delta["stop_reason"] as? String == "refusal" {
                    throw ClaudeError(message: "Claude hat diese Anfrage abgelehnt.")
                }
            case "error":
                let error = event["error"] as? [String: Any]
                if error?["type"] as? String == "overloaded_error" {
                    throw RetryableError(delay: 2, message: "Claude ist gerade überlastet – versuch es gleich noch einmal.")
                }
                throw ClaudeError(message: (error?["message"] as? String) ?? "Claude hat einen Fehler gemeldet.")
            default:
                break
            }
        }
    }

    private static func failure(status: Int, body: Data, retryAfter: String?) -> Error {
        let apiMessage = ((try? JSONSerialization.jsonObject(with: body)) as? [String: Any])
            .flatMap { $0["error"] as? [String: Any] }?["message"] as? String
        let delay = retryAfter.flatMap { Double($0) } ?? 2
        switch status {
        case 401: return ClaudeError(message: "Der API-Schlüssel wird nicht akzeptiert. Prüf ihn in den Einstellungen.")
        case 403: return ClaudeError(message: "Dieser API-Schlüssel darf das Modell nicht nutzen.")
        case 429: return RetryableError(delay: delay, message: "Zu viele Anfragen – warte kurz und versuch es noch einmal.")
        case 529: return RetryableError(delay: delay, message: "Claude ist gerade überlastet – versuch es gleich noch einmal.")
        case 500...599: return RetryableError(delay: delay, message: "Claude ist gerade nicht erreichbar (\(status)).")
        default: return ClaudeError(message: apiMessage ?? "Anfrage fehlgeschlagen (\(status)).")
        }
    }
}
