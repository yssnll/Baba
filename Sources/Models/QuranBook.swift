import Foundation

/// Le lecteur du mushaf utilise uniquement le texte Hafs ‘an ‘Asim.
/// Quran.com fournit pour cette édition le balisage tajwid vérifié.
enum QuranBookRiwaya: String, Codable, Identifiable {
    case hafs

    var id: String { rawValue }

    var title: String { "Hafs ‘an ‘Asim" }

    var shortTitle: String { "Hafs" }

    var icon: String { "sparkles" }

    var hasVerifiedTajweedMarkup: Bool { true }

    var sourceDescription: String {
        "Texte uthmani Hafs avec balisage tajwid vérifié fourni par Quran.com."
    }
}

struct QuranBookVerse: Codable, Identifiable, Hashable {
    let id: Int
    let verseKey: String
    let textUthmani: String?
    let textUthmaniTajweed: String?

    var verseNumber: Int {
        Int(verseKey.split(separator: ":").last ?? "") ?? 0
    }

    var plainText: String {
        textUthmani ?? textUthmaniTajweed ?? ""
    }

    var tajweedText: String? {
        textUthmaniTajweed
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case verseKey = "verse_key"
        case textUthmani = "text_uthmani"
        case textUthmaniTajweed = "text_uthmani_tajweed"
    }
}

struct QuranBookResponse: Decodable {
    let verses: [QuranBookVerse]
}

struct QuranBookDocument {
    let verses: [QuranBookVerse]

    static func verses(_ verses: [QuranBookVerse]) -> QuranBookDocument {
        QuranBookDocument(verses: verses)
    }
}