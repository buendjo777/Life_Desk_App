import Foundation

/// Calendar maths and date formatting in the vault's time zone (`settings.timezone`).
/// Weeks start on Monday and week numbers are ISO 8601, as in the design.
struct DeskCalendar {
    let calendar: Calendar

    init(timeZone identifier: String) {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: identifier) ?? .current
        calendar.locale = Locale(identifier: "en_GB")
        self.calendar = calendar
    }

    func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    func add(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    func add(months: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date
    }

    /// Whole calendar days from `start` to `end`; negative when `end` is earlier.
    func days(from start: Date, to end: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(start), to: startOfDay(end)).day ?? 0
    }

    func isSameDay(_ a: Date, _ b: Date) -> Bool { calendar.isDate(a, inSameDayAs: b) }

    /// The Monday that starts the week of `date`.
    func weekStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(date)
    }

    func monthStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? startOfDay(date)
    }

    func weekNumber(_ date: Date) -> Int { calendar.component(.weekOfYear, from: date) }
    func day(_ date: Date) -> Int { calendar.component(.day, from: date) }
    func hour(_ date: Date) -> Int { calendar.component(.hour, from: date) }

    /// Hours since local midnight, as a fraction (08:30 → 8.5).
    func hours(_ date: Date) -> Double {
        date.timeIntervalSince(startOfDay(date)) / 3600
    }

    func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
    }

    /// Formats with a fixed pattern, e.g. `"EEE d MMM"` → "Wed 11 Nov".
    func format(_ date: Date, _ pattern: String, locale: String = "en_GB") -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: locale)
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    func time(_ date: Date) -> String { format(date, "HH:mm") }
    func shortDay(_ date: Date) -> String { format(date, "d MMM") }
    func weekdayDay(_ date: Date) -> String { format(date, "EEE d MMM") }

    /// "2026-11" style month key, as used by `payments.csv`.
    func monthKey(_ date: Date) -> String { format(date, "yyyy-MM") }
    /// "2026-11-11", as written back to the vault.
    func isoDay(_ date: Date) -> String { format(date, "yyyy-MM-dd") }

    /// ISO 8601 with the vault's offset, e.g. `2026-11-11T08:12:00+01:00`.
    func isoStamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

/// A date read from the vault: a day (`2026-11-12`) or a moment with an offset.
struct Stamp: Hashable {
    let date: Date
    let hasTime: Bool
}

extension CodingUserInfoKey {
    /// The `DeskCalendar` used to place date-only values in the vault's time zone.
    static let deskCalendar = CodingUserInfoKey(rawValue: "deskCalendar")!
}

extension Stamp: Decodable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        let calendar = decoder.userInfo[.deskCalendar] as? DeskCalendar ?? DeskCalendar(timeZone: "UTC")
        guard let stamp = Parse.stamp(raw, calendar) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not an ISO 8601 date: \(raw)"))
        }
        self = stamp
    }
}
