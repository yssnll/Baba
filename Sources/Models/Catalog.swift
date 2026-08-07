import Foundation

// MARK: - Sourate

/// Métadonnées d'une sourate. Chargées depuis `surahs.json` (embarqué, donc hors ligne).
struct Surah: Codable, Identifiable, Hashable {
    let number: Int
    let nameAr: String
    let nameTranslit: String
    let nameFr: String
    let verses: Int
    let revelation: String
    let page: Int

    var id: Int { number }

    /// Numéro sur 3 chiffres, format utilisé par la quasi-totalité des serveurs audio.
    var padded: String { String(format: "%03d", number) }

    var isMeccan: Bool { revelation.hasPrefix("Mecq") }
}

// MARK: - Version de récitation

/// Une version enregistrée : un récitateur donné, dans une riwaya donnée, chez un fournisseur donné.
/// Un même récitateur peut en avoir plusieurs (Hafs murattal, Warsh, mujawwad…).
struct Recitation: Codable, Identifiable, Hashable {
    let id: String
    let provider: String
    let label: String
    let labelAr: String
    /// Gabarit d'URL. `{sss}` → numéro sur 3 chiffres, `{s}` → numéro brut.
    let urlTemplate: String
    /// Sourates réellement disponibles dans cette version.
    let surahList: [Int]

    func url(for surah: Int) -> URL? {
        let raw = urlTemplate
            .replacingOccurrences(of: "{sss}", with: String(format: "%03d", surah))
            .replacingOccurrences(of: "{s}", with: String(surah))
        return URL(string: raw)
    }

    var availableSet: Set<Int> { Set(surahList) }
    var isComplete: Bool { surahList.count >= 114 }

    var providerLabel: String {
        switch provider {
        case "mp3quran":     return "MP3Quran"
        case "quranicaudio": return "QuranicAudio"
        case "custom":       return "Ma source"
        default:             return provider.capitalized
        }
    }

    /// Nom court affichable, sans le préfixe « Rewayat » redondant.
    var shortLabel: String {
        label
            .replacingOccurrences(of: "Rewayat ", with: "")
            .replacingOccurrences(of: "Rewaya ", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Récitateur

struct Reciter: Codable, Identifiable, Hashable {
    // Mutables : la fusion des deux fournisseurs construit les récitateurs par
    // étapes — complète le nom arabe manquant, puis attribue l'identifiant
    // définitif une fois les doublons regroupés.
    var id: String
    var name: String
    var nameAr: String
    var letter: String
    var versions: [Recitation]
    /// Présent uniquement pour les récitateurs ajoutés par l'utilisateur.
    var isCustom: Bool?

    var custom: Bool { isCustom == true }

    /// Monogramme affiché dans la pastille du récitateur.
    var initials: String {
        let parts = name
            .components(separatedBy: .whitespaces)
            .filter { $0.count > 2 && !["al", "el", "abu", "bin", "ibn", "the"].contains($0.lowercased()) }
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init)
        if letters.isEmpty { return String(name.prefix(1)).uppercased() }
        return letters.joined().uppercased()
    }

    var completeVersions: [Recitation] { versions.filter(\.isComplete) }
    var hasArabicName: Bool { !nameAr.isEmpty }

    /// Version retenue par l'ajout en un appui : un mushaf complet si le
    /// récitateur en propose un, sinon la version la plus fournie.
    /// (`versions` est déjà trié par nombre de sourates décroissant.)
    var preferredVersion: Recitation? {
        completeVersions.first ?? versions.first
    }
}

// MARK: - Fichiers embarqués

struct ReciterCatalogFile: Codable {
    var version: Int = 2
    var sources: [String]?
    var reciters: [Reciter]
}

struct SurahCatalogFile: Codable {
    var version: Int = 1
    var surahs: [Surah]
}

// MARK: - Piste jouable

/// Unité de lecture : une sourate dans une version précise.
struct Track: Identifiable, Hashable, Codable {
    let reciterId: String
    let reciterName: String
    let reciterNameAr: String
    let recitation: Recitation
    let surah: Surah

    /// Clé stable, utilisée aussi comme identifiant de téléchargement.
    var id: String { "\(recitation.id)#\(surah.padded)" }

    var remoteURL: URL? { recitation.url(for: surah.number) }

    var subtitle: String {
        let v = recitation.shortLabel
        return v.isEmpty ? reciterName : "\(reciterName) · \(v)"
    }
}

// MARK: - État de téléchargement

/// `idle` plutôt que `none` : évite toute ambiguïté avec `Optional.none`
/// dans les expressions du type `states[key] ?? .idle`.
enum DownloadState: Equatable {
    case idle
    case waiting
    case downloading(progress: Double)
    case done
    case failed(String)

    var isActive: Bool {
        switch self {
        case .waiting, .downloading: return true
        default: return false
        }
    }

    var fraction: Double {
        if case .downloading(let p) = self { return p }
        if case .done = self { return 1 }
        return 0
    }

    var errorMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}
