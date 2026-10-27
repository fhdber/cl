import Foundation
import Vision

/// On-device OCR so text inside screenshots and images becomes searchable.
enum TextRecognizer {
    static func recognize(imageAt url: URL, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["de-DE", "en-US"]
            try? VNImageRequestHandler(url: url).perform([request])
            let text = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            DispatchQueue.main.async { completion(text.isEmpty ? nil : text) }
        }
    }
}
