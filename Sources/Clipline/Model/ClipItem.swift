import Foundation
import SwiftUI

enum ClipKind: String, Codable, CaseIterable, Identifiable {
    case text, link, code, color, image, screenshot, file

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .code: return "Code"
        case .color: return "Farbe"
        case .image: return "Bild"
        case .screenshot: return "Screenshot"
        case .file: return "Datei"
        }
    }

    var pluralTitle: String {
        switch self {
        case .text: return "Text"
        case .link: return "Links"
        case .code: return "Code"
        case .color: return "Farben"
        case .image: return "Bilder"
        case .screenshot: return "Screenshots"
        case .file: return "Dateien"
        }
    }

    var symbol: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette"
        case .image: return "photo"
        case .screenshot: return "camera.viewfinder"
        case .file: return "doc"
        }
    }

    var tint: Color {
        switch self {
        case .text: return Color(white: 0.75)
        case .link: return Color(red: 0.40, green: 0.62, blue: 1.00)
        case .code: return Color(red: 0.35, green: 0.85, blue: 0.70)
        case .color: return Color(red: 1.00, green: 0.45, blue: 0.65)
        case .image: return Color(red: 1.00, green: 0.66, blue: 0.30)
        case .screenshot: return Color(red: 0.70, green: 0.55, blue: 1.00)
        case .file: return Color(red: 0.45, green: 0.80, blue: 0.95)
        }
    }

    /// Kinds whose payload lives in `text`.
    var isTextual: Bool { [.text, .link, .code, .color].contains(self) }
}

struct ClipItem: Codable, Identifiable, Equatable {
    let id: UUID
    var kind: ClipKind
    var createdAt: Date
    var text: String?
    var imageFile: String?
    var imageSize: CGSize?
    var fileURLs: [URL]?
    var sourceAppName: String?
    var sourceBundleID: String?
    var ocrText: String?
    var pinned: Bool
    var collection: String?
    var contentHash: String

    init(kind: ClipKind,
         text: String? = nil,
         imageFile: String? = nil,
         imageSize: CGSize? = nil,
         fileURLs: [URL]? = nil,
         sourceAppName: String?,
         sourceBundleID: String?,
         contentHash: String) {
        self.id = UUID()
        self.kind = kind
        self.createdAt = Date()
        self.text = text
        self.imageFile = imageFile
        self.imageSize = imageSize
        self.fileURLs = fileURLs
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.ocrText = nil
        self.pinned = false
        self.collection = nil
        self.contentHash = contentHash
    }

    /// Everything the search field matches against, including OCR text from images.
    var searchText: String {
        [
            text,
            ocrText,
            fileURLs?.map(\.lastPathComponent).joined(separator: " "),
            sourceAppName,
            collection,
            kind.title,
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    var menuTitle: String {
        switch kind {
        case .image, .screenshot:
            return imageSize.map { "\(kind.title) · \(Int($0.width))×\(Int($0.height))" } ?? kind.title
        case .file:
            return fileURLs?.first?.lastPathComponent ?? kind.title
        default:
            let line = (text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines).first ?? ""
            return line.count > 48 ? String(line.prefix(48)) + "…" : line
        }
    }

    /// Short meta line shown at the bottom of a card.
    var meta: String {
        switch kind {
        case .text, .code:
            let count = text?.count ?? 0
            return "\(count.formatted()) Zeichen"
        case .link:
            return URL(string: text ?? "")?.host ?? "Link"
        case .color:
            return "Farbe"
        case .image, .screenshot:
            guard let size = imageSize else { return kind.title }
            return "\(Int(size.width)) × \(Int(size.height))"
        case .file:
            let count = fileURLs?.count ?? 0
            return count == 1 ? "1 Datei" : "\(count) Dateien"
        }
    }
}
