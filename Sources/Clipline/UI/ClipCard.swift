import AppKit
import SwiftUI

/// Supaste-style card: content bleeds to the edges, a soft shade at the bottom carries the
/// title, the source-app icon, the age and the ⌃⌘ shortcut. Hover reveals quick actions.
struct ClipCard: View {
    let item: ClipItem
    let size: CGSize
    let shortcut: Int?
    let isSelected: Bool
    let isHovered: Bool
    var showsPreviewButton = true
    let model: PanelModel
    let store: ClipStore

    private var compact: Bool { size.width < 110 }
    private var radius: CGFloat { compact ? 10 : 12 }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radius, style: .continuous) }

    var body: some View {
        ZStack {
            background
                .frame(width: size.width, height: size.height)
                .clipped()
            if hasShade {
                LinearGradient(colors: [.clear, .black.opacity(0.72)],
                               startPoint: UnitPoint(x: 0.5, y: 0.3), endPoint: .bottom)
            }
            VStack(alignment: .leading, spacing: compact ? 2 : 3) {
                if isHovered { hoverBar }
                Spacer(minLength: 0)
                if let title {
                    Text(title)
                        .font(.system(size: compact ? 10.5 : 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                metaRow
            }
            .padding(compact ? 6 : 8)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(isSelected ? Theme.selection : Theme.hairline, lineWidth: isSelected ? 2 : 1))
        .contentShape(shape)
        .onHover { inside in
            if inside {
                model.hoveredID = item.id
            } else if model.hoveredID == item.id {
                model.hoveredID = nil
            }
        }
        .onTapGesture(count: 2) { model.paste(model.targets(for: item)) }
        .onTapGesture { model.click(item) }
        .onDrag { store.itemProvider(for: item) }
        .contextMenu { ClipContextMenu(item: item, model: model, store: store) }
    }

    // MARK: - Background

    private var hasShade: Bool {
        switch item.kind {
        case .image, .screenshot, .color: return true
        case .link: return item.imageFile != nil
        default: return false
        }
    }

    @ViewBuilder
    private var background: some View {
        switch item.kind {
        case .image, .screenshot:
            thumbnail(fallback: "photo")

        case .link:
            if item.imageFile != nil {
                thumbnail(fallback: "globe")
            } else {
                ZStack(alignment: .topLeading) {
                    Theme.card
                    Image(systemName: "globe")
                        .font(.system(size: compact ? 14 : 18, weight: .light))
                        .foregroundStyle(ClipKind.link.tint)
                        .padding(compact ? 7 : 10)
                }
            }

        case .color:
            Color(nsColor: ContentClassifier.color(from: item.text ?? "") ?? .gray)

        case .text, .code:
            ZStack(alignment: .topLeading) {
                item.kind == .code ? Color(red: 0.06, green: 0.09, blue: 0.08) : Theme.card
                Text(String((item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)))
                    .font(item.kind == .code
                          ? .system(size: compact ? 8.5 : 9.5, design: .monospaced)
                          : .system(size: compact ? 10 : 11.5, weight: .medium))
                    .foregroundStyle(item.kind == .code ? Color(red: 0.7, green: 0.95, blue: 0.85) : .white.opacity(0.92))
                    .lineSpacing(compact ? 1 : 2)
                    .lineLimit(compact ? 3 : 4)
                    .padding(.horizontal, compact ? 7 : 9)
                    .padding(.top, compact ? 8 : 11)
            }

        case .file:
            ZStack {
                Theme.card
                if let first = item.fileURLs?.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: first.path))
                        .resizable()
                        .frame(width: compact ? 30 : 42, height: compact ? 30 : 42)
                        .offset(y: compact ? -8 : -12)
                }
            }
        }
    }

    private func thumbnail(fallback: String) -> some View {
        ZStack {
            Theme.card
            if let image = store.thumbnail(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                Image(systemName: fallback)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    // MARK: - Overlays

    private var title: String? {
        switch item.kind {
        case .image, .screenshot:
            return item.title
        case .link:
            let host = URL(string: item.text ?? "")?.host?.replacingOccurrences(of: "www.", with: "")
            return host ?? item.text
        case .color:
            return item.text?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        case .file:
            let name = item.fileURLs?.first?.lastPathComponent ?? ""
            let extra = (item.fileURLs?.count ?? 0) - 1
            return extra > 0 ? "\(name) +\(extra)" : name
        case .text, .code:
            return nil
        }
    }

    private var hoverBar: some View {
        HStack(spacing: 4) {
            CardIconButton(symbol: item.kind.symbol, compact: compact) { model.click(item) }
            Spacer(minLength: 0)
            if showsPreviewButton {
                CardIconButton(symbol: "eye.fill", compact: compact) { model.togglePreview(item) }
            }
            CardIconButton(symbol: "trash.fill", compact: compact) { model.delete(model.targets(for: item)) }
            CardIconButton(symbol: item.pinned ? "star.fill" : "star", compact: compact) {
                store.togglePin([item.id])
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: 4) {
            appIcon
            Text(PanelModel.relativeTime(item.createdAt))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            Spacer(minLength: 2)
            if let shortcut {
                Text("⌃⌘\(shortcut)")
                    .font(.system(size: compact ? 8.5 : 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 5)
                    .frame(height: compact ? 15 : 17)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
            } else if let size = fileSize {
                Text(size)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .font(.system(size: compact ? 9 : 10, weight: .medium))
    }

    @ViewBuilder
    private var appIcon: some View {
        let side: CGFloat = compact ? 12 : 14
        if let icon = AppIcons.icon(for: item.sourceBundleID) {
            Image(nsImage: icon).resizable().frame(width: side, height: side)
        } else {
            Image(systemName: item.kind.symbol)
                .font(.system(size: side * 0.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: side, height: side)
                .background(RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.25)))
        }
    }

    private var fileSize: String? {
        guard item.kind == .image || item.kind == .screenshot else { return nil }
        return store.fileSizeText(for: item)
    }
}

private struct CardIconButton: View {
    let symbol: String
    let compact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 8 : 10, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
                .background(Circle().fill(Color.black.opacity(0.6)))
                .overlay(Circle().strokeBorder(.white.opacity(0.15)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Right-click menu shared by every surface.
struct ClipContextMenu: View {
    let item: ClipItem
    let model: PanelModel
    let store: ClipStore

    var body: some View {
        let targets = model.targets(for: item)
        let ids = targets.map(\.id)

        Button(targets.count > 1 ? "\(targets.count) Clips einfügen" : "Einfügen") { model.paste(targets) }
        Button("Kopieren") { model.copy(targets) }
        Divider()
        Button(item.pinned ? "Aus Favoriten entfernen" : "Zu Favoriten") { store.togglePin(ids) }
        Menu("Kategorie") {
            ForEach(store.collections, id: \.self) { name in
                Button(name) { store.setCollection(name, for: ids) }
            }
            if !store.collections.isEmpty { Divider() }
            Button("Neue Kategorie …") { model.beginNewCollection(for: targets) }
            if item.collection != nil {
                Button("Aus Kategorie entfernen") { store.setCollection(nil, for: ids) }
            }
        }
        if let ocr = item.ocrText {
            Button("Erkannten Text kopieren") { model.copyText(ocr) }
        }
        if let url = item.fileURLs?.first ?? (item.kind == .link ? nil : store.imageURL(for: item)) {
            Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
        if item.kind == .link, let url = URL(string: item.text ?? "") {
            Button("Im Browser öffnen") { NSWorkspace.shared.open(url) }
        }
        Divider()
        Button("Löschen", role: .destructive) { model.delete(targets) }
    }
}
