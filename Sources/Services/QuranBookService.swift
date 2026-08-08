import Foundation

/// Charge uniquement le texte du mushaf demandé. Aucun texte n'est généré ou
/// recoloré localement : les balises de tajwid sont consommées telles quelles.
enum QuranBookService {
    enum ServiceError: LocalizedError {
        case invalidSurah
        case invalidURL
        case invalidResponse
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .invalidSurah:
                return "Cette sourate n'existe pas."
            case .invalidURL:
                return "L'adresse du texte coranique est invalide."
            case .invalidResponse:
                return "Le texte coranique n'a pas pu être vérifié."
            case .emptyResponse:
                return "Aucun verset n'est disponible pour cette sourate."
            }
        }
    }

    private actor Cache {
        private var documents: [Int: QuranBookDocument] = [:]

        func document(for surahNumber: Int) -> QuranBookDocument? {
            documents[surahNumber]
        }

        func insert(_ document: QuranBookDocument, for surahNumber: Int) {
            documents[surahNumber] = document
        }
    }

    private static let cache = Cache()

    static func load(surahNumber: Int) async throws -> QuranBookDocument {
        guard (1...114).contains(surahNumber) else {
            throw ServiceError.invalidSurah
        }

        if let cached = await cache.document(for: surahNumber) {
            return cached
        }

        let verses: [QuranBookVerse]
        do {
            verses = try await loadHafs(surahNumber: surahNumber)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Quran.com peut refuser une requête ponctuellement selon le
            // réseau, le pays ou la limite de trafic. Le texte Uthmani
            // d'AlQuran.cloud garde la lecture disponible pour les 114
            // sourates, même si le balisage tajwid n'est pas accessible.
            verses = try await loadPlainHafs(surahNumber: surahNumber)
        }

        let document = QuranBookDocument(verses: verses)
        await cache.insert(document, for: surahNumber)
        return document
    }

    private static func loadHafs(surahNumber: Int) async throws -> [QuranBookVerse] {
        var components = URLComponents(
            string: "https://api.quran.com/api/v4/quran/verses/uthmani_tajweed"
        )
        components?.queryItems = [
            URLQueryItem(name: "chapter_number", value: String(surahNumber)),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "per_page", value: "300")
        ]

        guard let url = components?.url else {
            throw ServiceError.invalidURL
        }

        var lastError: Error = ServiceError.invalidResponse

        // Une requête peut échouer ponctuellement (réseau mobile, délai ou
        // limitation distante). Chaque sourate est donc retentée séparément
        // au lieu de laisser l'écran rester bloqué sur la première.
        for attempt in 0..<3 {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 25
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("Tilawa/3.7", forHTTPHeaderField: "User-Agent")

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
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if attempt < 2 {
                    try await Task.sleep(
                        nanoseconds: UInt64(350_000_000 * (attempt + 1))
                    )
                }
            }
        }

        throw lastError
    }

    private static func loadPlainHafs(surahNumber: Int) async throws -> [QuranBookVerse] {
        guard let url = URL(
            string: "https://api.alquran.cloud/v1/surah/\(surahNumber)/quran-uthmani"
        ) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Tilawa/3.7", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw ServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(AlQuranCloudResponse.self, from: data)
        let verses = decoded.data.ayahs.map { ayah in
            QuranBookVerse(
                id: ayah.number,
                verseKey: "\(surahNumber):\(ayah.numberInSurah)",
                textUthmani: ayah.text,
                textUthmaniTajweed: nil
            )
        }
        guard !verses.isEmpty else {
            throw ServiceError.emptyResponse
        }
        return verses
    }

}

private struct AlQuranCloudResponse: Decodable {
    let data: AlQuranCloudSurah
}

private struct AlQuranCloudSurah: Decodable {
    let ayahs: [AlQuranCloudAyah]
}

private struct AlQuranCloudAyah: Decodable {
    let number: Int
    let numberInSurah: Int
    let text: String
}