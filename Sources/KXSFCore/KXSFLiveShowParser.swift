import Foundation

public enum KXSFLiveShowParser {
    public static func showName(in html: String) -> String? {
        guard let markerRange = html.range(
            of: "now playing",
            options: [.caseInsensitive, .diacriticInsensitive]
        ) else {
            return nil
        }

        let remainingHTML = String(html[markerRange.upperBound...])
        guard
            let headingStart = remainingHTML.range(of: "<h3", options: .caseInsensitive),
            let headingEnd = remainingHTML.range(
                of: "</h3>",
                options: .caseInsensitive,
                range: headingStart.lowerBound..<remainingHTML.endIndex
            )
        else {
            return nil
        }

        let headingHTML = String(remainingHTML[headingStart.lowerBound..<headingEnd.upperBound])
        let withoutTags = headingHTML.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        let normalized = withoutTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#8217;", with: "’")
            .replacingOccurrences(of: "&#8216;", with: "‘")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")

        return normalized.isEmpty ? nil : normalized
    }
}
