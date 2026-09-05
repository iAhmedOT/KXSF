import Foundation

public enum KXSFShowDetailParser {
    public static func hostName(in html: String) -> String? {
        if
            let descriptionHTML = firstCapture(
                "<meta[^>]*property=[\\\"']og:description[\\\"'][^>]*content=[\\\"']([^\\\"']*)[\\\"'][^>]*>",
                in: html
            ),
            let description = plainText(descriptionHTML),
            let host = hostName(inPlainText: description)
        {
            return host
        }

        if let memberHeading = firstCapture(
            "<h3[^>]*>\\s*<a[^>]*href=[\\\"'][^\\\"']*/members/[^\\\"']*[\\\"'][^>]*>(.*?)</a>\\s*</h3>",
            in: html
        ), let name = plainText(memberHeading) {
            return name
        }

        guard let pageText = plainText(html) else { return nil }
        return hostName(inPlainText: pageText)
    }

    private static func hostName(inPlainText text: String) -> String? {
        // Prefer recovering a DJ moniker from noisy blurbs before generic "With …" matching.
        if let akaDJ = firstCapture(#"(?i)\baka\s+(DJ\s+[A-Za-zÀ-ÖØ-öø-ÿ0-9’'\.\-]+(?:\s+[A-Za-zÀ-ÖØ-öø-ÿ0-9’'\.\-]+){0,4})"#, in: text) {
            let trimmed = akaDJ.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!? "))
            if let cleaned = KXSFHTMLText.cleanedHostCandidate(trimmed) {
                return cleaned
            }
        }

        let name = "([A-Z][A-Za-zÀ-ÖØ-öø-ÿ0-9’'\\.-]+(?:\\s+[A-Z][A-Za-zÀ-ÖØ-öø-ÿ0-9’'\\.-]+){0,6})"
        let patterns = [
            "\\bWith\\s+\(name)(?=[.!?]|$)",
            "\\bhost(?:ed\\s+by)?\\s+\(name)(?=[.!?]|$)",
            "\\b\(name)\\s+(?:hosts|curates|presents)\\b"
        ]

        for pattern in patterns {
            if let match = firstCapture(pattern, in: text) {
                let trimmed = match.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!? "))
                if let cleaned = KXSFHTMLText.cleanedHostCandidate(trimmed) {
                    return cleaned
                }
            }
        }
        return nil
    }
}

public struct KXSFYouTubeUpload: Sendable, Codable, Equatable, Identifiable {
    public let videoID: String
    public let title: String
    public let publishedAt: Date?
    public let thumbnailURL: URL?

    public var id: String { videoID }
    public var watchURL: URL { URL(string: "https://www.youtube.com/watch?v=\(videoID)")! }

    public init(videoID: String, title: String, publishedAt: Date?, thumbnailURL: URL?) {
        self.videoID = videoID
        self.title = title
        self.publishedAt = publishedAt
        self.thumbnailURL = thumbnailURL
    }
}

public enum KXSFYouTubeFeedParser {
    public static func uploads(in xml: String) -> [KXSFYouTubeUpload] {
        matches("<entry\\b[^>]*>.*?</entry>", in: xml).compactMap { entry in
            guard
                let videoID = firstCapture("<yt:videoId>(.*?)</yt:videoId>", in: entry),
                let title = firstCapture("<title>(.*?)</title>", in: entry).flatMap(plainText),
                !videoID.isEmpty
            else {
                return nil
            }

            let publishedAt = firstCapture("<published>(.*?)</published>", in: entry)
                .flatMap { ISO8601DateFormatter().date(from: $0) }
            let thumbnailURL = firstCapture("<media:thumbnail[^>]*url=[\\\"']([^\\\"']+)[\\\"']", in: entry)
                .flatMap { URL(string: KXSFHTMLText.decodeEntities($0)) }

            return KXSFYouTubeUpload(
                videoID: videoID,
                title: title,
                publishedAt: publishedAt,
                thumbnailURL: thumbnailURL
            )
        }
    }
}

/// Parses the public, official KXSF YouTube Videos page only as a fallback when
/// YouTube's documented Atom endpoint is unavailable. Entries missing a stable
/// YouTube video ID, title, or thumbnail are intentionally discarded.
public enum KXSFYouTubePageParser {
    public static func uploads(in html: String) -> [KXSFYouTubeUpload] {
        let source = decodeJavaScriptHexEscapes(in: html)
        let lockups: [KXSFYouTubeUpload] = jsonObjects(after: ["\"lockupViewModel\":"], in: source)
            .compactMap { object -> KXSFYouTubeUpload? in
                guard
                    let videoID = string(at: ["contentId"], in: object),
                    !videoID.isEmpty,
                    let rawTitle = string(at: ["metadata", "lockupMetadataViewModel", "title", "content"], in: object),
                    let title = KXSFHTMLText.plainText(rawTitle),
                    let thumbnail = string(at: ["contentImage", "thumbnailViewModel", "image", "sources", "0", "url"], in: object),
                    let thumbnailURL = URL(string: thumbnail)
                else { return nil }
                return KXSFYouTubeUpload(videoID: videoID, title: title, publishedAt: nil, thumbnailURL: thumbnailURL)
            }

        let renderers: [KXSFYouTubeUpload] = jsonObjects(
            after: ["\"videoRenderer\":", "\"gridVideoRenderer\":", "\"compactVideoRenderer\":"],
            in: source
        )
            .compactMap { object -> KXSFYouTubeUpload? in
                guard
                    let videoID = string(at: ["videoId"], in: object),
                    !videoID.isEmpty,
                    let rawTitle = string(at: ["title", "simpleText"], in: object)
                        ?? string(at: ["title", "runs", "0", "text"], in: object),
                    let title = KXSFHTMLText.plainText(rawTitle)
                else { return nil }
                let thumbnailURL = string(at: ["thumbnail", "thumbnails", "0", "url"], in: object)
                    .flatMap { URL(string: $0) }
                    ?? URL(string: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg")
                return KXSFYouTubeUpload(videoID: videoID, title: title, publishedAt: nil, thumbnailURL: thumbnailURL)
            }

        return (lockups + renderers).removingDuplicateVideoIDs()
    }
}

private func decodeJavaScriptHexEscapes(in source: String) -> String {
    let bytes = Array(source.utf8)
    var decoded: [UInt8] = []
    decoded.reserveCapacity(bytes.count)
    var index = 0

    while index < bytes.count {
        if index + 3 < bytes.count,
           bytes[index] == 0x5C,
           bytes[index + 1] == 0x78,
           let high = hexValue(bytes[index + 2]),
           let low = hexValue(bytes[index + 3]) {
            decoded.append((high << 4) | low)
            index += 4
        } else {
            decoded.append(bytes[index])
            index += 1
        }
    }
    return String(decoding: decoded, as: UTF8.self)
}

private func hexValue(_ byte: UInt8) -> UInt8? {
    switch byte {
    case 48...57: byte - 48
    case 65...70: byte - 55
    case 97...102: byte - 87
    default: nil
    }
}

private func jsonObjects(after markers: [String], in source: String) -> [[String: Any]] {
    markers.flatMap { marker in
        jsonObjects(after: marker, in: source)
    }
}

private func jsonObjects(after marker: String, in source: String) -> [[String: Any]] {
    var searchStart = source.startIndex
    var objects: [[String: Any]] = []

    while let markerRange = source.range(of: marker, range: searchStart..<source.endIndex),
          let objectStart = source[markerRange.upperBound...].firstIndex(of: "{"),
          let objectText = balancedJSONObject(in: source, from: objectStart),
          let data = objectText.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        objects.append(object)
        searchStart = source.index(after: objectStart)
    }
    return objects
}

private func balancedJSONObject(in source: String, from start: String.Index) -> String? {
    var depth = 0
    var isEscaped = false
    var inString = false

    for index in source.indices[start...] {
        let character = source[index]
        if inString {
            if isEscaped { isEscaped = false }
            else if character == "\\" { isEscaped = true }
            else if character == "\"" { inString = false }
            continue
        }
        if character == "\"" { inString = true }
        else if character == "{" { depth += 1 }
        else if character == "}" {
            depth -= 1
            if depth == 0 { return String(source[start...index]) }
        }
    }
    return nil
}

private func string(at path: [String], in object: [String: Any]) -> String? {
    var value: Any = object
    for component in path {
        if let dictionary = value as? [String: Any] {
            value = dictionary[component] as Any
        } else if let array = value as? [Any], let index = Int(component), array.indices.contains(index) {
            value = array[index]
        } else {
            return nil
        }
    }
    return value as? String
}

private extension Array where Element == KXSFYouTubeUpload {
    func removingDuplicateVideoIDs() -> [KXSFYouTubeUpload] {
        var seen = Set<String>()
        return filter { seen.insert($0.videoID).inserted }
    }
}

private func firstCapture(_ pattern: String, in source: String) -> String? {
    guard
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
        let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..<source.endIndex, in: source)),
        let range = Range(match.range(at: 1), in: source)
    else {
        return nil
    }
    return String(source[range])
}

private func matches(_ pattern: String, in source: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
        return []
    }
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    return regex.matches(in: source, range: range).compactMap { match in
        guard let range = Range(match.range, in: source) else { return nil }
        return String(source[range])
    }
}

private func plainText(_ source: String) -> String? {
    KXSFHTMLText.plainText(source)
}
