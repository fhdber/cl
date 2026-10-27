import AppKit
import Combine

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

struct DaySection: Identifiable {
    let title: String
    let items: [ClipItem]
    var id: String { title }
}

/// UI state of one surface (shelf, quick paste or library): search, filter, cursor, selection.
final class PanelModel: ObservableObject {
    @Published var query = "" { didSet { resetCursor() } }
    @Published var filter: ClipFilter = .all { didSet { resetCursor() } }
    @Published var cursor: UUID?
    @Published var selection: Set<UUID> = []
    @Published var hoveredID: UUID?
    @Published var previewID: UUID?
    @Published var focusToken = 0
    @Published var isAddingCollection = false
    @Published var newCollectionName = ""

    let store: ClipStore
    /// Cards per row, so ↑/↓ can jump a row in grid layouts.
    var columns = 1
    var onPaste: (([ClipItem]) -> Void)?
    var onCopy: (([ClipItem]) -> Void)?
    var onCopyText: ((String) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenLibrary: (() -> Void)?
    var onCaptureText: (() -> Void)?
    var onPickColor: (() -> Void)?
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

    func sections(for items: [ClipItem]) -> [DaySection] {
        var sections: [DaySection] = []
        var current: [ClipItem] = []
        var currentTitle: String?
        for item in items {
            let title = Self.dayTitle(item.createdAt)
            if title != currentTitle, let done = currentTitle {
                sections.append(DaySection(title: done, items: current))
                current = []
            }
            currentTitle = title
            current.append(item)
        }
        if let currentTitle { sections.append(DaySection(title: currentTitle, items: current)) }
        return sections
    }

    /// ⌃⌘0 … ⌃⌘9 always address the ten newest clips in the whole history.
    var shortcutIndex: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: store.items.prefix(10).enumerated().map { ($1.id, $0) })
    }

    var kindsPresent: [ClipKind] {
        let present = Set(store.items.map(\.kind))
        return ClipKind.allCases.filter(present.contains)
    }

    /// The most used source apps, for the app filter.
    var topApps: [AppSource] {
        var counts: [String: AppSource] = [:]
        for item in store.items {
            guard let id = item.sourceBundleID else { continue }
            counts[id, default: AppSource(bundleID: id, name: item.sourceAppName ?? id)].count += 1
        }
        return Array(counts.values.sorted { $0.count > $1.count }.prefix(8))
    }

    var isKindFilter: Bool {
        if case .kind = filter { return true }
        return false
    }

    var isAppFilter: Bool {
        if case .app = filter { return true }
        return false
    }

    var filterOptions: [ClipFilter] {
        [.all] + store.collections.map { .collection($0) }
    }

    var selectedItems: [ClipItem] {
        // Oldest first, so multi-clip pastes read in the order they were copied.
        visibleItems.filter { selection.contains($0.id) }.reversed()
    }

    var previewItem: ClipItem? {
        previewID.flatMap { id in store.items.first { $0.id == id } }
    }

    var cursorItem: ClipItem? {
        cursor.flatMap { id in store.items.first { $0.id == id } }
    }

    // MARK: - Navigation

    func prepareForShow() {
        query = ""
        isAddingCollection = false
        previewID = nil
        hoveredID = nil
        resetCursor()
        focusToken += 1
    }

    func resetCursor() {
        cursor = visibleItems.first?.id
        selection = cursor.map { Set([$0]) } ?? []
        if previewID != nil { previewID = cursor }
    }

    func move(_ delta: Int, extend: Bool) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let current = cursor.flatMap { id in items.firstIndex { $0.id == id } } ?? -1
        let next = max(0, min(items.count - 1, current + delta))
        let id = items[next].id
        cursor = id
        if extend { selection.insert(id) } else { selection = [id] }
        if previewID != nil { previewID = id }
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
        if previewID != nil { previewID = item.id }
    }

    func cycleFilter(_ delta: Int) {
        let options = filterOptions
        let index = options.firstIndex(of: filter) ?? 0
        filter = options[(index + delta + options.count) % options.count]
    }

    func togglePreview() {
        previewID = previewID == nil ? cursor : nil
    }

    func togglePreview(_ item: ClipItem) {
        if previewID == item.id {
            previewID = nil
        } else {
            cursor = item.id
            selection = [item.id]
            previewID = item.id
        }
    }

    // MARK: - Actions

    /// Context-menu actions apply to the whole selection if the clicked card is part of it.
    func targets(for item: ClipItem) -> [ClipItem] {
        selection.contains(item.id) ? selectedItems : [item]
    }

    func paste(_ items: [ClipItem]) { onPaste?(items) }
    func copy(_ items: [ClipItem]) { onCopy?(items) }
    func copyText(_ text: String) { onCopyText?(text) }

    func pasteSelection() {
        let items = selectedItems
        if !items.isEmpty { paste(items) }
    }

    func paste(at index: Int) {
        let items = visibleItems
        guard items.indices.contains(index) else { return }
        paste([items[index]])
    }

    func delete(_ items: [ClipItem]) {
        let ids = Set(items.map(\.id))
        let visible = visibleItems
        let firstIndex = visible.firstIndex { ids.contains($0.id) } ?? 0
        if let previewID, ids.contains(previewID) { self.previewID = nil }
        store.delete(ids)
        let remaining = visibleItems
        cursor = remaining.isEmpty ? nil : remaining[min(firstIndex, remaining.count - 1)].id
        selection = cursor.map { Set([$0]) } ?? []
    }

    func deleteSelection() {
        delete(visibleItems.filter { selection.contains($0.id) })
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
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return formatter
    }()

    static func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Heute" }
        if calendar.isDateInYesterday(date) { return "Gestern" }
        return dayFormatter.string(from: date)
    }

    /// Short ages that fit a card: "jetzt", "5 Min.", "3 Std.", "2 T.", "1 Wo."
    static func relativeTime(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        switch seconds {
        case ..<60: return "jetzt"
        case ..<3600: return "\(seconds / 60) Min."
        case ..<86_400: return "\(seconds / 3600) Std."
        case ..<604_800: return "\(seconds / 86_400) T."
        default: return "\(seconds / 604_800) Wo."
        }
    }
}
