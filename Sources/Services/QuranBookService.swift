import Foundation

/// Charge uniquement le texte du mushaf demandé. Aucun texte n'est généré ou
/// recoloré localement : les balises de tajwid sont consommées telles quelles.
enum QuranBookService {
    enum ServiceError: LocalizedError {
        case invalidURL
        case invalidResponse
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "L'adresse du texte coranique est invalide."
            case .invalidResponse:
                return "Le texte coranique n'a pas pu être vérifié."
            case .emptyResponse:
                return "Aucun verset n'est disponible pour cette sourate."
            }
        }
    }

    static func load(surahNumber: Int, riwaya: QuranBookRiwaya) async throws -> QuranBookDocument {
        switch riwaya {
        case .warsh:
            return try loadBundledWarsh(surahNumber: surahNumber)
        case .khalaf:
            guard let url = Bundle.main.url(forResource: "khalaf", withExtension: "pdf") else {
                throw ServiceError.invalidResponse
            }
            return .pdf(url: url, page: pageNumber(for: surahNumber))
        case .hafs:
            return .verses(try await loadHafs(surahNumber: surahNumber))
        }
    }

    private static func loadHafs(surahNumber: Int) async throws -> [QuranBookVerse] {
        var components = URLComponents(
            string: "https://api.quran.com/api/v4/quran/verses/uthmani_tajweed"
        )
        components?.queryItems = [
            URLQueryItem(name: "chapter_number", value: String(surahNumber))
        ]

        guard let url = components?.url else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw ServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(QuranBookResponse.self, from: data)
        let verses = decoded.verses.sorted { $0.verseNumber < $1.verseNumber }
        guard !verses.isEmpty else {
            throw ServiceError.emptyResponse
        }
        return verses
    }

    private static func loadBundledWarsh(surahNumber: Int) throws -> QuranBookDocument {
        guard let url = Bundle.main.url(forResource: "warsh_surahs", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            throw ServiceError.invalidResponse
        }

        let surahs = try JSONDecoder().decode([WarshSurah].self, from: data)
        guard let surah = surahs.first(where: { $0.id == surahNumber }) else {
            throw ServiceError.emptyResponse
        }

        let verses = surah.ayahs.map { ayah in
            QuranBookVerse(
                id: ayah.id,
                verseKey: "\(ayah.surah):\(ayah.number)",
                textUthmani: ayah.text,
                textUthmaniTajweed: nil
            )
        }
        guard !verses.isEmpty else {
            throw ServiceError.emptyResponse
        }
        return .verses(verses)
    }

    private static func pageNumber(for surahNumber: Int) -> Int {
        guard let url = Bundle.main.url(forResource: "surahs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(SurahCatalogFile.self, from: data),
              let surah = catalog.surahs.first(where: { $0.number == surahNumber })
        else {
            return 1
        }
        return max(1, surah.page)
    }
}