import Foundation
import XCTest
@testable import KXSFCore

/// Deterministic fixtures. Every instant is built from explicit America/Los_Angeles
/// wall-clock components or fixed UTC ISO strings, never from `Date()`.
final class KXSFTimeRangeParserTests: XCTestCase {
    private func parse(_ text: String) -> KXSFTimeRange? { KXSFTimeRangeParser.parse(text) }

    func test_parses_the_website_format() {
        XCTAssertEqual(parse("12:00 pm - 2:00 pm"), KXSFTimeRange(startMinute: 720, endMinute: 840))
        XCTAssertEqual(parse(" 4:00 pm - 6:00 pm "), KXSFTimeRange(startMinute: 960, endMinute: 1080))
    }

    func test_accepts_en_dash_em_dash_and_to() {
        let expected = KXSFTimeRange(startMinute: 600, endMinute: 780)
        XCTAssertEqual(parse("10:00 am – 1:00 pm"), expected)
        XCTAssertEqual(parse("10:00 am — 1:00 pm"), expected)
        XCTAssertEqual(parse("10:00 am to 1:00 pm"), expected)
        XCTAssertEqual(parse("10:00 am-1:00 pm"), expected)
    }

    func test_accepts_case_dots_and_hour_only_forms() {
        let expected = KXSFTimeRange(startMinute: 600, endMinute: 780)
        XCTAssertEqual(parse("10 AM - 1 PM"), expected)
        XCTAssertEqual(parse("10 a.m. - 1 p.m."), expected)
        XCTAssertEqual(parse("10am–1pm"), expected)
    }

    func test_accepts_non_breaking_and_narrow_spaces() {
        XCTAssertEqual(
            parse("10:00\u{202F}am\u{00A0}–\u{00A0}1:00\u{202F}pm"),
            KXSFTimeRange(startMinute: 600, endMinute: 780)
        )
    }

    func test_noon_and_midnight_use_twelve_hour_rules() {
        XCTAssertEqual(parse("12:00 am - 1:00 am"), KXSFTimeRange(startMinute: 0, endMinute: 60))
        XCTAssertEqual(parse("12:00 pm - 1:00 pm"), KXSFTimeRange(startMinute: 720, endMinute: 780))
        XCTAssertEqual(parse("11:00 am - 12:00 pm"), KXSFTimeRange(startMinute: 660, endMinute: 720))
    }

    func test_start_without_meridiem_inherits_the_end_meridiem_when_that_is_forward() {
        XCTAssertEqual(parse("12-2 p.m."), KXSFTimeRange(startMinute: 720, endMinute: 840))
        XCTAssertEqual(parse("3 - 5 pm"), KXSFTimeRange(startMinute: 900, endMinute: 1020))
    }

    func test_start_without_meridiem_flips_when_inheriting_would_run_backward() {
        // "10 - 1 pm": 10 pm would end before it starts, so 10 am is the only forward reading.
        XCTAssertEqual(parse("10 - 1 pm"), KXSFTimeRange(startMinute: 600, endMinute: 780))
        XCTAssertEqual(parse("11 - 1 pm"), KXSFTimeRange(startMinute: 660, endMinute: 780))
    }

    func test_overnight_range_is_flagged_and_measures_across_midnight() throws {
        let range = try XCTUnwrap(parse("10:00 pm - 2:00 am"))
        XCTAssertEqual(range, KXSFTimeRange(startMinute: 1320, endMinute: 120))
        XCTAssertTrue(range.crossesMidnight)
        XCTAssertEqual(range.durationMinutes, 240)
        XCTAssertEqual(try XCTUnwrap(parse("10:00 pm - 12:00 am")).durationMinutes, 120)
        XCTAssertFalse(try XCTUnwrap(parse("12:00 pm - 2:00 pm")).crossesMidnight)
    }

    func test_rejects_malformed_or_ambiguous_ranges() {
        let malformed = [
            "", "   ", "TBA", "Live", "1:00 pm",
            "10:00 - 11:00",            // no meridiem anywhere
            "13:00 pm - 2:00 pm",       // hour out of range
            "0:30 am - 1:00 am",        // hour 0 is not a 12-hour value
            "1:75 pm - 2:00 pm",        // minute out of range
            "1:00 pm - 1:00 pm",        // zero length; not guessing 24 hours
            "9 am - 10 pm - 11 pm",     // extra segment
            "noon - 2 pm",
        ]
        for text in malformed {
            XCTAssertNil(parse(text), "expected nil for \(text.debugDescription)")
        }
    }
}

final class KXSFUpNextTests: XCTestCase {
    private let la = TimeZone(identifier: "America/Los_Angeles")!

    private func instant(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0, _ s: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = la
        return calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    private func utc(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func show(
        _ name: String,
        _ day: KXSFWeekday,
        _ range: String,
        flagged: Bool = false
    ) -> KXSFShow {
        KXSFShow(
            day: day,
            name: name,
            timeRange: range,
            detailURL: URL(string: "https://kxsf.fm/shows/\(name.lowercased().replacingOccurrences(of: " ", with: "-"))/")!,
            artworkURL: nil,
            isNowPlaying: flagged
        )
    }

    private func schedule(_ shows: [KXSFShow]) -> KXSFSchedule {
        let grouped = Dictionary(grouping: shows, by: \.day)
        return KXSFSchedule(sections: KXSFWeekday.allCases.compactMap { day in
            grouped[day].map { KXSFScheduleSection(day: day, shows: $0) }
        })
    }

    /// Monday 2026-11-16 is a standard-time (PST) week.
    private var week: KXSFSchedule {
        schedule([
            show("Early", .monday, "8:00 am - 10:00 am"),
            show("Alpha", .monday, "10:00 am - 12:00 pm"),
            show("Bravo", .monday, "12:00 pm - 2:00 pm"),
            show("Charlie", .monday, "4:00 pm - 6:00 pm"),
            show("Delta", .tuesday, "10:00 am - 12:00 pm"),
            show("Night", .sunday, "10:00 pm - 2:00 am"),
        ])
    }

    private func nextName(_ at: Date, in schedule: KXSFSchedule? = nil) -> String? {
        if case let .next(occurrence) = KXSFUpNext.calculate(in: schedule ?? week, at: at) {
            return occurrence.show.name
        }
        return nil
    }

    // MARK: before / at start / at end

    func test_before_a_show_starts_the_next_show_is_that_show() {
        // 09:59:59 — Early is still on air; Alpha is next, not Early.
        XCTAssertEqual(nextName(instant(2026, 11, 16, 9, 59, 59)), "Alpha")
        // 07:59:59 — nothing on air yet; Early is next.
        XCTAssertEqual(nextName(instant(2026, 11, 16, 7, 59, 59)), "Early")
    }

    func test_at_the_exact_start_the_show_is_current_and_the_following_show_is_next() {
        let atStart = instant(2026, 11, 16, 10)
        XCTAssertEqual(KXSFUpNext.currentOccurrence(in: week, at: atStart)?.show.name, "Alpha")
        XCTAssertEqual(nextName(atStart), "Bravo")
    }

    func test_at_the_exact_end_the_show_is_over_and_never_next() {
        let atEnd = instant(2026, 11, 16, 12)
        XCTAssertEqual(KXSFUpNext.currentOccurrence(in: week, at: atEnd)?.show.name, "Bravo")
        XCTAssertEqual(nextName(atEnd), "Charlie")
        XCTAssertEqual(nextName(instant(2026, 11, 16, 11, 59, 59)), "Bravo")
    }

    func test_during_a_gap_nothing_is_current_and_the_next_show_is_the_following_start() {
        let gap = instant(2026, 11, 16, 15)
        XCTAssertNil(KXSFUpNext.currentOccurrence(in: week, at: gap))
        XCTAssertEqual(nextName(gap), "Charlie")
    }

    func test_already_aired_shows_today_are_never_next() {
        // 18:00 Monday: Early/Alpha/Bravo/Charlie all aired. Tuesday's Delta is next.
        XCTAssertEqual(nextName(instant(2026, 11, 16, 18)), "Delta")
        let occurrence = occurrenceAfter(instant(2026, 11, 16, 18))
        XCTAssertEqual(occurrence?.start, instant(2026, 11, 17, 10))
    }

    private func occurrenceAfter(_ date: Date, in schedule: KXSFSchedule? = nil) -> KXSFShowOccurrence? {
        if case let .next(occurrence) = KXSFUpNext.calculate(in: schedule ?? week, at: date) { return occurrence }
        return nil
    }

    // MARK: overnight

    func test_overnight_show_is_current_after_midnight_and_next_skips_it() {
        let sundayLate = instant(2026, 11, 15, 23)
        XCTAssertEqual(KXSFUpNext.currentOccurrence(in: week, at: sundayLate)?.show.name, "Night")
        XCTAssertEqual(nextName(sundayLate), "Early")

        let mondayOneAm = instant(2026, 11, 16, 1)
        XCTAssertEqual(KXSFUpNext.currentOccurrence(in: week, at: mondayOneAm)?.show.name, "Night")
        XCTAssertEqual(nextName(mondayOneAm), "Early")
    }

    func test_overnight_end_boundary_is_exclusive() {
        let atEnd = instant(2026, 11, 16, 2)
        XCTAssertNil(KXSFUpNext.currentOccurrence(in: week, at: atEnd))
        XCTAssertEqual(nextName(atEnd), "Early")
        XCTAssertEqual(KXSFUpNext.currentOccurrence(in: week, at: instant(2026, 11, 16, 1, 59, 59))?.show.name, "Night")
    }

    func test_overnight_show_is_attributed_to_its_start_day_and_ends_on_the_next_date() throws {
        let occurrence = try XCTUnwrap(KXSFUpNext.currentOccurrence(in: week, at: instant(2026, 11, 15, 23)))
        XCTAssertEqual(occurrence.start, instant(2026, 11, 15, 22))
        XCTAssertEqual(occurrence.end, instant(2026, 11, 16, 2))
    }

    // MARK: week wrap

    func test_sunday_night_wraps_to_monday() {
        let only = schedule([show("Early", .monday, "8:00 am - 10:00 am"), show("Late", .sunday, "6:00 pm - 8:00 pm")])
        XCTAssertEqual(nextName(instant(2026, 11, 15, 20, 30), in: only), "Early")
        XCTAssertEqual(occurrenceAfter(instant(2026, 11, 15, 20, 30), in: only)?.start, instant(2026, 11, 16, 8))
    }

    func test_the_only_weekly_show_recurs_next_week() throws {
        let only = schedule([show("Early", .monday, "8:00 am - 10:00 am")])
        let during = instant(2026, 11, 16, 9)
        XCTAssertEqual(KXSFUpNext.currentOccurrence(in: only, at: during)?.show.name, "Early")
        XCTAssertEqual(occurrenceAfter(during, in: only)?.start, instant(2026, 11, 23, 8))
    }

    func test_saturday_to_sunday_wrap_across_a_month_boundary() {
        let s = schedule([show("Sun", .sunday, "9:00 am - 10:00 am")])
        // Saturday 2026-10-31 → Sunday 2026-11-01 (also the fall-back day).
        XCTAssertEqual(occurrenceAfter(instant(2026, 10, 31, 12), in: s)?.start, instant(2026, 11, 1, 9))
    }

    // MARK: station time zone

    func test_station_weekday_follows_los_angeles_not_utc() {
        // 2026-11-17T03:00Z is still Monday 19:00 in Los Angeles.
        let now = utc("2026-11-17T03:00:00Z")
        XCTAssertEqual(KXSFStationClock.weekday(of: now), .monday)
        let s = schedule([
            show("Charlie", .monday, "4:00 pm - 6:00 pm"),
            show("Late", .monday, "8:00 pm - 9:00 pm"),
            show("Delta", .tuesday, "10:00 am - 12:00 pm"),
        ])
        XCTAssertEqual(nextName(now, in: s), "Late")
        XCTAssertEqual(occurrenceAfter(now, in: s)?.start, utc("2026-11-17T04:00:00Z"))
    }

    // MARK: DST

    func test_spring_forward_measures_wall_clock_ranges() throws {
        // 2026-03-08: 02:00 PST jumps to 03:00 PDT.
        let s = schedule([
            show("Before", .sunday, "12:00 am - 1:00 am"),
            show("Bridge", .sunday, "1:00 am - 3:00 am"),
            show("After", .sunday, "3:00 am - 4:00 am"),
        ])
        let bridge = try XCTUnwrap(KXSFUpNext.currentOccurrence(in: s, at: utc("2026-03-08T09:30:00Z")))
        XCTAssertEqual(bridge.show.name, "Bridge")
        XCTAssertEqual(bridge.start, utc("2026-03-08T09:00:00Z"))
        XCTAssertEqual(bridge.end, utc("2026-03-08T10:00:00Z")) // only one real hour long
        XCTAssertEqual(nextName(utc("2026-03-08T09:30:00Z"), in: s), "After")
        XCTAssertEqual(occurrenceAfter(utc("2026-03-08T09:30:00Z"), in: s)?.start, utc("2026-03-08T10:00:00Z"))
    }

    func test_fall_back_hour_does_not_confuse_current_or_next() throws {
        // 2026-11-01: 02:00 PDT repeats to 01:00 PST. Both 01:30s are inside "Long".
        let s = schedule([
            show("Long", .sunday, "12:00 am - 3:00 am"),
            show("After", .sunday, "3:00 am - 4:00 am"),
        ])
        for iso in ["2026-11-01T08:30:00Z", "2026-11-01T09:30:00Z"] {
            XCTAssertEqual(KXSFUpNext.currentOccurrence(in: s, at: utc(iso))?.show.name, "Long", iso)
            XCTAssertEqual(nextName(utc(iso), in: s), "After", iso)
        }
        let long = try XCTUnwrap(KXSFUpNext.currentOccurrence(in: s, at: utc("2026-11-01T09:30:00Z")))
        XCTAssertEqual(long.start, utc("2026-11-01T07:00:00Z"))
        XCTAssertEqual(long.end, utc("2026-11-01T11:00:00Z")) // four real hours
    }

    // MARK: unavailable / malformed

    func test_empty_schedule_is_unavailable() {
        XCTAssertEqual(KXSFUpNext.calculate(in: KXSFSchedule(sections: []), at: instant(2026, 11, 16, 9)), .unavailable)
    }

    func test_all_malformed_ranges_are_unavailable_not_invented() {
        let s = schedule([show("Mystery", .monday, "TBA"), show("Other", .tuesday, "")])
        XCTAssertEqual(KXSFUpNext.calculate(in: s, at: instant(2026, 11, 16, 9)), .unavailable)
    }

    func test_one_unreadable_show_makes_up_next_unavailable_instead_of_guessing() {
        let s = schedule([
            show("Alpha", .monday, "10:00 am - 12:00 pm"),
            show("Mystery", .monday, "sometime"),
            show("Charlie", .monday, "4:00 pm - 6:00 pm"),
        ])
        XCTAssertEqual(KXSFUpNext.calculate(in: s, at: instant(2026, 11, 16, 9)), .unavailable)
    }

    // MARK: website flag disagreement

    func test_a_show_the_website_flags_as_on_air_is_never_returned_as_up_next() {
        // Clock says Alpha has not started yet, website says it is on air (stale clock / cache).
        let s = schedule([
            show("Alpha", .monday, "10:00 am - 12:00 pm", flagged: true),
            show("Bravo", .monday, "12:00 pm - 2:00 pm"),
        ])
        XCTAssertEqual(nextName(instant(2026, 11, 16, 9, 58), in: s), "Bravo")
    }

    // MARK: upcoming list

    func test_upcoming_lists_following_shows_in_order_beginning_with_next() {
        let list = KXSFUpNext.upcoming(in: week, at: instant(2026, 11, 16, 11), limit: 3)
        XCTAssertEqual(list.map(\.show.name), ["Bravo", "Charlie", "Delta"])
        XCTAssertEqual(list.map(\.start), list.map(\.start).sorted())
    }

    func test_upcoming_is_empty_when_unavailable() {
        XCTAssertTrue(KXSFUpNext.upcoming(in: KXSFSchedule(sections: []), at: instant(2026, 11, 16, 11), limit: 3).isEmpty)
    }

    // MARK: partially invalid real-world data

    /// The live Monday listing: Blue Lew Show is displayed as "2:00 pm - 2:00 pm".
    private var liveMonday: KXSFSchedule {
        schedule([
            show("Morning", .monday, "10:00 am - 12:00 pm"),
            show("Bravo", .monday, "12:00 pm - 2:00 pm"),
            show("Blue Lew Show", .monday, "2:00 pm - 2:00 pm"),
            show("Later", .monday, "4:00 pm - 6:00 pm"),
            show("Delta", .tuesday, "10:00 am - 12:00 pm"),
        ])
    }

    func test_start_parser_reads_explicit_start_of_unusable_ranges_without_inventing_an_end() {
        XCTAssertNil(KXSFTimeRangeParser.parse("2:00 pm - 2:00 pm"))
        XCTAssertEqual(KXSFTimeRangeParser.parseStart("2:00 pm - 2:00 pm"), 14 * 60)
        XCTAssertEqual(KXSFTimeRangeParser.parseStart("2:00 pm - 4:00"), 14 * 60)
        XCTAssertEqual(KXSFTimeRangeParser.parseStart("12:00 pm - 2:00 pm"), 12 * 60)
        for text in ["", "TBA", "2 - 2", "sometime", "13:00 pm - 2:00 pm", "2:75 pm - 3:00 pm"] {
            XCTAssertNil(KXSFTimeRangeParser.parseStart(text), text)
        }
    }

    func test_live_zero_length_entry_does_not_disable_up_next_before_it() {
        XCTAssertEqual(nextName(instant(2026, 11, 16, 11), in: liveMonday), "Bravo")
        // During Bravo the next show is the show with the known start, Blue Lew, end not invented.
        let bravoTime = instant(2026, 11, 16, 13)
        let next = occurrenceAfter(bravoTime, in: liveMonday)
        XCTAssertEqual(next?.show.name, "Blue Lew Show")
        XCTAssertEqual(next?.start, instant(2026, 11, 16, 14))
        XCTAssertNil(next?.end)
        XCTAssertFalse(KXSFUpNext.isCurrentShowUncertain(in: liveMonday, at: bravoTime))
    }

    func test_after_a_start_only_show_begins_current_is_uncertain_but_later_start_is_next() {
        let during = instant(2026, 11, 16, 15)
        XCTAssertNil(KXSFUpNext.currentOccurrence(in: liveMonday, at: during))
        XCTAssertTrue(KXSFUpNext.isCurrentShowUncertain(in: liveMonday, at: during))
        XCTAssertEqual(nextName(during, in: liveMonday), "Later")
        XCTAssertEqual(KXSFUpNext.upcoming(in: liveMonday, at: during, limit: 2).map(\.show.name), ["Later", "Delta"])
        // The week recurs, so the third following show is next Monday's Morning.
        XCTAssertEqual(KXSFUpNext.upcoming(in: liveMonday, at: during, limit: 3).map(\.show.name), ["Later", "Delta", "Morning"])
    }

    func test_unreadable_entry_on_an_unrelated_day_does_not_affect_today() {
        let s = schedule([
            show("Alpha", .monday, "10:00 am - 12:00 pm"),
            show("Bravo", .monday, "12:00 pm - 2:00 pm"),
            show("Broken", .thursday, "TBA"),
        ])
        XCTAssertEqual(nextName(instant(2026, 11, 16, 11), in: s), "Bravo")
        XCTAssertEqual(KXSFUpNext.upcoming(in: s, at: instant(2026, 11, 16, 9), limit: 5).map(\.show.name), ["Alpha", "Bravo"])
        // Thursday is unprovable, so nothing after it (next week's Alpha) is offered.
    }

    func test_upcoming_is_truncated_before_an_unreadable_day() {
        let s = schedule([
            show("Alpha", .monday, "10:00 am - 12:00 pm"),
            show("Bravo", .monday, "12:00 pm - 2:00 pm"),
            show("Broken", .tuesday, "TBA"),
            show("Delta", .tuesday, "6:00 pm - 7:00 pm"),
            show("Wed", .wednesday, "9:00 am - 10:00 am"),
        ])
        // Monday shows are certain; Tuesday's Delta and later cannot be ordered against Broken.
        XCTAssertEqual(KXSFUpNext.upcoming(in: s, at: instant(2026, 11, 16, 9), limit: 10).map(\.show.name), ["Alpha", "Bravo"])
        // After Monday's last show only Tuesday remains, and it is unprovable.
        XCTAssertEqual(KXSFUpNext.calculate(in: s, at: instant(2026, 11, 16, 15)), .unavailable)
    }

    func test_malformed_current_entry_makes_next_unavailable_but_is_reported_uncertain() {
        let s = schedule([
            show("Alpha", .monday, "10:00 am - 12:00 pm"),
            show("Mystery", .monday, "sometime"),
            show("Delta", .tuesday, "10:00 am - 12:00 pm"),
        ])
        let now = instant(2026, 11, 16, 12, 30)
        XCTAssertNil(KXSFUpNext.currentOccurrence(in: s, at: now))
        XCTAssertTrue(KXSFUpNext.isCurrentShowUncertain(in: s, at: now))
        XCTAssertEqual(KXSFUpNext.calculate(in: s, at: now), .unavailable)
        // Once Monday is over, Tuesday is justified again.
        XCTAssertEqual(nextName(instant(2026, 11, 17, 0, 30), in: s), "Delta")
    }

    func test_next_day_start_only_show_is_next_after_the_last_show_today() {
        XCTAssertEqual(nextName(instant(2026, 11, 16, 19), in: liveMonday), "Delta")
    }

    func test_los_angeles_clock_applies_to_malformed_schedules_regardless_of_device_zone() {
        // 2026-11-16T21:30:00Z is Monday 13:30 in Los Angeles (Bravo on air).
        let now = utc("2026-11-16T21:30:00Z")
        let next = occurrenceAfter(now, in: liveMonday)
        XCTAssertEqual(next?.show.name, "Blue Lew Show")
        XCTAssertEqual(next?.start, utc("2026-11-16T22:00:00Z"))
        // 2026-11-17T01:00:00Z is still Monday 17:00 in Los Angeles, not Tuesday.
        XCTAssertEqual(KXSFStationClock.weekday(of: utc("2026-11-17T01:00:00Z")), .monday)
        XCTAssertEqual(nextName(utc("2026-11-17T01:00:00Z"), in: liveMonday), "Delta")
    }

    func test_station_clock_weekday_boundaries() {
        XCTAssertEqual(KXSFStationClock.weekday(of: instant(2026, 11, 16, 0)), .monday)
        XCTAssertEqual(KXSFStationClock.weekday(of: instant(2026, 11, 15, 23, 59, 59)), .sunday)
    }
}
