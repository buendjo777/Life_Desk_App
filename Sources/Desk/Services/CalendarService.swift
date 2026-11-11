import EventKit
import Foundation

/// Where Live mode gets calendar events and adds one on Jose's click. Demo never uses it.
@MainActor
protocol CalendarSource: AnyObject {
    /// Asks for full access once. Returns whether Desk may read the calendar.
    func requestAccess() async -> Bool
    func events(from start: Date, to end: Date) -> [CalEvent]
    /// Creates an event with a title and times only.
    func add(title: String, start: Date, end: Date, allDay: Bool) throws
}

/// EventKit, using the accounts already on the Mac. Desk holds no calendar credentials.
@MainActor
final class EventKitCalendar: CalendarSource {
    private let store = EKEventStore()

    func requestAccess() async -> Bool {
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess { return true }
        return (try? await store.requestFullAccessToEvents()) ?? false
    }

    func events(from start: Date, to end: Date) -> [CalEvent] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { event in
            CalEvent(id: "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
                     calendar: event.calendar?.title ?? "", title: event.title ?? "",
                     start: event.startDate, end: event.endDate, allDay: event.isAllDay, location: event.location)
        }
    }

    /// Title and times only: no notes, links, locations or attendees. EventKit cannot add
    /// participants at all, so no invitation can leave Jose's account.
    func add(title: String, start: Date, end: Date, allDay: Bool) throws {
        guard let calendar = store.defaultCalendarForNewEvents else {
            throw Git.Failure(message: "No default calendar to add the event to.")
        }
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = end
        event.isAllDay = allDay
        try store.save(event, span: .thisEvent)
    }
}
