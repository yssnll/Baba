import Foundation

/// Emplacements sur disque. Tout l'audio vit dans `Documents/Audio/<version>/<sss>.mp3`,
/// donc dans le conteneur de l'app : sauvegardé par iTunes/iCloud, effaçable par l'utilisateur.
enum Storage {

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var audioRoot: URL {
        documents.appendingPathComponent("Audio", isDirectory: true)
    }

    static var catalogCache: URL {
        documents.appendingPathComponent("catalog-v2.json")
    }

    static var customReciters: URL {
        documents.appendingPathComponent("custom-reciters.json")
    }

    /// Neutralise les caractères qui n'ont rien à faire dans un nom de dossier.
    static func slug(_ raw: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let cleaned = String(raw.map { allowed.contains($0) ? $0 : "-" })
        return cleaned.isEmpty ? "unknown" : String(cleaned.prefix(80))
    }

    static func folder(for recitationId: String) -> URL {
        audioRoot.appendingPathComponent(slug(recitationId), isDirectory: true)
    }

    static func file(recitationId: String, surah: Int) -> URL {
        folder(for: recitationId)
            .appendingPathComponent(String(format: "%03d.mp3", surah))
    }

    static func exists(recitationId: String, surah: Int) -> Bool {
        FileManager.default.fileExists(atPath: file(recitationId: recitationId, surah: surah).path)
    }

    @discardableResult
    static func ensureFolder(for recitationId: String) -> URL {
        let dir = folder(for: recitationId)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Exclut le dossier audio des sauvegardes : ces fichiers sont retéléchargeables,
    /// inutile de gonfler l'archive iCloud de l'utilisateur.
    static func excludeAudioFromBackup() {
        var dir = audioRoot
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
    }

    // MARK: Inventaire

    static func size(of url: URL) -> Int64 {
        let v = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(v?.fileSize ?? 0)
    }

    /// Total occupé par l'audio téléchargé.
    static func totalAudioBytes() -> Int64 {
        guard let e = FileManager.default.enumerator(
            at: audioRoot,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in e where url.pathExtension.lowercased() == "mp3" {
            total += size(of: url)
        }
        return total
    }

    /// Sourates présentes localement, groupées par identifiant de version.
    static func inventory() -> [String: Set<Int>] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(
            at: audioRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [:] }

        var out: [String: Set<Int>] = [:]
        for dir in dirs {
            guard let files = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            let numbers = files.compactMap { f -> Int? in
                guard f.pathExtension.lowercased() == "mp3" else { return nil }
                return Int(f.deletingPathExtension().lastPathComponent)
            }
            if !numbers.isEmpty { out[dir.lastPathComponent] = Set(numbers) }
        }
        return out
    }

    static func delete(recitationId: String, surah: Int) {
        try? FileManager.default.removeItem(at: file(recitationId: recitationId, surah: surah))
    }

    static func deleteAll(recitationId: String) {
        try? FileManager.default.removeItem(at: folder(for: recitationId))
    }

    static func deleteEverything() {
        try? FileManager.default.removeItem(at: audioRoot)
        try? FileManager.default.createDirectory(at: audioRoot, withIntermediateDirectories: true)
    }
}
