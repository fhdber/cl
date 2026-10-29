import SwiftUI
import UniformTypeIdentifiers

enum Layout {
    // Notch shelf
    static let shelfWidth: CGFloat = 660
    static let shelfCard = CGSize(width: 136, height: 100)
    static let shelfHeight: CGFloat = 44 + 40 + 24 + shelfCard.height + 14
    static let detailHeight: CGFloat = 340
    static let detailGap: CGFloat = 8
    /// Roughly the notch: where the shelf grows out of and folds back into.
    static let notchSize = CGSize(width: 200, height: 34)

    // Mini shelf – for smaller screens like the 14" MacBook Pro
    static let miniShelfWidth: CGFloat = 460
    static let miniCard = CGSize(width: 98, height: 72)
    static let miniShelfHeight: CGFloat = 6 + 32 + 6 + miniCard.height + 12
    static let miniDetailHeight: CGFloat = 300

    /// "auto" picks the mini shelf on screens narrower than 1600 pt (14" MacBook Pro and smaller).
    static func shelfIsMini(on screen: NSScreen) -> Bool {
        switch Prefs.shelfSize {
        case "mini": return true
        case "full": return false
        default: return screen.frame.width < 1600
        }
    }

    static func shelfSize(mini: Bool, preview: Bool) -> (width: CGFloat, height: CGFloat) {
        let width = mini ? miniShelfWidth : shelfWidth
        let base = mini ? miniShelfHeight : shelfHeight
        let detail = preview ? detailGap + (mini ? miniDetailHeight : detailHeight) : 0
        return (width, base + detail)
    }

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
    @ObservedObject var tray: TrayStore = .shared

    private static let shelfShape = UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 24,
                                                           bottomTrailingRadius: 24, topTrailingRadius: 0,
                                                           style: .continuous)
    private static let detailShape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    var body: some View {
        VStack(spacing: Layout.detailGap) {
            Group {
                if model.isMini { miniShelf } else { shelf }
            }
                .frame(height: model.isMini ? Layout.miniShelfHeight : Layout.shelfHeight)
                .background(Self.shelfShape.fill(Theme.surface))
                .overlay(
                    Self.shelfShape.strokeBorder(Color.white.opacity(model.isDropTargeted ? 0.5 : 0), lineWidth: 2)
                )
                .clipShape(Self.shelfShape)

            if model.tab == .clips, let item = model.previewItem {
                ClipDetailView(item: item, model: model, store: store)
                    .frame(height: model.isMini ? Layout.miniDetailHeight : Layout.detailHeight)
                    .background(Self.detailShape.fill(Theme.surface))
                    .clipShape(Self.detailShape)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .compositingGroup() // fade the shelf as one layer, not card by card
        .opacity(Double(0.25 + 0.75 * model.reveal)) // content eases in while the shape opens
        .mask(alignment: .top) { NotchReveal(progress: model.reveal) }
        // Files dropped anywhere on the shelf land in the tray.
        .onDrop(of: [.fileURL], isTargeted: Binding(get: { model.isDropTargeted },
                                                    set: { model.isDropTargeted = $0 })) { providers in
            TrayStore.loadURLs(from: providers) { urls in
                TrayStore.shared.add(urls)
                model.tab = .tray
            }
            return true
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: Full

    private var shelf: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ShelfTabs(model: model, diameter: 30)
                if model.tab == .clips {
                    SearchRow(model: model) { fullTools }
                } else {
                    Text(model.tab.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    if model.tab == .tray, !tray.files.isEmpty {
                        Button("Leeren") { tray.clear() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    fullTools
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            switch model.tab {
            case .clips:
                FilterBar(model: model, store: store)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                ShelfStrip(model: model, store: store)
            case .nook:
                NookView(model: model, player: .shared, calendar: .shared, shortcuts: .shared, mirror: .shared)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
            case .tray:
                TrayView(model: model, tray: .shared)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
            }
        }
    }

    @ViewBuilder
    private var fullTools: some View {
        if !Paster.isTrusted {
            Button("Auto-Einfügen aktivieren") { Paster.requestAccess() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.orange)
        }
        if model.tab == .clips {
            RoundButton(symbol: "text.viewfinder", help: "Text aus Bildschirmbereich erkennen") {
                model.onCaptureText?()
            }
            RoundButton(symbol: "eyedropper", help: "Farbe vom Bildschirm aufnehmen") {
                model.onPickColor?()
            }
        }
        RoundButton(symbol: "arrow.up.right", help: "Bibliothek öffnen") {
            model.onOpenLibrary?()
        }
        RoundButton(symbol: "gearshape.fill", help: "Einstellungen (⌘,)") {
            model.onOpenSettings?()
        }
        RoundButton(symbol: "arrow.down.right.and.arrow.up.left", help: "Mini-Shelf") {
            model.setMini(true)
        }
    }

    // MARK: Mini

    /// Compact: tabs, search and a few small buttons, then one row of content.
    private var miniShelf: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ShelfTabs(model: model, diameter: 24)
                if model.tab == .clips {
                    SearchRow(model: model, fontSize: 13) { miniTools }
                } else {
                    Text(model.tab.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    miniTools
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            .padding(.top, 6)

            switch model.tab {
            case .clips:
                ShelfStrip(model: model, store: store, card: Layout.miniCard, showsDayLabels: false)
            case .nook:
                NookView(model: model, player: .shared, calendar: .shared, shortcuts: .shared, mirror: .shared)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            case .tray:
                TrayView(model: model, tray: .shared)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
    }

    @ViewBuilder
    private var miniTools: some View {
        if !Paster.isTrusted {
            RoundButton(symbol: "exclamationmark", diameter: 24, help: "Auto-Einfügen aktivieren") {
                Paster.requestAccess()
            }
        }
        if model.tab == .clips {
            RoundButton(symbol: "star.fill", isOn: model.filter == .pinned, diameter: 24, help: "Favoriten") {
                model.filter = model.filter == .pinned ? .all : .pinned
            }
            MiniFilterMenu(model: model, store: store)
        }
        RoundButton(symbol: "arrow.up.left.and.arrow.down.right", diameter: 24, help: "Großes Shelf") {
            model.setMini(false)
        }
    }
}

/// Clips · Nook · Tray – small round segments at the start of the shelf's top row.
private struct ShelfTabs: View {
    @ObservedObject var model: PanelModel
    let diameter: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ShelfTab.allCases, id: \.self) { tab in
                Button { model.tab = tab } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: diameter * 0.4, weight: .semibold))
                        .foregroundStyle(model.tab == tab ? Color.black : Color.white.opacity(0.75))
                        .frame(width: diameter, height: diameter)
                        .background(Circle().fill(model.tab == tab ? Color.white : Color.clear))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("\(tab.title) (⌘\(tab.number))")
            }
        }
        .padding(2)
        .background(Capsule().fill(Theme.control))
    }
}

/// Categories, types and apps in one menu – the mini shelf has no room for pills.
private struct MiniFilterMenu: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipStore

    var body: some View {
        Menu {
            Button("Alle") { model.filter = .all }
            if !store.collections.isEmpty {
                Section("Kategorien") {
                    ForEach(store.collections, id: \.self) { name in
                        Button(name) { model.filter = .collection(name) }
                    }
                }
            }
            Section("Typ") {
                ForEach(model.kindsPresent) { kind in
                    Button {
                        model.filter = .kind(kind)
                    } label: {
                        Label(kind.pluralTitle, systemImage: kind.symbol)
                    }
                }
            }
            Section("App") {
                ForEach(model.topApps) { app in
                    Button(app.name) { model.filter = .app(app.bundleID) }
                }
            }
            Divider()
            Button("Bibliothek öffnen") { model.onOpenLibrary?() }
            Button("Einstellungen …") { model.onOpenSettings?() }
            Button("Clipline beenden") { NSApp.terminate(nil) }
        } label: {
            RoundIcon(symbol: "line.3.horizontal.decrease", isOn: model.filter != .all && model.filter != .pinned,
                      diameter: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Filtern")
    }
}

/// Grows from notch size to the full panel, anchored top-centre. The content keeps its
/// layout and is uncovered rather than squeezed – like Supaste's shelf.
private struct NotchReveal: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let notch = Layout.notchSize
            let width = notch.width + (geometry.size.width - notch.width) * progress
            let height = notch.height + (geometry.size.height - notch.height) * progress
            let radius = 12 + 14 * progress
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: radius,
                                   bottomTrailingRadius: radius, topTrailingRadius: 0, style: .continuous)
                .frame(width: width, height: height)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

/// Horizontal strip grouped by day, each group headed by a small label.
private struct ShelfStrip: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipStore
    var card: CGSize = Layout.shelfCard
    var showsDayLabels = true

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
                                if showsDayLabels {
                                    Text(section.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Theme.secondaryText)
                                        .frame(height: 16)
                                }
                                LazyHStack(spacing: 8) {
                                    ForEach(section.items) { item in
                                        ClipCard(item: item,
                                                 size: card,
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
