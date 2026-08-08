import Foundation

/// Les éditions de texte disponibles dans le lecteur du mushaf.
/// Le serveur Quran.com fournit actuellement un balisage tajwid complet pour
/// l'édition uthmani utilisée ici pour Hafs. Les autres éditions restent
/// distinctes et sont affichées sans coloration inventée.
enum QuranBookRiwaya: String, CaseIterable, Codable, Identifiable {
    case hafs
    case warsh
    case khalaf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hafs: return "Hafs ‘an ‘Asim"
        case .warsh: return "Warsh ‘an Nafi‘"
        case .khalaf: return "Khalaf ‘an Hamzah"
        }
    }

    var shortTitle: String {
        switch self {
        case .hafs: return "Hafs"
        case .warsh: return "Warsh"
        case .khalaf: return "Khalaf"
        }
    }

    var icon: String {
        switch self {
        case .hafs: return "sparkles"
        case .warsh: return "book.closed"
        case .khalaf: return "book.closed.fill"
        }
    }

    var hasVerifiedTajweedMarkup: Bool {
        self == .hafs
    }

    var sourceDescription: String {
        switch self {
        case .hafs:
            return "Texte uthmani avec balisage tajwid fourni par Quran.com."
        case .warsh:
            return "Texte Warsh dédié, embarqué pour une lecture hors connexion. Le balisage tajwid couleur n'est pas fourni par cette édition."
        case .khalaf:
            return "Mushaf PDF dédié à Khalaf ‘an Hamzah, embarqué pour une lecture hors connexion."
        }
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

struct WarshSurah: Decodable {
    let id: Int
    let ayahs: [WarshAyah]
}

struct WarshAyah: Decodable {
    let id: Int
    let number: Int
    let surah: String
    let text: String
}

struct QuranBookDocument {
    let verses: [QuranBookVerse]
    let pdfURL: URL?
    let initialPDFPage: Int?

    static func verses(_ verses: [QuranBookVerse]) -> QuranBookDocument {
        QuranBookDocument(verses: verses, pdfURL: nil, initialPDFPage: nil)
    }

    static func pdf(url: URL, page: Int) -> QuranBookDocument {
        QuranBookDocument(verses: [], pdfURL: url, initialPDFPage: page)
    }
}