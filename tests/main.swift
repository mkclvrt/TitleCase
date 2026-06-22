import Foundation

typealias Style = TitleCase.Style

// (input, style, expected)
let cases: [(String, Style, String)] = [
    // Shared behavior — same in both styles.
    ("the quick brown fox", .chicago, "The Quick Brown Fox"),
    ("a tale of two cities", .chicago, "A Tale of Two Cities"),
    ("we are not in kansas anymore", .chicago, "We Are Not in Kansas Anymore"),
    ("to be or not to be", .chicago, "To Be or Not to Be"),
    ("for whom the bell tolls", .chicago, "For Whom the Bell Tolls"),
    ("the iPhone is here", .chicago, "The iPhone Is Here"),
    ("a study of the NASA program", .chicago, "A Study of the NASA Program"),
    ("small word at the end is nothing to be afraid of", .chicago,
     "Small Word at the End Is Nothing to Be Afraid Of"),
    ("this vs that", .chicago, "This vs That"),
    ("o'brien's car", .chicago, "O'Brien's Car"),
    ("HELLO WORLD", .chicago, "Hello World"),
    ("the lord of the rings", .chicago, "The Lord of the Rings"),
    ("mcdonald's farm", .chicago, "McDonald's Farm"),
    ("a man, a plan, a canal: panama", .chicago, "A Man, a Plan, a Canal: Panama"),
    ("nothing to fear but fear itself", .chicago, "Nothing to Fear but Fear Itself"),
    ("the self-esteem workshop", .chicago, "The Self-Esteem Workshop"),
    ("welcome to GitHub and the web", .chicago, "Welcome to GitHub and the Web"),
    ("of mice and men", .chicago, "Of Mice and Men"),
    ("\"the road not taken\"", .chicago, "\"The Road Not Taken\""),

    // Style contrast — Chicago lowercases long prepositions; AP capitalizes them.
    ("a song about love", .chicago, "A Song about Love"),
    ("a song about love", .ap, "A Song About Love"),
    ("the man from earth", .chicago, "The Man from Earth"),
    ("the man from earth", .ap, "The Man From Earth"),
    ("notes toward a theory of love", .chicago, "Notes toward a Theory of Love"),
    ("notes toward a theory of love", .ap, "Notes Toward a Theory of Love"),
    ("a journey between two worlds", .chicago, "A Journey between Two Worlds"),
    ("a journey between two worlds", .ap, "A Journey Between Two Worlds"),
    ("walking through the fire with you", .chicago, "Walking through the Fire with You"),
    ("walking through the fire with you", .ap, "Walking Through the Fire With You"),

    // Long preposition forced when first or last word (both styles).
    ("between two worlds", .chicago, "Between Two Worlds"),
    ("the world i walked through", .chicago, "The World I Walked Through"),
]

var failures = 0
for (input, style, expected) in cases {
    let got = TitleCase.convert(input, style: style)
    let mark = got == expected ? "ok  " : "FAIL"
    if got != expected { failures += 1 }
    let tag = style == .ap ? "[AP]     " : "[Chicago]"
    print("\(mark) \(tag) \(input)\n          -> \(got)")
    if got != expected { print("          ** expected: \(expected)") }
}
print("\n\(cases.count - failures)/\(cases.count) passed")
if failures > 0 { exit(1) }
