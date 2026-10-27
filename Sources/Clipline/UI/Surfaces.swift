import SwiftUI

enum Layout {
    // Notch shelf
    static let shelfWidth: CGFloat = 660
    static let shelfCard = CGSize(width: 136, height: 100)
    static let shelfHeight: CGFloat = 44 + 40 + 24 + shelfCard.height + 14
    static let detailHeight: CGFloat = 340
    static let detailGap: CGFloat = 8

    // Quick paste
    static let quickPasteWidth: CGFloat = 318
    static let quickPasteColumns = 3
    static let quickPasteCard = CGSize(width: 94, height: 72)
    static let quickPasteSpacing: CGFloat = 6
    static let quickPasteMaxRows = 4
    /// Padding + search row + filter row + gaps around the grid.
    static let quickPasteChrome: CGFloat = 10 + 30 + 8 + 28 + 8 + 4 + 10

    /// Grows with the content, up to four rows – like Supaste's popup.
    static func quickPasteHeight(itemCount: Int) -> CGFloat {
        let rows = min(quickPasteMaxRows, max(1, (itemCount + quickPasteColumns - 1) / quickPasteColumns))
        return quickPasteChrome + CGFloat(rows) * quickPasteCard.height + CGFloat(rows - 1) * quickPasteSpacing
    }

    // Library
    static let libraryCard = CGSize(width: 150, height: 112)
    static let inspectorWidth: CGFloat = 300
}

// MARK: - Notch shelf

struct ShelfView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipStore

    private static let shelfShape = UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 24,
                                                           bottomTrailingRadius: 24, topTrailingRadius: 0,
                                                           style: .continuous)
    private static let detailShape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        VStack(spacing: Layout.detailGap) {
            shelf
                .frame(height: Layout.shelfHeight)
                .background(Self.shelfShape.fill(Theme.surface))
                .clipShape(Self.shelfShape)

            if let item = model.previewItem {
                ClipDetailView(item: item, model: model, store: store)
                    .frame(height: Layout.detailHeight)
                    .background(Self.detailShape.fill(Theme.surface))
                    .clipShape(Self.detailShape)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }

    private var shelf: some View {
        VStack(alignment: .leading, spacing: 0) {
            SearchRow(model: model) {
                if !Paster.isTrusted {
                    Button("Auto-Einfügen aktivieren") { Paster.requestAccess() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                }
                RoundButton(symbol: "text.viewfinder", help: "Text aus Bildschirmbereich erkennen") {
                    model.onCaptureText?()
                }
                RoundButton(symbol: "eyedropper", help: "Farbe vom Bildschirm aufnehmen") {
                    model.onPickColor?()
                }
                RoundButton(symbol: "arrow.up.right", help: "Bibliothek öffnen") {
                    model.onOpenLibrary?()
                }
                RoundButton(symbol: "gearshape.fill", help: "Einstellungen (⌘,)") {
                    model.onOpenSettings?()
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            FilterBar(model: model, store: store)
                .padding(.horizontal, 12)
                .frame(height: 40)

            ShelfStrip(model: model, store: store)
        }
    }
}

/// Horizontal strip grouped by day, each group headed by a small label.
private struct ShelfStrip: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipStore

    var body: some View {
        let items = model.visibleItems
        let shortcuts = model.shortcutIndex
        if items.isEmpty {
            EmptyHint(query: model.query)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(model.sections(for: items)) { section in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.secondaryText)
                                    .frame(height: 16)
                                LazyHStack(spacing: 8) {
                                    ForEach(section.items) { item in
                                        ClipCard(item: item,
                                                 size: Layout.shelfCard,
                                                 shortcut: shortcuts[item.id],
                                                 isSelected: model.selection.contains(item.id),
                                                 isHovered: model.hoveredID == item.id,
                                                 model: model,
                                                 store: store)
                                            .id(item.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 2)
                    .padding(.bottom, 14)
                }
                .onChange(of: model.cursor) { _, cursor in
                    guard let cursor else { return }
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(cursor) }
                }
            }
        }
    }
}

// MARK: - Quick paste

struct QuickPasteView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipStore

    private static let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SearchRow(model: model, placeholder: "Verlauf durchsuchen", fontSize: 13) { EmptyView() }
                .frame(height: 30)
            FilterBar(model: model, store: store, allTitle: "Verlauf", showsAllCount: true,
                      showsTypeAndApp: false, height: 26)
                .frame(height: 28)
            CardGrid(model: model, store: store, card: Layout.quickPasteCard,
                     columns: Layout.quickPasteColumns, spacing: Layout.quickPasteSpacing,
                     showsPreviewButton: false)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Self.shape.fill(Color(white: 0.07)))
        .overlay(Self.shape.strokeBorder(.white.opacity(0.1)))
        .clipShape(Self.shape)
        .environment(\.colorScheme, .dark)
    }
}

/// Fixed-column grid used by quick paste and the library.
struct CardGrid: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipStore
    let card: CGSize
    let columns: Int
    var spacing: CGFloat = 10
    var showsPreviewButton = true

    var body: some View {
        let items = model.visibleItems
        let shortcuts = model.shortcutIndex
        if items.isEmpty {
            EmptyHint(query: model.query)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(card.width), spacing: spacing), count: columns),
                              alignment: .leading, spacing: spacing) {
                        ForEach(items) { item in
                            ClipCard(item: item,
                                     size: card,
                                     shortcut: shortcuts[item.id],
                                     isSelected: model.selection.contains(item.id),
                                     isHovered: model.hoveredID == item.id,
                                     showsPreviewButton: showsPreviewButton,
                                     model: model,
                                     store: store)
                                .id(item.id)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onChange(of: model.cursor) { _, cursor in
                    guard let cursor else { return }
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(cursor) }
                }
            }
        }
    }
}

struct EmptyHint: View {
    let query: String

    var body: some View {
        Text(query.isEmpty ? "Noch nichts hier – kopier etwas." : "Nichts gefunden für „\(query)“")
            .font(.system(size: 12))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Library window

struct LibraryView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipStore

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                SearchRow(model: model) {
                    RoundButton(symbol: "gearshape.fill", help: "Einstellungen") { model.onOpenSettings?() }
                }
                .padding(.leading, 66) // sits on the title bar, next to the traffic lights
                .frame(height: 30)

                FilterBar(model: model, store: store, allTitle: "Verlauf", showsAllCount: true)
                    .frame(height: 32)

                GeometryReader { geometry in
                    // Cards stretch so the columns always fill the full width.
                    let spacing: CGFloat = 10
                    let columns = max(2, Int((geometry.size.width + spacing) / (Layout.libraryCard.width + spacing)))
                    let cardWidth = max(80, floor((geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)))
                    CardGrid(model: model, store: store,
                             card: CGSize(width: cardWidth, height: floor(cardWidth * 0.75)),
                             columns: columns, spacing: spacing, showsPreviewButton: false)
                        .onChange(of: columns, initial: true) { model.columns = columns }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 1)
            .padding(.bottom, 4)

            if let item = model.cursorItem, model.selection.count == 1 {
                Rectangle().fill(Theme.hairline).frame(width: 1)
                LibraryInspector(item: item, model: model, store: store)
                    .frame(width: Layout.inspectorWidth)
            }
        }
        .background(Theme.surface)
        .ignoresSafeArea() // content runs under the transparent title bar
        .environment(\.colorScheme, .dark)
    }
}

private struct LibraryInspector: View {
    let item: ClipItem
    let model: PanelModel
    let store: ClipStore

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                InfoChip(symbol: item.kind.symbol, text: item.collection ?? item.kind.title, prominent: true)
                Spacer()
                RoundButton(symbol: item.pinned ? "star.fill" : "star", diameter: 26, help: "Favorit") {
                    store.togglePin([item.id])
                }
                RoundButton(symbol: "trash", diameter: 26, help: "Löschen") { model.delete([item]) }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    preview
                    field("Erstellt", Self.dateFormatter.string(from: item.createdAt))
                    if let app = item.sourceAppName {
                        VStack(alignment: .leading, spacing: 4) {
                            label("Quelle")
                            HStack(spacing: 6) {
                                if let icon = AppIcons.icon(for: item.sourceBundleID) {
                                    Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                                }
                                Text(app).font(.system(size: 12, weight: .medium))
                            }
                        }
                    }
                    if item.kind == .link, let link = item.text {
                        VStack(alignment: .leading, spacing: 4) {
                            label("Link")
                            HStack {
                                Text(link).font(.system(size: 12)).lineLimit(2)
                                Spacer()
                                RoundButton(symbol: "arrow.up.right", diameter: 22, help: "Öffnen") {
                                    if let url = URL(string: link) { NSWorkspace.shared.open(url) }
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
                        }
                    }
                    if let size = item.imageSize {
                        field("Maße", "\(Int(size.width)) × \(Int(size.height)) px")
                    }
                    if let bytes = store.fileSizeText(for: item), item.kind != .link {
                        field("Größe", bytes)
                    }
                    if let ocr = item.ocrText {
                        VStack(alignment: .leading, spacing: 4) {
                            label("Erkannter Text")
                            Text(ocr).font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { model.copy([item]) } label: {
                Label("In Zwischenablage kopieren", systemImage: "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .color:
            ColorDetail(text: item.text ?? "")
        case .text, .code:
            Text(String((item.text ?? "").prefix(2000)))
                .font(item.kind == .code ? .system(size: 11, design: .monospaced) : .system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
        default:
            if let image = store.thumbnail(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if let first = item.fileURLs?.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: first.path))
                    .resizable().frame(width: 64, height: 64)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(Theme.secondaryText)
    }

    private func field(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(title)
            Text(value).font(.system(size: 12, weight: .medium))
        }
    }
}
