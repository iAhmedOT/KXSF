import XCTest
@testable import KXSFCore

final class KXSFContentParserTests: XCTestCase {
    func test_extracts_host_from_official_member_block() {
        let html = """
        <h1>FreeFall. Tuesday, 10AM</h1>
        <a href="https://kxsf.fm/members/david-bassin/"><span class="person_outline"></span></a>
        <h3><a href="https://kxsf.fm/members/david-bassin/">David Bassin</a></h3>
        """

        XCTAssertEqual(KXSFShowDetailParser.hostName(in: html), "David Bassin")
    }

    func test_extracts_the_host_from_an_official_show_detail_page() {
        let html = """
        <h1>FreeFall. Tuesday, 10AM</h1>
        <p>David Bassin hosts an eclectic two-hour mix of jazz, R&amp;B, global grooves &amp; abstract beats.</p>
        <h3>David Bassin</h3>
        """

        XCTAssertEqual(KXSFShowDetailParser.hostName(in: html), "David Bassin")
    }

    func test_extracts_host_from_with_phrase_in_official_description_metadata() {
        let html = """
        <meta property="og:description" content="Every week on Fri at 8:00 PM With&nbsp;DJ Casanova" />
        <h3>Info</h3>
        """

        XCTAssertEqual(KXSFShowDetailParser.hostName(in: html), "DJ Casanova")
    }

    func test_extracts_host_after_host_noun_in_official_description_metadata() {
        let html = """
        <meta property="og:description" content="Off the Hook offers the opinionated expertise of host&nbsp;Gage Kenady. [...]" />
        <h3>Info</h3>
        """

        XCTAssertEqual(KXSFShowDetailParser.hostName(in: html), "Gage Kenady")
    }

    func test_rejects_all_caps_host_blurbs() {
        let html = """
        <meta property="og:description" content="Every week With MS. WHITE 1ST LADY OF FRISCO." />
        """

        XCTAssertNil(KXSFShowDetailParser.hostName(in: html))
    }

    func test_recovers_dj_name_from_aka_blurb() {
        let html = """
        <meta property="og:description" content="Every week With MS. WHITE 1ST LADY OF FRISCO aka DJ Safire White." />
        """

        XCTAssertEqual(KXSFShowDetailParser.hostName(in: html), "DJ Safire White")
    }

    func test_orders_sections_starting_with_the_listener_weekday() {
        let monday = KXSFScheduleSection(day: .monday, shows: [])
        let tuesday = KXSFScheduleSection(day: .tuesday, shows: [])
        let wednesday = KXSFScheduleSection(day: .wednesday, shows: [])
        let schedule = KXSFSchedule(sections: [monday, tuesday, wednesday])

        XCTAssertEqual(
            schedule.sections(startingWith: .tuesday).map(\.day),
            [.tuesday, .wednesday, .monday]
        )
    }

    func test_parses_the_latest_official_youtube_uploads() throws {
        let feed = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom" xmlns:yt="http://www.youtube.com/xml/schemas/2015">
          <entry>
            <yt:videoId>abc123def45</yt:videoId>
            <title>KXSF Live at The Chapel</title>
            <published>2026-08-26T18:30:00+00:00</published>
            <media:group xmlns:media="http://search.yahoo.com/mrss/"><media:thumbnail url="https://i.ytimg.com/vi/abc123def45/hqdefault.jpg" /></media:group>
          </entry>
        </feed>
        """

        let upload = try XCTUnwrap(KXSFYouTubeFeedParser.uploads(in: feed).first)
        XCTAssertEqual(upload.title, "KXSF Live at The Chapel")
        XCTAssertEqual(upload.videoID, "abc123def45")
        XCTAssertEqual(upload.thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/abc123def45/hqdefault.jpg")
        XCTAssertEqual(upload.watchURL.absoluteString, "https://www.youtube.com/watch?v=abc123def45")
    }

    func test_skips_youtube_entries_without_a_video_id() {
        let feed = "<feed xmlns=\"http://www.w3.org/2005/Atom\"><entry><title>Broken</title></entry></feed>"

        XCTAssertTrue(KXSFYouTubeFeedParser.uploads(in: feed).isEmpty)
    }

    func test_parses_hex_escaped_mobile_youtube_compact_renderer() throws {
        let page = #"""
        <script>var ytInitialData = '\x7b\x22compactVideoRenderer\x22:\x7b\x22videoId\x22:\x22dZAC4-xTj3U\x22,\x22title\x22:\x7b\x22runs\x22:\x5b\x7b\x22text\x22:\x22Amy Obenski on KXSF, June 28th, 2026\x22\x7d\x5d\x7d\x7d\x7d';</script>
        """#

        let uploads = KXSFYouTubePageParser.uploads(in: page)
        XCTAssertEqual(uploads.map(\.videoID), ["dZAC4-xTj3U"])
        XCTAssertEqual(uploads.map(\.title), ["Amy Obenski on KXSF, June 28th, 2026"])
        XCTAssertEqual(uploads.first?.thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/dZAC4-xTj3U/hqdefault.jpg")
    }

    func test_youtube_uploads_round_trip_for_last_known_good_cache() throws {
        let upload = KXSFYouTubeUpload(
            videoID: "abc123def45",
            title: "KXSF Live Session",
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            thumbnailURL: URL(string: "https://i.ytimg.com/vi/abc123def45/hqdefault.jpg")
        )

        let data = try JSONEncoder().encode([upload])
        let restored = try JSONDecoder().decode([KXSFYouTubeUpload].self, from: data)
        XCTAssertEqual(restored, [upload])
    }

    func test_parses_youtube_video_renderer_markup_variant() throws {
        let page = """
        <script>
        var ytInitialData = {"contents":[
          {"videoRenderer":{"videoId":"abc123def45","title":{"runs":[{"text":"KXSF Live – Guest Session"}]},"thumbnail":{"thumbnails":[{"url":"https://i.ytimg.com/vi/abc123def45/hqdefault.jpg"}]}}},
          {"gridVideoRenderer":{"videoId":"zyx987wvu65","title":{"simpleText":"KXSF Live: Studio Performance"},"thumbnail":{"thumbnails":[{"url":"https://i.ytimg.com/vi/zyx987wvu65/hqdefault.jpg"}]}}}
        ]};
        </script>
        """

        let uploads = KXSFYouTubePageParser.uploads(in: page)
        XCTAssertEqual(uploads.map(\.videoID), ["abc123def45", "zyx987wvu65"])
        XCTAssertEqual(uploads.map(\.title), ["KXSF Live – Guest Session", "KXSF Live: Studio Performance"])
    }

    func test_parses_official_youtube_videos_page_when_atom_feed_is_unavailable() throws {
        let page = """
        <script>
        var ytInitialData = {"contents":{"twoColumnBrowseResultsRenderer":{"tabs":[{"tabRenderer":{"content":{"richGridRenderer":{"contents":[{"richItemRenderer":{"content":{"lockupViewModel":{"contentId":"dZAC4-xTj3U","contentImage":{"thumbnailViewModel":{"image":{"sources":[{"url":"https://i.ytimg.com/vi/dZAC4-xTj3U/hqdefault.jpg","width":480,"height":270}]}}},"metadata":{"lockupMetadataViewModel":{"title":{"content":"Amy Obenski on KXSF, June 28th, 2026"}}}}}}]}}}}]}};
        </script>
        """

        let upload = try XCTUnwrap(KXSFYouTubePageParser.uploads(in: page).first)
        XCTAssertEqual(upload.videoID, "dZAC4-xTj3U")
        XCTAssertEqual(upload.title, "Amy Obenski on KXSF, June 28th, 2026")
        XCTAssertEqual(upload.thumbnailURL?.absoluteString, "https://i.ytimg.com/vi/dZAC4-xTj3U/hqdefault.jpg")
    }
}
