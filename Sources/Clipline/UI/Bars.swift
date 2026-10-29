import SwiftUI

// MARK: - Round icon button

struct RoundIcon: View {
    let symbol: String
    var isOn = false
    var diameter: CGFloat = 30
    /// Accent for status buttons (e.g. a missing permission).
    var tint: Color?

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: diameter * 0.4, weight: .semibold))
            .foregroundStyle(isOn ? Color.black : (tint ?? Color.white.opacity(0.85)))
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(isOn ? Color.white : (tint.map { $0.opacity(0.18) } ?? Theme.control)))
            .contentShape(Circle())
    }
}

struct RoundButton: View {
    let symbol: String
    var isOn = false
    var diameter: CGFloat = 30
    var tint: Color?
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { RoundIcon(symbol: symbol, isOn: isOn, diameter: diameter, tint: tint) }
            .buttonStyle(.plain)
            .help(help)
    }
}

// MARK: - Search row

struct SearchRow<Trailing: View>: View {
    @ObservedObject var model: PanelModel
    var placeholder = "Suchen"
    var fontSize: CGFloat = 14
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: fontSize))
                .foregroundStyle(Theme.secondaryText)
            FocusableTextField(text: $model.query, placeholder: placeholder, fontSize: fontSize,
                               focusToken: model.focusToken)
            trailing()
        }
    }
}

// MARK: - Category pills

struct CategoryPill: View {
    let title: String
    let count: Int?
    let tint: Color
    let isOn: Bool
    var height: CGFloat = 30
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                    .foregroundStyle(isOn ? Color.black : Color.white.opacity(0.92))
                if let count {
                    Text("\(count)")
                        .foregroundStyle(isOn ? Color.black.opacity(0.4) : Color.white.opacity(0.45))
                }
            }
            .font(.system(size: height * 0.42, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, height * 0.42)
            .frame(height: height)
            .background(Capsule().fill(isOn ? Color.white : tint))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Favourites · type · app · All/History · custom categories · +
struct FilterBar: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var store: ClipStore
    var allTitle = "Alle"
    var showsAllCount = false
    var showsTypeAndApp = true
    var height: CGFloat = 30

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                RoundButton(symbol: "star.fill", isOn: model.filter == .pinned, diameter: height, help: "Favoriten") {
                    model.filter = model.filter == .pinned ? .all : .pinned
                }
                if showsTypeAndApp {
                    typeMenu
                    appMenu
                }

                CategoryPill(title: allTitle, count: showsAllCount ? store.items.count : nil, tint: Theme.control,
                             isOn: model.filter == .all, height: height) {
                    model.filter = .all
                }

                ForEach(store.collections, id: \.self) { name in
                    CategoryPill(title: name, count: store.count(in: name),
                                 tint: Theme.categoryColor(store.collectionColors[name]),
                                 isOn: model.filter == .collection(name), height: height) {
                        model.filter = .collection(name)
                    }
                    .contextMenu {
                        Button("Kategorie löschen", role: .destructive) { model.deleteCollection(name) }
                    }
                }

                if model.isAddingCollection {
                    FocusableTextField(text: $model.newCollectionName, placeholder: "Name", fontSize: height * 0.42,
                                       focusToken: model.focusToken,
                                       onSubmit: { model.commitNewCollection() })
                        .padding(.horizontal, 12)
                        .frame(width: 130, height: height)
                        .background(Capsule().strokeBorder(.white.opacity(0.35)))
                } else {
                    RoundButton(symbol: "plus", diameter: height, help: "Neue Kategorie") {
                        model.beginNewCollection()
                    }
                }
            }
        }
    }

    private var typeMenu: some View {
        Menu {
            Button("Alle Typen") { model.filter = .all }
            Divider()
            ForEach(model.kindsPresent) { kind in
                Button {
                    model.filter = .kind(kind)
                } label: {
                    Label(kind.pluralTitle, systemImage: kind.symbol)
                }
            }
        } label: {
            RoundIcon(symbol: "square.grid.2x2.fill", isOn: model.isKindFilter, diameter: height)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Nach Typ filtern")
    }

    private var appMenu: some View {
        Menu {
            Button("Alle Apps") { model.filter = .all }
            Divider()
            ForEach(model.topApps) { app in
                Button(app.name) { model.filter = .app(app.bundleID) }
            }
        } label: {
            RoundIcon(symbol: "app.badge", isOn: model.isAppFilter, diameter: height)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Nach App filtern")
    }
}
