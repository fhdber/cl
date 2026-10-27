import SwiftUI

struct PanelView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(model: model, store: store)
            Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
            ClipTimeline(model: model, store: store)
        }
        .background(
            ZStack {
                VisualEffect(material: .hudWindow, cornerRadius: 20)
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.black.opacity(0.35))
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.1)))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Top bar

private struct TopBar: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipStore

    var body: some View {
        HStack(spacing: 12) {
            search

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    FilterChip(isOn: model.filter == .all, action: { model.filter = .all }) { Text("Alle") }
                    if store.items.contains(where: \.pinned) {
                        FilterChip(isOn: model.filter == .pinned, action: { model.filter = .pinned }) {
                            Image(systemName: "pin.fill")
                        }
                        .help("Angeheftet")
                    }

                    divider

                    ForEach(model.kindsPresent) { kind in
                        FilterChip(isOn: model.filter == .kind(kind), action: { model.filter = .kind(kind) }) {
                            Label(kind.pluralTitle, systemImage: kind.symbol)
                        }
                    }

                    let apps = model.topApps
                    if !apps.isEmpty { divider }
                    ForEach(apps) { app in
                        FilterChip(isOn: model.filter == .app(app.bundleID), action: { model.filter = .app(app.bundleID) }) {
                            if let icon = AppIcons.icon(for: app.bundleID) {
                                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
                            } else {
                                Text(app.name)
                            }
                        }
                        .help(app.name)
                    }

                    divider
                    collections
                }
                .padding(.vertical, 2)
            }

            Spacer(minLength: 0)

            if !Paster.isTrusted {
                Button("Auto-Einfügen aktivieren") { Paster.requestAccess() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
                    .help("Clipline braucht Bedienungshilfen-Zugriff, um ⌘V für dich zu drücken.")
            }

            Text("\(model.visibleItems.count)")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.4))

            Button { model.onOpenSettings?() } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.6))
            .help("Einstellungen (⌘,)")
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private var search: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.45))
            FocusableTextField(text: $model.query,
                               placeholder: "Suchen – auch Text in Bildern",
                               focusToken: model.focusToken)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(width: 250, height: 30)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white.opacity(0.07)))
    }

    @ViewBuilder
    private var collections: some View {
        ForEach(store.collections, id: \.self) { name in
            FilterChip(isOn: model.filter == .collection(name), action: { model.filter = .collection(name) }) {
                Label(name, systemImage: "square.stack")
            }
            .contextMenu {
                Button("Sammlung löschen", role: .destructive) { model.deleteCollection(name) }
            }
        }
        if model.isAddingCollection {
            FocusableTextField(text: $model.newCollectionName,
                               placeholder: "Name",
                               fontSize: 12,
                               focusToken: model.focusToken,
                               onSubmit: { model.commitNewCollection() })
                .padding(.horizontal, 10)
                .frame(width: 130, height: 26)
                .background(Capsule().strokeBorder(.white.opacity(0.3)))
        } else {
            FilterChip(isOn: false, action: { model.beginNewCollection() }) {
                Image(systemName: "plus")
            }
            .help("Neue Sammlung")
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 16).padding(.horizontal, 4)
    }
}

// MARK: - Timeline

private struct ClipTimeline: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipStore

    var body: some View {
        let items = model.visibleItems
        if items.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(model.rows(for: items)) { row in
                            switch row {
                            case .day(let title):
                                DayMarker(title: title)
                            case .clip(let item, let index):
                                ClipCard(item: item,
                                         index: index,
                                         isSelected: model.selection.contains(item.id),
                                         model: model,
                                         store: store)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .onChange(of: model.cursor) { _, cursor in
                    guard let cursor else { return }
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(cursor.uuidString) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: model.query.isEmpty ? "list.clipboard" : "magnifyingglass")
                .font(.system(size: 28, weight: .light))
            Text(model.query.isEmpty ? "Kopier etwas – es landet hier." : "Nichts gefunden für „\(model.query)“")
                .font(.system(size: 13))
        }
        .foregroundStyle(.white.opacity(0.45))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DayMarker: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .kerning(1.2)
            .foregroundStyle(.white.opacity(0.4))
            .fixedSize()
            .rotationEffect(.degrees(-90))
            .frame(width: 16, height: ClipCard.size.height)
    }
}
