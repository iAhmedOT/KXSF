import Foundation

public enum KXSFHTMLText {
    public struct ShowIdentity: Equatable, Sendable {
        public let title: String
        public let embeddedHostName: String?

        public init(title: String, embeddedHostName: String? = nil) {
            self.title = title
            self.embeddedHostName = embeddedHostName
        }
    }

    public static func showTitle(_ source: String) -> String? {
        showIdentity(from: source)?.title
    }

    public static func showIdentity(from source: String) -> ShowIdentity? {
        guard var title = plainText(source) else { return nil }

        let weekday = "(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)s?"
        let scheduleSuffix = "(?:\\s*[\\.,:;\\-–—]\\s*|(?<=!)\\s+)\\b\(weekday)\\b.*$"
        title = title.replacingOccurrences(
            of: scheduleSuffix,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        var embeddedHost: String?
        if let match = firstMatch(
            #"^(.*?)\s+\bwith\s+(.+)$"#,
            in: title,
            options: [.caseInsensitive]
        ) {
            let base = collapseWhitespace(match.0)
            let host = collapseWhitespace(match.1)
            if !base.isEmpty, let cleanedHost = cleanedHostCandidate(host) {
                title = base
                embeddedHost = cleanedHost
            }
        }

        let cleaned = collapseWhitespace(title)
        guard !cleaned.isEmpty else { return nil }
        return ShowIdentity(title: cleaned, embeddedHostName: embeddedHost)
    }

    /// Prefer a short host label. Prefer recovered DJ names from noisy blurbs.
    public static func preferredHostName(showTitle: String, candidateHost: String?) -> String? {
        guard let candidateHost else { return nil }
        guard let cleanedHost = cleanedHostCandidate(candidateHost) else { return nil }

        let lowerTitle = showTitle.lowercased()
        let lowerHost = cleanedHost.lowercased()

        // Title already ends with "with Host Name" — do not repeat it under the card.
        if lowerTitle.range(
            of: #"\bwith\s+"# + NSRegularExpression.escapedPattern(for: lowerHost) + #"\s*$"#,
            options: .regularExpression
        ) != nil {
            return nil
        }

        // Title already contains the host name somewhere.
        if lowerTitle.contains(lowerHost) { return nil }

        // Host is just a fragment already present in the title (e.g. "Girls' Club").
        let hostWordTokens = tokens(in: cleanedHost)
            .filter { $0.count >= 3 && !["with", "from", "the", "and", "show", "radio", "live", "boys", "girls", "club"].contains($0) }
        if !hostWordTokens.isEmpty {
            let titleWordTokens = tokens(in: showTitle)
            if hostWordTokens.isSubset(of: titleWordTokens) {
                return nil
            }
        }

        let allHostTokens = tokens(in: cleanedHost)
        if !allHostTokens.isEmpty, allHostTokens.isSubset(of: tokens(in: showTitle)) {
            return nil
        }

        return cleanedHost
    }

    public static func cleanedHostCandidate(_ source: String) -> String? {
        var host = collapseWhitespace(source)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!? "))
        guard !host.isEmpty else { return nil }

        // Prefer a DJ moniker after "aka".
        if let akaMatch = firstMatch(#"(?i)\baka\s+(.+)$"#, in: host) {
            let afterAka = collapseWhitespace(akaMatch.0)
            if !afterAka.isEmpty {
                host = afterAka
            }
        }

        // Drop leading all-caps slogan prefixes before a DJ moniker if still present.
        if let djMatch = firstMatch(#"(?i)\b(DJ\s+.+)$"#, in: host) {
            host = collapseWhitespace(djMatch.0)
        }

        // Normalize honorifics like "Ms." / "MS." without creating "Ms.."
        host = host.replacingOccurrences(of: #"\bMs\.\b"#, with: "Ms.", options: [.regularExpression, .caseInsensitive])
        host = host.replacingOccurrences(of: #"\bMs\b"#, with: "Ms.", options: [.regularExpression, .caseInsensitive])
        host = host.replacingOccurrences(of: #"\bMr\.\b"#, with: "Mr.", options: [.regularExpression, .caseInsensitive])
        host = host.replacingOccurrences(of: #"\bMr\b"#, with: "Mr.", options: [.regularExpression, .caseInsensitive])
        // Collapse accidental double periods from mixed input.
        host = host.replacingOccurrences(of: #"\.{2,}"#, with: ".", options: .regularExpression)
        host = collapseWhitespace(host)

        let hostTokens = host.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if hostTokens.isEmpty { return nil }
        if hostTokens.count > 5 { return nil }
        if host.count > 42 { return nil }
        if hostTokens.count == 1, hostTokens[0].count <= 3 { return nil }
        if hostTokens.contains(where: { $0.lowercased() == "aka" }) { return nil }

        // Reject pure all-caps slogans, but allow normal mixed-case names and DJ monikers.
        let lettersOnly = host.filter(\.isLetter)
        if !lettersOnly.isEmpty,
           lettersOnly.allSatisfy({ $0.isUppercase || !$0.isCased }),
           !host.localizedCaseInsensitiveContains("DJ ") {
            return nil
        }

        return host
    }

    public static func plainText(_ source: String) -> String? {
        let withoutTags = source.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        let normalized = collapseWhitespace(decodeEntities(withoutTags))
        return normalized.isEmpty ? nil : normalized
    }

    public static func collapseWhitespace(_ source: String) -> String {
        source
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func decodeEntities(_ source: String) -> String {
        var decoded = source
        let namedEntities = [
            "&amp;": "&",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
            "&ndash;": "–",
            "&mdash;": "—",
        ]
        for (entity, replacement) in namedEntities {
            decoded = decoded.replacingOccurrences(
                of: entity,
                with: replacement,
                options: .caseInsensitive
            )
        }

        guard let regex = try? NSRegularExpression(pattern: "&#(x[0-9a-f]+|[0-9]+);", options: .caseInsensitive) else {
            return decoded
        }
        let range = NSRange(decoded.startIndex..<decoded.endIndex, in: decoded)
        for match in regex.matches(in: decoded, range: range).reversed() {
            guard
                let entityRange = Range(match.range(at: 0), in: decoded),
                let valueRange = Range(match.range(at: 1), in: decoded)
            else { continue }

            let valueText = String(decoded[valueRange])
            let radix = valueText.lowercased().hasPrefix("x") ? 16 : 10
            let digits = radix == 16 ? String(valueText.dropFirst()) : valueText
            guard
                let value = UInt32(digits, radix: radix),
                let scalar = Unicode.Scalar(value)
            else { continue }
            decoded.replaceSubrange(entityRange, with: String(scalar))
        }
        return decoded
    }

    private static func tokens(in text: String) -> Set<String> {
        Set(
            text
                .lowercased()
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    private static func firstMatch(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> (String, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            match.numberOfRanges >= 3,
            let first = Range(match.range(at: 1), in: text),
            let second = Range(match.range(at: 2), in: text)
        else {
            // Support single-capture patterns too.
            if let match = regex.firstMatch(in: text, range: range),
               match.numberOfRanges >= 2,
               let only = Range(match.range(at: 1), in: text) {
                return (String(text[only]), "")
            }
            return nil
        }
        return (String(text[first]), String(text[second]))
    }
}
