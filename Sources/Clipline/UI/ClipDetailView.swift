import AppKit
import SwiftUI

/// Large preview below the shelf (eye button / space bar): info chips on top, content below.
struct ClipDetailView: View {
    let item: ClipItem
    let model: PanelModel
    let store: ClipStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            if let url = revealURL {
                RoundButton(symbol: "folder", diameter: 28, help: "Im Finder zeigen") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            InfoChip(symbol: item.kind.symbol, text: item.kind.title, prominent: true)
            ForEach(infoChips, id: \.self) { text in
                InfoChip(symbol: nil, text: text, prominent: false)
            }
            Spacer(minLength: 8)
            Button { model.copy([item]) } label: {
                Label("Kopieren", systemImage: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule().fill(Theme.control))
            }
            .buttonStyle(.plain)
            RoundButton(symbol: item.pinned ? "star.fill" : "star", diameter: 28, help: "Favorit") {
                store.togglePin([item.id])
            }
            RoundButton(symbol: "xmark", diameter: 28, help: "Schließen (Leertaste)") {
                model.previewID = nil
            }
        }
    }

    private var revealURL: URL? {
        if let file = item.fileURLs?.first { return file }
        return item.kind == .link ? nil : store.imageURL(for: item)
    }

    private var infoChips: [String] {
        switch item.kind {
        case .text, .code:
            let text = item.text ?? ""
            let words = text.split { $0.isWhitespace || $0.isNewline }.count
            return ["\(text.count.formatted()) Zeichen", "\(words.formatted()) Wörter"]
        case .image, .screenshot:
            var chips: [String] = []
            if let size = item.imageSize { chips.append("\(Int(size.width)) × \(Int(size.height))") }
            if let bytes = store.fileSizeText(for: item) { chips.append(bytes) }
            return chips
        case .link:
            return [URL(string: item.text ?? "")?.host ?? "Link"]
        case .file:
            let count = item.fileURLs?.count ?? 0
            return [count == 1 ? "1 Datei" : "\(count) Dateien"]
        case .color:
            return []
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text, .code:
            ScrollView {
                Text(item.text ?? "")
                    .font(item.kind == .code ? .system(size: 12, design: .monospaced) : .system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(.white.opacity(0.92))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .color:
            ColorDetail(text: item.text ?? "")

        case .image, .screenshot:
            HStack(alignment: .top, spacing: 14) {
                previewImage
                if let ocr = item.ocrText {
                    RecognizedText(text: ocr) { model.copyText(ocr) }
                        .frame(width: 220)
                }
            }

        case .link:
            VStack(alignment: .leading, spacing: 10) {
                if item.imageFile != nil { previewImage }
                if let title = item.title {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
                Button {
                    if let url = URL(string: item.text ?? "") { NSWorkspace.shared.open(url) }
                } label: {
                    Text(item.text ?? "").font(.system(size: 13)).foregroundStyle(Theme.selection)
                }
                .buttonStyle(.plain)
            }

        case .file:
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(item.fileURLs ?? [], id: \.self) { url in
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable().frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent).font(.system(size: 13, weight: .medium))
                                Text(url.deletingLastPathComponent().path)
                                    .font(.system(size: 11)).foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        if let image = store.thumbnail(for: item) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Pieces

struct InfoChip: View {
    let symbol: String?
    let text: String
    let prominent: Bool

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.system(size: 12, weight: prominent ? .semibold : .medium))
        .foregroundStyle(prominent ? Color.white : Color.white.opacity(0.7))
        .padding(.horizontal, 11)
        .frame(height: 28)
        .background(Capsule().fill(Theme.control))
    }
}

struct RecognizedText: View {
    let text: String
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Erkannter Text").font(.system(size: 12, weight: .semibold))
                Spacer()
                Button("Text kopieren", action: onCopy)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.selection)
            }
            ScrollView {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.card))
    }
}

/// Swatch plus the value in every common notation.
struct ColorDetail: View {
    let text: String

    var body: some View {
        let color = ContentClassifier.color(from: text) ?? .gray
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: color))
                .frame(height: 120)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(ColorFormats.rows(for: color, saved: text), id: \.label) { row in
                    HStack(spacing: 18) {
                        Text(row.label)
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 44, alignment: .leading)
                        Text(row.value)
                            .foregroundStyle(.white)
                            .textSelection(.enabled)
                    }
                }
            }
            .font(.system(size: 12.5, design: .monospaced))
        }
    }
}

enum ColorFormats {
    struct Row { let label: String; let value: String }

    static func rows(for color: NSColor, saved: String) -> [Row] {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
        let hex = String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))

        let k = 1 - max(r, g, b)
        let cmyk: (CGFloat, CGFloat, CGFloat) = k >= 1 ? (0, 0, 0)
            : ((1 - r - k) / (1 - k), (1 - g - k) / (1 - k), (1 - b - k) / (1 - k))

        let maxV = max(r, g, b), minV = min(r, g, b)
        let l = (maxV + minV) / 2
        let d = maxV - minV
        var h: CGFloat = 0
        var s: CGFloat = 0
        if d > 0 {
            s = d / (1 - abs(2 * l - 1))
            if maxV == r { h = 60 * ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if maxV == g { h = 60 * ((b - r) / d + 2) }
            else { h = 60 * ((r - g) / d + 4) }
            if h < 0 { h += 360 }
        }

        func pct(_ v: CGFloat) -> Int { Int(round(v * 100)) }
        return [
            Row(label: "Kopiert", value: saved.trimmingCharacters(in: .whitespacesAndNewlines)),
            Row(label: "HEX", value: hex),
            Row(label: "RGB", value: "rgb(\(Int(round(r * 255))), \(Int(round(g * 255))), \(Int(round(b * 255))))"),
            Row(label: "CMYK", value: "cmyk(\(pct(cmyk.0))%, \(pct(cmyk.1))%, \(pct(cmyk.2))%, \(pct(k))%)"),
            Row(label: "HSL", value: "hsl(\(Int(round(h))), \(pct(s))%, \(pct(l))%)"),
        ]
    }
}
