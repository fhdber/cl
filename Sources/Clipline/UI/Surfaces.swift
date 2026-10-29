import SwiftUI
import UniformTypeIdentifiers

enum Layout {
    // Notch shelf
    static let shelfWidth: CGFloat = 720
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

    // Compact shelf – just a row of small clips under the notch; typing searches.
    static let compactShelfWidth: CGFloat = 500
    static let compactCard = CGSize(width: 74, height: 56)
    static let compactBand: CGFloat = 30
    static let compactShelfHeight: CGFloat = compactBand + compactCard.height + 10

    /// The camera housing on this screen: (width, height). Zero width where there is no notch.
    static func notch(on screen: NSScreen) -> CGSize {
        let menuBar = max(screen.frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
        guard screen.safeAreaInsets.top > 0 else { return CGSize(width: 0, height: menuBar) }
        // Never trust a missing or implausible measurement: MacBook notches are ~185–210 pt wide.
        var width: CGFloat = 210
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let measured = screen.frame.width - left.width - right.width
            if measured > 120 && measured < 400 { width = measured }
        }
        return CGSize(width: max(width, 210), height: max(screen.safeAreaInsets.top, menuBar))
    }

    enum ShelfMode { case full, mini, compact }

    /// "auto" picks the mini shelf on screens narrower than 1600 pt (14" MacBook Pro and smaller).
    static func shelfMode(on screen: NSScreen) -> ShelfMode {
        switch Prefs.shelfSize {
        case "compact": return .compact
        case "mini": return .mini
        case "full": return .full
        default: return screen.frame.width < 1600 ? .mini : .full
        }
    }

    static func shelfIsMini(on screen: NSScreen) -> Bool { shelfMode(on: screen) != .full }

    static func shelfSize(mode: ShelfMode, preview: Bool, notchHeight: CGFloat = compactBand) -> (width: CGFloat, height: CGFloat) {
        switch mode {
        case .full:
            return (shelfWidth, shelfHeight + (preview ? detailGap + detailHeight : 0))
        case .mini:
            return (miniShelfWidth, miniShelfHeight + (preview ? detailGap + miniDetailHeight : 0))
        case .compact:
            let band = max(compactBand, notchHeight + 2)
            return (compactShelfWidth, band + compactCard.height + 10 + (preview ? detailGap + miniDetailHeight : 0))
        }
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
                if model.isCompact { compactShelf } else if model.isMini { miniShelf } else { shelf }
            }
                .frame(height: model.isCompact ? compactBand + Layout.compactCard.height + 10
                       : model.isMini ? Layout.miniShelfHeight : Layout.shelfHeight)
                .background(Self.shelfShape.fill(Theme.surface))
                .overlay(
                    Self.shelfShape.stroke(Color.white.opacity(model.isDropTargeted ? 0.5 : 0), lineWidth: 4)
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
            // Top row sits beside the camera: tabs left, tools right, nothing in the middle.
            HStack(spacing: 10) {
                ShelfTabs(model: model, diameter: 30)
                if model.tab == .tray, !tray.files.isEmpty {
                    Button("Leeren") { tray.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 0)
                fullTools
            }
            .padding(.horizontal, 16)
            .frame(height: 44)

            switch model.tab {
            case .clips:
                HStack(spacing: 8) {
                    searchField
                    FilterBar(model: model, store: store)
                }
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

    /// Search below the notch line, at the start of the filter row.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
            FocusableTextField(text: $model.query, placeholder: "Suchen", fontSize: 13, focusToken: model.focusToken)
            if !model.query.isEmpty {
                Button { model.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(width: 190, height: 30)
        .background(Capsule().fill(Theme.control))
    }

    /// Mini and compact have no visible field: typing goes into this one, the query shows as a tile.
    private var hiddenSearchField: some View {
        FocusableTextField(text: $model.query, placeholder: "", fontSize: 1, focusToken: model.focusToken)
            .frame(width: 1, height: 1)
            .opacity(0.01)
    }

    @ViewBuilder
    private var fullTools: some View {
        if !Paster.isTrusted {
            RoundButton(symbol: "exclamationmark", tint: .orange,
                        help: "Auto-Einfügen aktivieren – Clipline braucht dafür die Bedienungshilfen") {
                Paster.requestAccess()
            }
        }
        if model.tab == .clips {
            RoundButton(symbol: "sparkle", help: "Claude fragen (⌃⌘C)") {
                if let item = model.cursorItem ?? model.visibleItems.first { model.onAskClaude?(item, nil) }
            }
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
            model.setShelfSize("mini")
        }
    }

    // MARK: Mini

    /// Mini: tabs and a few small buttons, then one row of content.
    private var miniShelf: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Tabs left, tools right – the middle stays free for the camera. Typing searches.
            HStack(spacing: 6) {
                ShelfTabs(model: model, diameter: 24)
                Spacer(minLength: 0)
                miniTools
            }
            .padding(.horizontal, 14)
            .frame(height: 32)
            .padding(.top, 6)
            .background(hiddenSearchField)

            switch model.tab {
            case .clips:
                ShelfStrip(model: model, store: store, card: Layout.miniCard, showsDayLabels: false,
                           showsQueryTile: true)
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
            RoundButton(symbol: "exclamationmark", diameter: 24, tint: .orange,
                        help: "Auto-Einfügen aktivieren – Clipline braucht dafür die Bedienungshilfen") {
                Paster.requestAccess()
            }
        }
        if model.tab == .clips {
            RoundButton(symbol: "star.fill", isOn: model.filter == .pinned, diameter: 24, help: "Favoriten") {
                model.filter = model.filter == .pinned ? .all : .pinned
            }
            MiniFilterMenu(model: model, store: store)
        }
        RoundButton(symbol: "arrow.down.right.and.arrow.up.left", diameter: 24, help: "Kompakt") {
            model.setShelfSize("compact")
        }
        RoundButton(symbol: "arrow.up.left.and.arrow.down.right", diameter: 24, help: "Großes Shelf") {
            model.setShelfSize("full")
        }
    }

    // MARK: Compact

    private var compactBand: CGFloat { max(Layout.compactBand, model.notchSize.height + 2) }

    /// Only a row of small clips under the notch. Typing filters; a hidden field takes the keys.
    /// The top band is as tall as the camera housing; only a hint and a button sit in the wings.
    private var compactShelf: some View {
        // Wings beside the camera, with breathing room towards it.
        let wing = max(60, (Layout.compactShelfWidth - model.notchSize.width) / 2 - 16)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .help("Einfach tippen, um zu suchen")
                    .frame(width: wing - 14, alignment: .leading)
                .padding(.leading, 14)
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    RoundButton(symbol: "arrow.up.left.and.arrow.down.right", diameter: 20, help: "Größer") {
                        model.setShelfSize("mini")
                    }
                }
                .frame(width: wing - 14)
                .padding(.trailing, 14)
            }
            .frame(height: compactBand, alignment: .center)
            .background(hiddenSearchField)

            ShelfStrip(model: model, store: store, card: Layout.compactCard, showsDayLabels: false,
                       showsQueryTile: true)
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
    /// Shows what you've typed as the first tile (mini and compact have no visible search field).
    var showsQueryTile = false

    var body: some View {
        let items = model.visibleItems
        let shortcuts = model.shortcutIndex
        let queryTile = showsQueryTile && !model.query.isEmpty
        if items.isEmpty && !queryTile {
            EmptyHint(query: model.query)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        if queryTile {
                            QueryTile(model: model, size: card, hasResults: !items.isEmpty)
                        }
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

/// The search term as a tile at the start of the strip, with a clear button.
private struct QueryTile: View {
    @ObservedObject var model: PanelModel
    let size: CGSize
    let hasResults: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "magnifyingglass")
                Spacer()
                Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .help("Suche leeren (Esc)")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.secondaryText)
            Spacer(minLength: 0)
            Text(model.query)
                .font(.system(size: size.width < 90 ? 11 : 13, weight: .semibold))
                .lineLimit(2)
                .truncationMode(.head)
            if !hasResults {
                Text("Nichts gefunden")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(8)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.selection.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.selection, lineWidth: 1.5))
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
                .padding(.leading, 62) // sits on the title bar, next to the traffic lights
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
            // Clear of the window's rounded corners; the top row lines up with the traffic lights.
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)

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
