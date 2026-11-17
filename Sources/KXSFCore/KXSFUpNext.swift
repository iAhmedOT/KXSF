import Foundation

// MARK: - Source assumptions (explicit)
//
// 1. `KXSFShow.timeRange` is display text copied from kxsf.fm, e.g. "12:00 pm - 2:00 pm".
//    It carries no date and no time zone.
// 2. Times are station wall-clock time in America/Los_Angeles, regardless of device zone.
// 3. A show listed under a weekday recurs every week on that weekday.
// 4. A range whose end is at or before its start crosses midnight and ends on the next
//    calendar date (e.g. "10:00 pm - 2:00 am"). It belongs to the day it starts on.
// 5. Start is inclusive and end is exclusive: at the exact start the show is current,
//    at the exact end it is over.
// 6. Wall-clock times are resolved with the Gregorian calendar in the station zone, so a
//    "1:00 am - 3:00 am" show is one real hour on spring-forward night and a
//    "12:00 am - 3:00 am" show is four real hours on fall-back night.
// 7. Each entry is judged on its own; one bad entry never disables the whole schedule.
//    - Fully readable: start and end are known.
//    - Start-only (e.g. the live "2:00 pm - 2:00 pm", or an end with no am/pm): the start
//      is stated explicitly but the end is not. The end is NEVER invented (`end == nil`).
//      Such a show can be reported as upcoming (its start is known), but once it has
//      started the current show is uncertain. Assumes shows do not overlap, so the first
//      known start after now is still the next show.
//    - Unreadable: only the weekday is known. It might start any time that day, so no
//      show is presented as "next" if it starts after the beginning of that day while now
//      is before the end of that day. The result is `.unavailable` or the upcoming list is
//      truncated at that point rather than guessed.
//    Limit: an unreadable entry is assumed not to run past midnight into the next day.

/// Minutes after midnight for a parsed `timeRange`.
public struct KXSFTimeRange: Sendable, Equatable {
    public let startMinute: Int
    public let endMinute: Int

    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    public var crossesMidnight: Bool { endMinute <= startMinute }

    public var durationMinutes: Int {
        crossesMidnight ? (1440 - startMinute) + endMinute : endMinute - startMinute
    }
}

public enum KXSFTimeRangeParser {
    /// Returns nil for anything that is not an unambiguous start/end pair.
    public static func parse(_ text: String) -> KXSFTimeRange? {
        let normalized = text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{2009}", with: " ")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        let separator = "(?:\\s*[-\u{2012}\u{2013}\u{2014}\u{2015}\u{2212}]\\s*|\\s+to\\s+)"
        let clock = "(\\d{1,2})(?::(\\d{2}))?\\s*(?:([ap])\\.?m?\\.?)?"
        let pattern = "^\(clock)\(separator)\(clock)$"
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized))
        else { return nil }

        func capture(_ index: Int) -> String? {
            Range(match.range(at: index), in: normalized).map { String(normalized[$0]) }
        }
        guard
            let startHour = capture(1).flatMap(Int.init),
            let endHour = capture(4).flatMap(Int.init),
            let endMeridiem = capture(6).flatMap(Meridiem.init)
        else { return nil } // the end must say am or pm
        let startMinutePart = capture(2).flatMap(Int.init) ?? 0
        let endMinutePart = capture(5).flatMap(Int.init) ?? 0
        guard
            (1...12).contains(startHour), (1...12).contains(endHour),
            (0..<60).contains(startMinutePart), (0..<60).contains(endMinutePart)
        else { return nil }

        let end = minutes(hour: endHour, minute: endMinutePart, meridiem: endMeridiem)
        let start: Int
        if let explicit = capture(3).flatMap(Meridiem.init) {
            start = minutes(hour: startHour, minute: startMinutePart, meridiem: explicit)
        } else {
            // "12-2 p.m.": inherit the end meridiem when that reads forward in time,
            // otherwise use the opposite ("10 - 1 pm" means 10 am).
            let inherited = minutes(hour: startHour, minute: startMinutePart, meridiem: endMeridiem)
            if inherited < end {
                start = inherited
            } else {
                start = minutes(hour: startHour, minute: startMinutePart, meridiem: endMeridiem.opposite)
            }
        }
        guard start != end else { return nil } // zero length; do not guess 24 hours
        return KXSFTimeRange(startMinute: start, endMinute: end)
    }

    /// Start minute when the start is stated with an explicit am/pm even if the range as a
    /// whole is unusable, e.g. "2:00 pm - 2:00 pm" or "2:00 pm - 4:00".
    public static func parseStart(_ text: String) -> Int? {
        if let range = parse(text) { return range.startMinute }
        let normalized = text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{2009}", with: " ")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = "(?:\\s*[-\u{2012}\u{2013}\u{2014}\u{2015}\u{2212}]\\s*|\\s+to\\s+)"
        let pattern = "^(\\d{1,2})(?::(\\d{2}))?\\s*([ap])\\.?m?\\.?\(separator)(\\d{1,2})(?::(\\d{2}))?\\s*(?:[ap]\\.?m?\\.?)?$"
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized))
        else { return nil }
        func capture(_ index: Int) -> String? {
            Range(match.range(at: index), in: normalized).map { String(normalized[$0]) }
        }
        guard
            let hour = capture(1).flatMap(Int.init), (1...12).contains(hour),
            let meridiem = capture(3).flatMap(Meridiem.init)
        else { return nil }
        let minute = capture(2).flatMap(Int.init) ?? 0
        guard (0..<60).contains(minute) else { return nil }
        if let endHour = capture(4).flatMap(Int.init), !(1...12).contains(endHour) { return nil }
        if let endMinute = capture(5).flatMap(Int.init), !(0..<60).contains(endMinute) { return nil }
        return minutes(hour: hour, minute: minute, meridiem: meridiem)
    }

    private enum Meridiem {
        case am, pm
        init?(_ letter: String) {
            switch letter {
            case "a": self = .am
            case "p": self = .pm
            default: return nil
            }
        }
        var opposite: Meridiem { self == .am ? .pm : .am }
    }

    private static func minutes(hour: Int, minute: Int, meridiem: Meridiem) -> Int {
        let hour24 = (hour % 12) + (meridiem == .pm ? 12 : 0)
        return hour24 * 60 + minute
    }
}

/// Station time (America/Los_Angeles).
public enum KXSFStationClock {
    public static let timeZone = TimeZone(identifier: "America/Los_Angeles")!

    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    public static func weekday(of date: Date) -> KXSFWeekday {
        weekday(fromCalendarWeekday: calendar.component(.weekday, from: date))
    }

    static func weekday(fromCalendarWeekday value: Int) -> KXSFWeekday {
        switch value {
        case 1: .sunday
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        default: .saturday
        }
    }
}

public struct KXSFShowOccurrence: Sendable, Equatable {
    public let show: KXSFShow
    public let start: Date
    /// nil when the station's range does not state a usable end. Never guessed.
    public let end: Date?

    public init(show: KXSFShow, start: Date, end: Date?) {
        self.show = show
        self.start = start
        self.end = end
    }
}

public enum KXSFUpNextResult: Sendable, Equatable {
    case next(KXSFShowOccurrence)
    case unavailable
}

public enum KXSFUpNext {
    /// The first show that starts strictly after `date` and after the current show ends.
    public static func calculate(in schedule: KXSFSchedule, at date: Date) -> KXSFUpNextResult {
        upcomingResult(in: schedule, at: date, limit: 1).first.map(KXSFUpNextResult.next) ?? .unavailable
    }

    /// Following shows in start order; the first element is the Up Next show.
    public static func upcoming(in schedule: KXSFSchedule, at date: Date, limit: Int) -> [KXSFShowOccurrence] {
        upcomingResult(in: schedule, at: date, limit: limit)
    }

    /// The occurrence with a known end whose `[start, end)` contains `date`.
    /// Start-only entries are never returned because they cannot be confirmed.
    public static func currentOccurrence(in schedule: KXSFSchedule, at date: Date) -> KXSFShowOccurrence? {
        guard let model = model(in: schedule, around: date) else { return nil }
        return model.known
            .filter { occurrence in occurrence.end.map { occurrence.start <= date && date < $0 } ?? false }
            .max { $0.start < $1.start }
    }

    /// True when the clock cannot confirm what is on air: a start-only show has begun
    /// (end unknown) or an unreadable entry exists for today, and no fully-known show
    /// is confirmed current.
    public static func isCurrentShowUncertain(in schedule: KXSFSchedule, at date: Date) -> Bool {
        guard let model = model(in: schedule, around: date) else { return false }
        if currentOccurrence(in: schedule, at: date) != nil { return false }
        if model.windows.contains(where: { $0.start <= date && date < $0.end }) { return true }
        guard let latestStarted = model.known.filter({ $0.start <= date }).max(by: { $0.start < $1.start }) else {
            return false
        }
        return latestStarted.end == nil
    }

    private static func upcomingResult(in schedule: KXSFSchedule, at date: Date, limit: Int) -> [KXSFShowOccurrence] {
        guard limit > 0, let model = model(in: schedule, around: date) else { return [] }
        let all = model.known

        // Nothing may be returned that starts before the current show is over.
        let currentEnd = all
            .filter { occurrence in occurrence.end.map { occurrence.start <= date && date < $0 } ?? false }
            .compactMap(\.end).max()
        var upcoming = all
            .filter { occurrence in
                occurrence.start > date && (currentEnd.map { occurrence.start >= $0 } ?? true)
            }
            .sorted { $0.start < $1.start }

        // The website flags a show as on air but the clock does not place it on air
        // (stale cache or a wrong device clock): never present that show as "next".
        if currentEnd == nil, let flagged = schedule.currentShow,
           let index = upcoming.firstIndex(where: { $0.show.day == flagged.day && $0.show.id == flagged.id }) {
            upcoming.remove(at: index)
        }
        // An unreadable entry may start any time on its day; stop before anything it could precede.
        let justified = upcoming.prefix { occurrence in
            !model.windows.contains { $0.start < occurrence.start && $0.end > date }
        }
        return Array(justified.prefix(limit))
    }

    private struct Model {
        var known: [KXSFShowOccurrence]
        var windows: [(start: Date, end: Date)]
    }

    private enum Entry {
        case full(KXSFTimeRange)
        case startOnly(Int)
        case unknown
    }

    /// Occurrences from yesterday through a week ahead plus unknown-time day windows;
    /// nil when the schedule is empty.
    private static func model(in schedule: KXSFSchedule, around date: Date) -> Model? {
        let shows = schedule.shows
        guard !shows.isEmpty else { return nil }
        let entries: [(KXSFShow, Entry)] = shows.map { show in
            if let range = KXSFTimeRangeParser.parse(show.timeRange) { return (show, .full(range)) }
            if let start = KXSFTimeRangeParser.parseStart(show.timeRange) { return (show, .startOnly(start)) }
            return (show, .unknown)
        }

        let calendar = KXSFStationClock.calendar
        let today = calendar.startOfDay(for: date)
        var known: [KXSFShowOccurrence] = []
        var windows: [(start: Date, end: Date)] = []
        for offset in -1...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
            let weekday = KXSFStationClock.weekday(fromCalendarWeekday: calendar.component(.weekday, from: day))
            for (show, entry) in entries where show.day == weekday {
                switch entry {
                case let .full(range):
                    guard
                        let start = wallClock(day, minute: range.startMinute, dayOffset: 0, calendar: calendar),
                        let end = wallClock(day, minute: range.endMinute, dayOffset: range.crossesMidnight ? 1 : 0, calendar: calendar),
                        end > start
                    else { continue }
                    known.append(KXSFShowOccurrence(show: show, start: start, end: end))
                case let .startOnly(minute):
                    guard let start = wallClock(day, minute: minute, dayOffset: 0, calendar: calendar) else { continue }
                    known.append(KXSFShowOccurrence(show: show, start: start, end: nil))
                case .unknown:
                    windows.append((day, nextDay))
                }
            }
        }
        return Model(known: known, windows: windows)
    }

    private static func wallClock(_ day: Date, minute: Int, dayOffset: Int, calendar: Calendar) -> Date? {
        guard let base = calendar.date(byAdding: .day, value: dayOffset, to: day) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: base)
        components.hour = minute / 60
        components.minute = minute % 60
        return calendar.date(from: components)
    }
}
