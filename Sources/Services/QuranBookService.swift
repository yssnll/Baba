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

    static func load(surahNumber: Int) async throws -> QuranBookDocument {
        .verses(try await loadHafs(surahNumber: surahNumber))
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

}