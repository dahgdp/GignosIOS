import Foundation

enum HTMLContent {
    static func replacing(_ text: String, pattern: String, with template: String) -> String {
        text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
    }
    static func decodeEntities(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z][a-zA-Z0-9]+);") else { return text }
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range, in: result), let keyRange = Range(match.range(at: 1), in: result) else { continue }
            let key = String(result[keyRange])
            let replacement: String?
            if key.hasPrefix("#") {
                let hex = key.hasPrefix("#x")
                replacement = UInt32(key.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10).flatMap(UnicodeScalar.init).map(String.init)
            } else { replacement = htmlEntities[key] }
            if let replacement { result.replaceSubrange(range, with: replacement) }
        }
        return result
    }
    static func plainText(_ html: String) -> String {
        var text = replacing(html, pattern: "(?is)<(script|style)\\b[^>]*>.*?</\\1>", with: "")
        text = replacing(text, pattern: "(?i)<br\\s*/?>|</(?:p|div|h[1-6]|li|tr)\\s*>", with: "\n\n")
        text = replacing(text, pattern: "<[^>]+>", with: "")
        text = decodeEntities(text).replacingOccurrences(of: "\u{00a0}", with: " ")
        text = replacing(text, pattern: "[\\t ]+", with: " ")
        text = replacing(text, pattern: "\\n\\s*\\n", with: "\n\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func links(_ html: String, baseURL: URL) -> [RecordLink] {
        guard let regex = try? NSRegularExpression(pattern: "(?is)<a\\b[^>]*href\\s*=\\s*[\"']([^\"']+)[\"'][^>]*>(.*?)</a>") else { return [] }
        return regex.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { match in
            guard let target = Range(match.range(at: 1), in: html), let label = Range(match.range(at: 2), in: html),
                  let url = RecordLink.safeURL(decodeEntities(String(html[target])), relativeTo: baseURL) else { return nil }
            let title = plainText(String(html[label]))
            return RecordLink(title: title.isEmpty ? "Reference" : title, url: url)
        }
    }
}
