import Foundation

// Title casing with no external dependencies, in two styles.
//
// Shared rules (both styles):
//  - Capitalize the first and last word of each line, always.
//  - Capitalize all "principal" words.
//  - Lowercase articles, coordinating conjunctions, and short prepositions
//    ("small words") unless first/last or following sentence punctuation.
//  - Preserve words with intentional internal capitals (iPhone, NASA, GitHub).
//  - Capitalize each part of a hyphenated word (Self-Esteem).
//  - Handle Mc/name-apostrophe prefixes (McDonald, O'Brien, D'Angelo).
//  - Title-case ALL-CAPS input ("HELLO WORLD" -> "Hello World").
//
// Style difference:
//  - .chicago additionally lowercases prepositions of any length
//    ("about", "toward", "between", "through", "with"...).
//  - .ap keeps only the short small-word list, so 4+ letter prepositions are
//    capitalized.
//
// Note: neither style can detect a preposition used adverbially ("Look Up"),
// since that needs part-of-speech analysis. This matches typical converters.

enum TitleCase {

    enum Style {
        case chicago
        case ap
    }

    // Short small words: articles, coordinating conjunctions, short
    // prepositions. Lowercased in BOTH styles. (Gruber's conservative list.)
    static let baseSmall: Set<String> = [
        "a", "an", "and", "as", "at", "but", "by", "en", "for", "if", "in",
        "nor", "of", "on", "or", "the", "to", "v", "v.", "via", "vs", "vs.",
    ]

    // Longer prepositions. Lowercased only in Chicago style.
    static let longPrepositions: Set<String> = [
        "about", "above", "across", "after", "against", "along", "amid",
        "among", "around", "atop", "before", "behind", "below", "beneath",
        "beside", "besides", "between", "beyond", "concerning", "despite",
        "down", "during", "except", "from", "inside", "into", "like", "near",
        "onto", "outside", "over", "past", "regarding", "round", "since",
        "than", "through", "throughout", "toward", "towards", "under",
        "underneath", "unlike", "until", "unto", "upon", "with", "within",
        "without",
    ]

    static func isSmall(_ word: String, _ style: Style) -> Bool {
        let w = word.lowercased()
        if baseSmall.contains(w) { return true }
        if style == .chicago && longPrepositions.contains(w) { return true }
        return false
    }

    static func convert(_ text: String, style: Style = .chicago) -> String {
        let lines = text.components(separatedBy: "\n")
        let converted = lines.map { convertLine($0, style) }
        return converted.joined(separator: "\n")
    }

    private static func convertLine(_ line: String, _ style: Style) -> String {
        let allCaps = isAllCaps(line)
        // Split on spaces only, preserving empty fields so runs of spaces and
        // leading/trailing spaces are kept exactly.
        let tokens = line.components(separatedBy: " ")

        // First pass: case each token on its own merits.
        var cased = tokens.map { caseWord($0, allCaps: allCaps, style: style) }

        // Track which tokens are actual words (contain a letter) so first/last
        // logic ignores empty fields created by multiple spaces.
        let wordIndexes = tokens.indices.filter { containsLetter(tokens[$0]) }
        guard let firstWord = wordIndexes.first, let lastWord = wordIndexes.last
        else { return cased.joined(separator: " ") }

        // Second pass: force-capitalize small words that are first, last, or
        // follow sentence-ending punctuation. Non-small words are already
        // capitalized; internal-caps words are left untouched.
        var previousEndsSentence = true  // start of line behaves like a new phrase
        for i in tokens.indices {
            let token = tokens[i]
            guard containsLetter(token) else { continue }
            let core = trimEdgePunct(token)
            let forced = (i == firstWord) || (i == lastWord) || previousEndsSentence
            if forced && isSmall(core, style) {
                cased[i] = capitalizeFirstLetter(cased[i])
            }
            previousEndsSentence = endsSentence(token)
        }

        return cased.joined(separator: " ")
    }

    // MARK: - Single-word casing

    private static func caseWord(_ word: String, allCaps: Bool, style: Style) -> String {
        if word.isEmpty { return word }

        let (lead, core, trail) = splitEdges(word)
        if core.isEmpty { return word }

        // Preserve intentional internal capitals (iPhone, NASA) unless the whole
        // line was all-caps (in which case there's no intent to preserve).
        if !allCaps && hasInternalUppercase(core) {
            return word
        }

        var working = core
        if allCaps { working = working.lowercased() }

        return lead + caseCore(working, style) + trail
    }

    private static func caseCore(_ core: String, _ style: Style) -> String {
        // Tentatively lowercase small words; the second pass re-capitalizes the
        // ones in forcing positions.
        if isSmall(core, style) {
            return core.lowercased()
        }

        let lower = core.lowercased()

        // Mc-prefixed names: McDonald, McEachran.
        if lower.count > 2 && lower.hasPrefix("mc") {
            let rest = String(core.dropFirst(2))
            return "Mc" + capitalizeFirstLetter(rest)
        }

        // Capitalize each hyphen-separated part.
        let parts = core.components(separatedBy: "-").map { capitalizeFirstLetter($0) }
        var result = parts.joined(separator: "-")

        // Name apostrophe prefixes: a single leading letter followed by an
        // apostrophe and a letter -> capitalize the letter after the apostrophe
        // (O'Brien, D'Angelo, L'Amour). Contractions like "don't" have more than
        // one leading letter and are left as "Don't".
        result = capitalizeAfterLeadingApostrophe(result)
        return result
    }

    // MARK: - Helpers

    private static func capitalizeFirstLetter(_ s: String) -> String {
        var chars = Array(s)
        for i in chars.indices {
            if chars[i].isLetter {
                chars[i] = Character(String(chars[i]).uppercased())
                break
            }
        }
        return String(chars)
    }

    private static func capitalizeAfterLeadingApostrophe(_ s: String) -> String {
        let chars = Array(s)
        guard let f = chars.firstIndex(where: { $0.isLetter }) else { return s }
        let apos = f + 1
        let next = f + 2
        guard apos < chars.count, next < chars.count else { return s }
        let isApos = chars[apos] == "'" || chars[apos] == "’"
        if isApos && chars[next].isLetter {
            var out = chars
            out[next] = Character(String(out[next]).uppercased())
            return String(out)
        }
        return s
    }

    private static func hasInternalUppercase(_ core: String) -> Bool {
        let chars = Array(core)
        guard let f = chars.firstIndex(where: { $0.isLetter }) else { return false }
        for i in (f + 1)..<chars.count where chars[i].isUppercase {
            return true
        }
        return false
    }

    private static func isAllCaps(_ line: String) -> Bool {
        var hasLetter = false
        for ch in line {
            if ch.isLetter {
                hasLetter = true
                if ch.isLowercase { return false }
            }
        }
        return hasLetter
    }

    private static func containsLetter(_ s: String) -> Bool {
        return s.contains(where: { $0.isLetter })
    }

    private static func endsSentence(_ token: String) -> Bool {
        for ch in token.reversed() {
            if ch == "\"" || ch == "'" || ch == "”" || ch == "’" || ch == ")" { continue }
            return [":", ".", ";", "?", "!"].contains(ch)
        }
        return false
    }

    private static func trimEdgePunct(_ s: String) -> String {
        let (_, core, _) = splitEdges(s)
        return core
    }

    private static let edgePunct = CharacterSet(charactersIn: "!\"#$%&'‘’“”()*+,-./:;?@[\\]_`{|}~")

    // Split a token into (leading punctuation, core, trailing punctuation),
    // where the core starts and ends with a letter or digit.
    private static func splitEdges(_ s: String) -> (String, String, String) {
        let chars = Array(s)
        var start = 0
        var end = chars.count
        while start < end, isEdge(chars[start]) { start += 1 }
        while end > start, isEdge(chars[end - 1]) { end -= 1 }
        let lead = String(chars[0..<start])
        let core = String(chars[start..<end])
        let trail = String(chars[end..<chars.count])
        return (lead, core, trail)
    }

    private static func isEdge(_ c: Character) -> Bool {
        return c.unicodeScalars.allSatisfy { edgePunct.contains($0) }
    }
}
