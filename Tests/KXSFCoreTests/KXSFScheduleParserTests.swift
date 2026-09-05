import Foundation
import XCTest
@testable import KXSFCore

final class KXSFScheduleParserTests: XCTestCase {
    private let fixture = """
    <h3 class="proradio-schedule__dayname">Monday</h3>
    <article class="proradio-post proradio-post__card--shows">
      <div class="proradio-bgimg">
        <img src="https://kxsf.fm/wp-content/uploads/moon-wax.jpg" alt="Moon Wax Radio" />
      </div>
      <div class="proradio-post__headercont">
        <h5 class="proradio-tag-nowplaying"><span>Now playing</span></h5>
        <a class="proradio-post__header__link" href="https://kxsf.fm/shows/moon-wax-radio/"></a>
        <h3 class="proradio-post__title"><a href="https://kxsf.fm/shows/moon-wax-radio/">Moon Wax &amp; Friends</a></h3>
        <p class="proradio-itemmetas"> 12:00 pm - 2:00 pm </p>
      </div>
    </article>
    <article class="proradio-post proradio-post__card--shows">
      <a class="proradio-post__header__link" href="https://kxsf.fm/shows/power-machine/"></a>
      <h3 class="proradio-post__title"><a href="https://kxsf.fm/shows/power-machine/">Power Machine</a></h3>
      <p class="proradio-itemmetas"> 4:00 pm - 6:00 pm </p>
    </article>
    <h3 class="proradio-schedule__dayname">Tuesday</h3>
    <article class="proradio-post proradio-post__card--shows">
      <img src="https://kxsf.fm/wp-content/uploads/freefall.png" alt="FreeFall" />
      <a class="proradio-post__header__link" href="https://kxsf.fm/shows/freefall/"></a>
      <h3 class="proradio-post__title"><a href="https://kxsf.fm/shows/freefall/">FreeFall</a></h3>
      <p class="proradio-itemmetas"> 10:00 am - 12:00 pm </p>
    </article>
    """

    func test_parses_weekday_show_metadata_and_artwork() throws {
        let schedule = KXSFScheduleParser.schedule(in: fixture)

        XCTAssertEqual(schedule.shows.count, 3)
        let show = try XCTUnwrap(schedule.shows.first)
        XCTAssertEqual(show.day, .monday)
        XCTAssertEqual(show.name, "Moon Wax & Friends")
        XCTAssertEqual(show.timeRange, "12:00 pm - 2:00 pm")
        XCTAssertEqual(show.detailURL.absoluteString, "https://kxsf.fm/shows/moon-wax-radio/")
        XCTAssertEqual(show.artworkURL?.absoluteString, "https://kxsf.fm/wp-content/uploads/moon-wax.jpg")
        XCTAssertTrue(show.isNowPlaying)
    }

    func test_groups_shows_in_website_weekday_order() {
        let schedule = KXSFScheduleParser.schedule(in: fixture)

        XCTAssertEqual(schedule.sections.map(\.day), [.monday, .tuesday])
        XCTAssertEqual(schedule.sections[0].shows.map(\.name), ["Moon Wax & Friends", "Power Machine"])
        XCTAssertEqual(schedule.sections[1].shows.map(\.name), ["FreeFall"])
    }

    func test_exposes_the_current_show_with_artwork() {
        let schedule = KXSFScheduleParser.schedule(in: fixture)

        XCTAssertEqual(schedule.currentShow?.name, "Moon Wax & Friends")
        XCTAssertEqual(
            schedule.currentShow?.artworkURL?.absoluteString,
            "https://kxsf.fm/wp-content/uploads/moon-wax.jpg"
        )
    }

    func test_decodes_numeric_entities_and_collapses_irregular_whitespace() throws {
        let html = """
        <h3 class="proradio-schedule__dayname">Friday</h3>
        <article class="proradio-post proradio-post__card--shows">
          <a class="proradio-post__header__link" href="https://kxsf.fm/shows/frequency-uplift/"></a>
          <h3 class="proradio-post__title"><a href="https://kxsf.fm/shows/frequency-uplift/">  Frequency&nbsp; Uplift! Fridays, 10 am &#8211; 1 pm  </a></h3>
          <p class="proradio-itemmetas"> 10:00 am &#x2013; 1:00 pm </p>
        </article>
        """

        let show = try XCTUnwrap(KXSFScheduleParser.schedule(in: html).shows.first)
        XCTAssertEqual(show.name, "Frequency Uplift!")
        XCTAssertEqual(show.timeRange, "10:00 am – 1:00 pm")
    }

    func test_removes_website_schedule_suffix_without_changing_a_real_weekday_title() {
        let titles = [
            "Shadrack’s Inferno: Mondays, 12-2 p.m.",
            "Pasco’s Perspective. Tuesday, 3PM – #SPORTS #LOCAL",
            "KXSF Live! Sundays 3 PM",
            "Sunday Morning Coming Down",
        ]
        let articles = titles.enumerated().map { index, title in
            """
            <article class="proradio-post proradio-post__card--shows">
              <a class="proradio-post__header__link" href="https://kxsf.fm/shows/test-\(index)/"></a>
              <h3 class="proradio-post__title"><a>\(title)</a></h3>
              <p class="proradio-itemmetas"> 1:00 pm - 2:00 pm </p>
            </article>
            """
        }.joined()
        let html = "<h3 class=\"proradio-schedule__dayname\">Sunday</h3>" + articles

        XCTAssertEqual(
            KXSFScheduleParser.schedule(in: html).shows.map(\.name),
            ["Shadrack’s Inferno", "Pasco’s Perspective", "KXSF Live!", "Sunday Morning Coming Down"]
        )
    }

    func test_prioritizes_current_show_for_host_enrichment() {
        let archived = KXSFShow(
            day: .monday,
            name: "Archived",
            timeRange: "1:00 pm - 2:00 pm",
            detailURL: URL(string: "https://kxsf.fm/shows/archived/")!,
            artworkURL: nil,
            isNowPlaying: false
        )
        let current = KXSFShow(
            day: .friday,
            name: "Around the World",
            timeRange: "8:00 pm - 10:00 pm",
            detailURL: URL(string: "https://kxsf.fm/shows/around-the-world/")!,
            artworkURL: nil,
            isNowPlaying: true
        )
        let schedule = KXSFSchedule(sections: [
            KXSFScheduleSection(day: .monday, shows: [archived]),
            KXSFScheduleSection(day: .friday, shows: [current]),
        ])

        XCTAssertEqual(schedule.showsPrioritizingCurrent().map(\.name), ["Around the World", "Archived"])
    }

    func test_enriches_hosts_without_changing_other_show_metadata() throws {
        let schedule = KXSFScheduleParser.schedule(in: fixture)
        let current = try XCTUnwrap(schedule.currentShow)

        let enriched = schedule.enrichingHosts([current.detailURL: "DJ Casanova"])
        XCTAssertEqual(enriched.currentShow?.hostName, "DJ Casanova")
        XCTAssertEqual(enriched.currentShow?.name, current.name)
        XCTAssertEqual(enriched.currentShow?.timeRange, current.timeRange)
        XCTAssertEqual(enriched.currentShow?.artworkURL, current.artworkURL)
    }

    func test_splits_title_embedded_host_and_recovers_dj_from_noisy_blurb() {
        let show = KXSFShow(
            day: .sunday,
            name: "Frisco's First Lady Radio with Ms. White",
            timeRange: "2:00 pm - 4:00 pm",
            detailURL: URL(string: "https://kxsf.fm/shows/friscos-first-lady-radio/")!,
            artworkURL: nil,
            hostName: nil,
            isNowPlaying: false
        )
        let schedule = KXSFSchedule(sections: [KXSFScheduleSection(day: .sunday, shows: [show])])

        let noisyHost = "MS. WHITE 1ST LADY OF FRISCO aka DJ Safire White"
        let enriched = schedule.enrichingHosts([show.detailURL: noisyHost])
        XCTAssertEqual(enriched.shows.first?.name, "Frisco's First Lady Radio")
        XCTAssertEqual(enriched.shows.first?.hostName, "DJ Safire White")
    }

    func test_parses_title_embedded_host_during_schedule_parse() throws {
        let html = """
        <h3 class="proradio-schedule__dayname">Sunday</h3>
        <article class="proradio-post proradio-post__card--shows">
          <a class="proradio-post__header__link" href="https://kxsf.fm/shows/friscos-first-lady-radio/"></a>
          <h3 class="proradio-post__title"><a>Frisco’s First Lady Radio with Ms. White</a></h3>
          <p class="proradio-itemmetas"> 2:00 pm - 4:00 pm </p>
        </article>
        """

        let show = try XCTUnwrap(KXSFScheduleParser.schedule(in: html).shows.first)
        XCTAssertEqual(show.name, "Frisco’s First Lady Radio")
        XCTAssertEqual(show.hostName, "Ms. White")
    }

    func test_suppresses_host_fragment_already_present_in_title() {
        let show = KXSFShow(
            day: .saturday,
            name: "Live from the Salesian Boys & Girls Club",
            timeRange: "2:00 pm - 3:00 pm",
            detailURL: URL(string: "https://kxsf.fm/shows/salesian-boys-girls-club/")!,
            artworkURL: nil,
            hostName: nil,
            isNowPlaying: false
        )
        let schedule = KXSFSchedule(sections: [KXSFScheduleSection(day: .saturday, shows: [show])])

        let enriched = schedule.enrichingHosts([show.detailURL: "Girls’ Club"])
        XCTAssertNil(enriched.shows.first?.hostName)
    }

    func test_skips_incomplete_cards_instead_of_inventing_data() {
        let html = """
        <h3 class="proradio-schedule__dayname">Monday</h3>
        <article><h3>Missing URL and time</h3></article>
        """

        XCTAssertTrue(KXSFScheduleParser.schedule(in: html).shows.isEmpty)
    }
}
