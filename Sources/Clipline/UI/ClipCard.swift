import AppKit
import SwiftUI

struct ClipCard: View {
    static let size = CGSize(width: 212, height: 240)

    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let model: PanelModel
    let store: ClipStore
    @State private var hovering = false

    private let radius: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white.opacity(hovering || isSelected ? 0.09 : 0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.07),
                              lineWidth: isSelected ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .scaleEffect(isSelected ? 1 : 0.985)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { model.paste(model.targets(for: item)) }
        .onTapGesture { model.click(item) }
        .onDrag { store.itemProvider(for: item) }
        .contextMenu { menu }
    }

    // MARK: - Parts

    private var header: some View {
        HStack(spacing: 6) {
            if let icon = AppIcons.icon(for: item.sourceBundleID) {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            } else {
                Image(systemName: item.kind.symbol).font(.system(size: 11)).frame(width: 16)
            }
            Text(item.kind.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(item.kind.tint)
            Spacer(minLength: 4)
            if item.pinned {
                Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.white.opacity(0.7))
            }
            if item.collection != nil {
                Image(systemName: "square.stack").font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
            }
            Text(PanelModel.relativeTime(item.createdAt))
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            Text(String((item.text ?? "").prefix(800)))
                .font(.system(size: 12.5))
                .lineSpacing(2)
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 12)

        case .code:
            Text(String((item.text ?? "").prefix(800)))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Color(red: 0.75, green: 0.95, blue: 0.88))
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.black.opacity(0.3)))
                .clipped()
                .padding(.horizontal, 8)

        case .link:
            LinkPreview(text: item.text ?? "")
                .padding(.horizontal, 12)

        case .color:
            ColorSwatch(text: item.text ?? "")
                .padding(.horizontal, 8)

        case .image, .screenshot:
            if let image = store.thumbnail(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.horizontal, 8)
            } else {
                Image(systemName: "photo").font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

        case .file:
            FilePreview(urls: item.fileURLs ?? [])
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(item.meta)
                .lineLimit(1)
            if item.ocrText != nil {
                Image(systemName: "text.viewfinder").help("Text erkannt – durchsuchbar")
            }
            Spacer(minLength: 4)
            if index < 10 {
                KeyHint(text: "⌘\(index == 9 ? 0 : index + 1)")
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.4))
        .padding(.horizontal, 12)
        .frame(height: 30)
    }

    @ViewBuilder
    private var menu: some View {
        let targets = model.targets(for: item)
        let ids = targets.map(\.id)

        Button(targets.count > 1 ? "\(targets.count) Clips einfügen" : "Einfügen") { model.paste(targets) }
        Button("Kopieren") { model.copy(targets) }
        Divider()
        Button(item.pinned ? "Lösen" : "Anheften") { store.togglePin(ids) }
        Menu("Zu Sammlung") {
            ForEach(store.collections, id: \.self) { name in
                Button(name) { store.setCollection(name, for: ids) }
            }
            if !store.collections.isEmpty { Divider() }
            Button("Neue Sammlung …") { model.beginNewCollection(for: targets) }
            if item.collection != nil {
                Button("Aus Sammlung entfernen") { store.setCollection(nil, for: ids) }
            }
        }
        if let ocr = item.ocrText {
            Button("Erkannten Text kopieren") { model.copyText(ocr) }
        }
        if let url = item.fileURLs?.first ?? store.imageURL(for: item) {
            Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
        Divider()
        Button("Löschen", role: .destructive) { store.delete(Set(ids)) }
    }
}

// MARK: - Content previews

private struct LinkPreview: View {
    let text: String

    var body: some View {
        let url = URL(string: text)
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(ClipKind.link.tint)
                .padding(.top, 6)
            Text(url?.host?.replacingOccurrences(of: "www.", with: "") ?? text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(4)
        }
    }
}

private struct ColorSwatch: View {
    let text: String

    var body: some View {
        let color = ContentClassifier.color(from: text) ?? .gray
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        let ink: Color = luminance > 0.6 ? .black.opacity(0.75) : .white.opacity(0.9)

        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(nsColor: color))
            .overlay(alignment: .bottomLeading) {
                Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .padding(10)
            }
    }
}

private struct FilePreview: View {
    let urls: [URL]

    var body: some View {
        VStack(spacing: 10) {
            if let first = urls.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: first.path))
                    .resizable()
                    .frame(width: 64, height: 64)
                Text(first.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if urls.count > 1 {
                    Text("+ \(urls.count - 1) weitere")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
