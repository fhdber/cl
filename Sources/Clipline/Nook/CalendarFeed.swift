import AppKit
import Combine
import EventKit

/// Today's (or a chosen day's) events for the calendar widget.
final class CalendarFeed: ObservableObject {
    static let shared = CalendarFeed()

    enum Access { case unknown, granted, denied }

    struct DayEvent: Identifiable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let color: NSColor
    }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var day = Calendar.current.startOfDay(for: Date())
    @Published private(set) var events: [DayEvent] = []

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?

    func activate() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            access = .granted
            reload()
        case .notDetermined:
            store.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async {
                    self.access = granted ? .granted : .denied
                    if granted { self.reload() }
                }
            }
        default:
            access = .denied
        }
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store,
                                                              queue: .main) { [weak self] _ in self?.reload() }
        }
    }

    func shift(days: Int) {
        day = Calendar.current.date(byAdding: .day, value: days, to: day) ?? day
        reload()
    }

    func goToToday() {
        day = Calendar.current.startOfDay(for: Date())
        reload()
    }

    private func reload() {
        guard access == .granted else { return }
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        let predicate = store.predicateForEvents(withStart: day, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                DayEvent(id: (event.eventIdentifier ?? UUID().uuidString) + "\(event.startDate.timeIntervalSince1970)",
                         title: event.title ?? "Termin",
                         start: event.startDate,
                         end: event.endDate,
                         isAllDay: event.isAllDay,
                         color: event.calendar?.color ?? .systemBlue)
            }
    }
}
