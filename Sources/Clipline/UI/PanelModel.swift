import AppKit

enum ClipFilter: Hashable {
    case all
    case pinned
    case kind(ClipKind)
    case app(String)
    case collection(String)
}

struct AppSource: Identifiable {
    let bundleID: String
    let name: String
    var count = 0
    var id: String { bundleID }
}

enum TimelineRow: Identifiable {
    case day(String)
    case clip(ClipItem, index: Int)

    var id: String {
        switch self {
        case .day(let title): return "day-\(title)"
        case .clip(let item, _): return item.id.uuidString
        }
    }
}

/// UI state of the timeline panel: search, filter, cursor and multi-selection.
final class PanelModel: ObservableObject {
    @Published var query = "" { didSet { resetCursor() } }
    @Published var filter: ClipFilter = .all { didSet { resetCursor() } }
    @Published var cursor: UUID?
    @Published var selection: Set<UUID> = []
    @Published var focusToken = 0
    @Published var isAddingCollection = false
    @Published var newCollectionName = ""

    let store: ClipStore
    var onPaste: (([ClipItem]) -> Void)?
    var onCopy: (([ClipItem]) -> Void)?
    var onOpenSettings: (() -> Void)?
    private var collectionTargets: [UUID] = []

    init(store: ClipStore) {
        self.store = store
    }

    // MARK: - Derived data

    var visibleItems: [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return store.items.filter { item in
            switch filter {
            case .all: break
            case .pinned: if !item.pinned { return false }
            case .kind(let kind): if item.kind != kind { return false }
            case .app(let id): if item.sourceBundleID != id { return false }
            case .collection(let name): if item.collection != name { return false }
            }
            return q.isEmpty || item.searchText.localizedStandardContains(q)
        }
    }

    func rows(for items: [ClipItem]) -> [TimelineRow] {
        var rows: [TimelineRow] = []
        var lastDay: String?
        for (index, item) in items.enumerated() {
            let day = Self.dayTitle(item.createdAt)
            if day != lastDay {
                rows.append(.day(day))
                lastDay = day
            }
            rows.append(.clip(item, index: index))
        }
        return rows
    }

    var kindsPresent: [ClipKind] {
        let present = Set(store.items.map(\.kind))
        return ClipKind.allCases.filter(present.contains)
    }

    /// The most used source apps, for the app filter chips.
    var topApps: [AppSource] {
        var counts: [String: AppSource] = [:]
        for item in store.items {
            guard let id = item.sourceBundleID else { continue }
            counts[id, default: AppSource(bundleID: id, name: item.sourceAppName ?? id)].count += 1
        }
        return Array(counts.values.sorted { $0.count > $1.count }.prefix(6))
    }

    var filterOptions: [ClipFilter] {
        var options: [ClipFilter] = [.all]
        if store.items.contains(where: \.pinned) { options.append(.pinned) }
        options += kindsPresent.map { .kind($0) }
        options += topApps.map { .app($0.bundleID) }
        options += store.collections.map { .collection($0) }
        return options
    }

    var selectedItems: [ClipItem] {
        // Oldest first, so multi-clip pastes read in the order they were copied.
        visibleItems.filter { selection.contains($0.id) }.reversed()
    }

    // MARK: - Navigation

    func prepareForShow() {
        query = ""
        isAddingCollection = false
        resetCursor()
        focusToken += 1
    }

    func resetCursor() {
        cursor = visibleItems.first?.id
        selection = cursor.map { Set([$0]) } ?? []
    }

    func move(_ delta: Int, extend: Bool) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let current = cursor.flatMap { id in items.firstIndex { $0.id == id } } ?? -1
        let next = max(0, min(items.count - 1, current + delta))
        let id = items[next].id
        cursor = id
        if extend { selection.insert(id) } else { selection = [id] }
    }

    func click(_ item: ClipItem) {
        let modifiers = NSEvent.modifierFlags
        let items = visibleItems
        if modifiers.contains(.command) {
            if selection.contains(item.id) { selection.remove(item.id) } else { selection.insert(item.id) }
        } else if modifiers.contains(.shift),
                  let anchor = cursor.flatMap({ id in items.firstIndex { $0.id == id } }),
                  let target = items.firstIndex(where: { $0.id == item.id }) {
            selection = Set(items[min(anchor, target)...max(anchor, target)].map(\.id))
        } else {
            selection = [item.id]
        }
        cursor = item.id
    }

    func cycleFilter(_ delta: Int) {
        let options = filterOptions
        let index = options.firstIndex(of: filter) ?? 0
        filter = options[(index + delta + options.count) % options.count]
    }

    // MARK: - Actions

    /// Context-menu actions apply to the whole selection if the clicked card is part of it.
    func targets(for item: ClipItem) -> [ClipItem] {
        selection.contains(item.id) ? selectedItems : [item]
    }

    func paste(_ items: [ClipItem]) { onPaste?(items) }
    func copy(_ items: [ClipItem]) { onCopy?(items) }

    func pasteSelection() {
        let items = selectedItems
        if !items.isEmpty { paste(items) }
    }

    func paste(at index: Int) {
        let items = visibleItems
        guard items.indices.contains(index) else { return }
        paste([items[index]])
    }

    func deleteSelection() {
        let items = visibleItems
        let firstIndex = items.firstIndex { selection.contains($0.id) } ?? 0
        store.delete(selection)
        let remaining = visibleItems
        cursor = remaining.isEmpty ? nil : remaining[min(firstIndex, remaining.count - 1)].id
        selection = cursor.map { Set([$0]) } ?? []
    }

    func togglePinSelection() {
        store.togglePin(Array(selection))
    }

    // MARK: - Collections

    func beginNewCollection(for items: [ClipItem] = []) {
        collectionTargets = items.map(\.id)
        newCollectionName = ""
        isAddingCollection = true
    }

    func commitNewCollection() {
        let name = newCollectionName.trimmingCharacters(in: .whitespaces)
        isAddingCollection = false
        focusToken += 1
        guard !name.isEmpty else { return }
        store.addCollection(name)
        if collectionTargets.isEmpty {
            filter = .collection(name)
        } else {
            store.setCollection(name, for: collectionTargets)
        }
        collectionTargets = []
    }

    func cancelNewCollection() {
        isAddingCollection = false
        collectionTargets = []
        focusToken += 1
    }

    func deleteCollection(_ name: String) {
        if filter == .collection(name) { filter = .all }
        store.removeCollection(name)
    }

    // MARK: - Formatting

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMM")
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.unitsStyle = .short
        return formatter
    }()

    static func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Heute" }
        if calendar.isDateInYesterday(date) { return "Gestern" }
        return dayFormatter.string(from: date)
    }

    static func relativeTime(_ date: Date) -> String {
        if Date().timeIntervalSince(date) < 60 { return "gerade eben" }
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}
