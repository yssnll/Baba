import Foundation

/// Catalogue des récitateurs et des sourates.
///
/// Trois couches, dans cet ordre de priorité :
/// 1. `custom-reciters.json` — les sources ajoutées par l'utilisateur ;
/// 2. `catalog-v2.json` en Documents — dernière synchronisation réseau ;
/// 3. `reciters.json` embarqué dans le bundle — toujours présent, donc l'app
///    n'est jamais vide au premier lancement ni sans réseau.
final class CatalogStore: ObservableObject {
    static let shared = CatalogStore()

    @Published private(set) var catalog: [Reciter] = []
    @Published private(set) var surahs: [Surah] = []
    @Published private(set) var custom: [Reciter] = []
    @Published var favorites: Set<String> = []

    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?
    @Published var refreshMessage: String?
    @Published private(set) var refreshSucceeded: Bool?
    @Published private(set) var isLoadingCatalog = true
    @Published private(set) var riwayaCounts: [Riwaya: Int] = [:]

    private let favoritesKey = "tilawa.favorites"
    private let lastRefreshKey = "tilawa.lastRefresh"

    private init() {
        favorites = Set(UserDefaults.standard.stringArray(forKey: favoritesKey) ?? [])
        lastRefresh = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date

        // Le cache peut contenir plusieurs centaines de récitateurs. Toute
        // lecture/décodage de fichiers est volontairement hors du thread UI.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let loadedSurahs = Self.loadSurahsFromDisk()
            let loadedCatalog = Self.loadCatalogFromDisk()
            let loadedCustom = Self.loadCustomFromDisk()

            DispatchQueue.main.async {
                guard let self else { return }
                self.surahs = loadedSurahs
                self.catalog = loadedCatalog
                self.custom = loadedCustom
                self.recalculateRiwayaCounts()
                self.isLoadingCatalog = false
            }
        }
    }

    /// Sources utilisateur d'abord : ce que l'on a ajouté soi-même doit être à portée de main.
    var allReciters: [Reciter] { custom + catalog }

    var totalVersions: Int { allReciters.reduce(0) { $0 + $1.versions.count } }

    var availableRiwayas: [Riwaya] {
        Riwaya.filterableCases.filter { riwayaCounts[$0, default: 0] > 0 }
    }

    func surah(_ number: Int) -> Surah? { surahs.first { $0.number == number } }

    func reciter(id: String) -> Reciter? { allReciters.first { $0.id == id } }

    // MARK: - Chargement local

    private static func loadSurahsFromDisk() -> [Surah] {
        if let file: SurahCatalogFile = Self.decodeBundled("surahs") {
            return file.surahs.sorted { $0.number < $1.number }
        }
        return []
    }

    private static func loadCatalogFromDisk() -> [Reciter] {
        // Cache réseau d'abord, bundle en repli.
        if let data = try? Data(contentsOf: Storage.catalogCache),
           let file = try? JSONDecoder().decode(ReciterCatalogFile.self, from: data),
           !file.reciters.isEmpty {
            return Self.groupExistingReciters(file.reciters)
        }
        if let file: ReciterCatalogFile = Self.decodeBundled("reciters") {
            return Self.groupExistingReciters(file.reciters)
        }
        return []
    }

    private static func loadCustomFromDisk() -> [Reciter] {
        guard let data = try? Data(contentsOf: Storage.customReciters),
              let list = try? JSONDecoder().decode([Reciter].self, from: data)
        else { return [] }
        return list
    }

    private static func decodeBundled<T: Decodable>(_ name: String) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Favoris

    func toggleFavorite(_ reciterId: String) {
        if favorites.contains(reciterId) { favorites.remove(reciterId) }
        else { favorites.insert(reciterId) }
        UserDefaults.standard.set(Array(favorites), forKey: favoritesKey)
    }

    func isFavorite(_ reciterId: String) -> Bool { favorites.contains(reciterId) }

    // MARK: - Récitateurs personnalisés

    private func loadCustom() {
        custom = Self.loadCustomFromDisk()
        recalculateRiwayaCounts()
    }

    private func persistCustom() {
        guard let data = try? JSONEncoder().encode(custom) else { return }
        try? data.write(to: Storage.customReciters, options: .atomic)
    }

    /// Ajoute une source manuelle. `template` doit contenir `{sss}` ou `{s}` ;
    /// sinon on considère que c'est un dossier et on complète le gabarit.
    /// Renvoie `nil` si tout va bien, un message d'erreur sinon.
    func addCustomReciter(name: String, nameAr: String, template rawTemplate: String,
                          versionLabel: String) -> String? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var template = rawTemplate.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else { return "Le nom du récitateur est obligatoire." }
        guard !template.isEmpty else { return "L'adresse de la source est obligatoire." }

        if !template.contains("{sss}") && !template.contains("{s}") {
            if !template.hasSuffix("/") { template += "/" }
            template += "{sss}.mp3"
        }

        guard let probe = URL(string: template.replacingOccurrences(of: "{sss}", with: "001")
                                              .replacingOccurrences(of: "{s}", with: "1")),
              let scheme = probe.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              probe.host != nil
        else { return "Adresse invalide. Attendu : http(s)://serveur/dossier/" }

        let uid = "cst-\(UUID().uuidString.prefix(8))"
        let recitation = Recitation(
            id: uid,
            provider: "custom",
            label: versionLabel.isEmpty ? "Ma source" : versionLabel,
            labelAr: "",
            sourceName: name,
            urlTemplate: template,
            surahList: Array(1...114)
        )
        let reciter = Reciter(
            id: "u-\(uid)",
            name: name,
            nameAr: nameAr.trimmingCharacters(in: .whitespacesAndNewlines),
            letter: String(name.prefix(1)).uppercased(),
            versions: [recitation],
            nameVariants: [name],
            isCustom: true
        )
        custom.insert(reciter, at: 0)
        recalculateRiwayaCounts()
        persistCustom()
        return nil
    }

    func removeCustomReciter(id: String) {
        guard let idx = custom.firstIndex(where: { $0.id == id }) else { return }
        for v in custom[idx].versions { Storage.deleteAll(recitationId: v.id) }
        custom.remove(at: idx)
        recalculateRiwayaCounts()
        persistCustom()
    }

    // MARK: - Synchronisation réseau

    /// Réinterroge les deux fournisseurs et reconstruit le catalogue fusionné.
    /// Sans réseau, on conserve simplement ce qui est déjà en place.
    func refresh() async {
        // Prise du verrou sur le thread principal : évite deux synchros concurrentes.
        let acquired = await MainActor.run { () -> Bool in
            guard !self.isRefreshing else { return false }
            self.isRefreshing = true
            self.refreshMessage = nil
            self.refreshSucceeded = nil
            return true
        }
        guard acquired else { return }

        async let mp3 = Self.fetchMP3Quran()
        async let qa = Self.fetchQuranicAudio()
        let (a, b) = await (mp3, qa)

        func finish(_ message: String?, failed: Bool = true) async {
            await MainActor.run {
                if let message { self.refreshMessage = message }
                self.refreshSucceeded = !failed
                self.isRefreshing = false
            }
        }

        guard !a.isEmpty || !b.isEmpty else {
            await finish("Synchronisation impossible — vérifie ta connexion.")
            return
        }

        let merged = Self.merge(mp3quran: a, quranicAudio: b)
        // Garde-fou : une réponse tronquée ne doit pas écraser un catalogue complet.
        guard merged.count >= 50 else {
            await finish("Réponse incomplète des serveurs, catalogue conservé.")
            return
        }

        let file = ReciterCatalogFile(version: 2,
                                      sources: ["mp3quran.net", "quranicaudio.com"],
                                      reciters: merged)
        if let data = try? JSONEncoder().encode(file) {
            try? data.write(to: Storage.catalogCache, options: .atomic)
        }
        let stamp = Date()
        UserDefaults.standard.set(stamp, forKey: lastRefreshKey)
        let versions = merged.reduce(0) { $0 + $1.versions.count }

        await MainActor.run {
            self.catalog = merged
            self.recalculateRiwayaCounts()
            self.lastRefresh = stamp
            self.refreshMessage = "\(merged.count) récitateurs · \(versions) versions"
            self.refreshSucceeded = true
            self.isRefreshing = false
        }
    }

    private func recalculateRiwayaCounts() {
        riwayaCounts = allReciters
            .flatMap(\.versions)
            .reduce(into: [:]) { counts, version in
                counts[version.riwaya, default: 0] += 1
            }
    }

    // MARK: Fournisseurs

    private struct MQResponse: Decodable {
        struct Moshaf: Decodable {
            let id: Int
            let name: String
            let server: String
            let surah_total: Int?
            let surah_list: String?
        }
        struct Reciter: Decodable {
            let id: Int
            let name: String
            let letter: String?
            let moshaf: [Moshaf]
        }
        let reciters: [Reciter]
    }

    private struct QAQari: Decodable {
        let id: Int
        let name: String
        let arabic_name: String?
        let relative_path: String?
        let file_formats: String?
    }

    /// Renvoie les récitateurs mp3quran, noms latins et arabes appariés par identifiant.
    private static func fetchMP3Quran() async -> [(en: MQResponse.Reciter, ar: MQResponse.Reciter?)] {
        async let enTask: MQResponse? = get("https://mp3quran.net/api/v3/reciters?language=eng")
        async let arTask: MQResponse? = get("https://mp3quran.net/api/v3/reciters?language=ar")
        let (en, ar) = await (enTask, arTask)
        guard let en else { return [] }
        let arIndex = Dictionary(uniqueKeysWithValues: (ar?.reciters ?? []).map { ($0.id, $0) })
        return en.reciters.map { ($0, arIndex[$0.id]) }
    }

    private static func fetchQuranicAudio() async -> [QAQari] {
        await get("https://quranicaudio.com/api/qaris") ?? []
    }

    private static func get<T: Decodable>(_ urlString: String) async -> T? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 25
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
            else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: Fusion

    /// Regroupe les deux fournisseurs en une liste de personnes.
    /// Rapprochement par nom arabe normalisé (fiable), puis par translittération
    /// latine réduite en repli — les translittérations varient trop pour s'y fier seules.
    private static func merge(mp3quran: [(en: MQResponse.Reciter, ar: MQResponse.Reciter?)],
                              quranicAudio: [QAQari]) -> [Reciter] {
        var people: [Reciter] = []
        var byArabic: [String: Int] = [:]
        var byLatin: [String: Int] = [:]

        func index(name: String, nameAr: String) -> Int {
            let displayName = cleanDisplayName(tidy(name))
            let ka = arabicIdentity(nameAr)
            let kl = normalizeLatin(name)
            var found: Int?
            if !ka.isEmpty { found = byArabic[ka] }
            if found == nil, !kl.isEmpty { found = byLatin[latinIdentity(name)] }

            if let i = found {
                people[i].nameVariants = uniqueNames(people[i].nameVariants + [displayName])
                if people[i].nameAr.isEmpty, !nameAr.isEmpty { people[i].nameAr = nameAr }
                if !ka.isEmpty, byArabic[ka] == nil { byArabic[ka] = i }
                if !kl.isEmpty {
                    byLatin[kl] = i
                    byLatin[latinIdentity(name)] = i
                }
                return i
            }
            people.append(Reciter(id: "", name: displayName, nameAr: nameAr,
                                  letter: String(displayName.prefix(1)).uppercased(),
                                  versions: [], nameVariants: [displayName], isCustom: nil))
            let i = people.count - 1
            if !ka.isEmpty { byArabic[ka] = i }
            if !kl.isEmpty {
                byLatin[kl] = i
                byLatin[latinIdentity(name)] = i
            }
            return i
        }

        for entry in mp3quran {
            let arMoshafs = Dictionary(uniqueKeysWithValues:
                (entry.ar?.moshaf ?? []).map { ($0.id, $0.name) })
            let i = index(name: tidy(entry.en.name), nameAr: tidy(entry.ar?.name ?? ""))
            for m in entry.en.moshaf {
                let list = (m.surah_list ?? "")
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    .filter { (1...114).contains($0) }
                guard !list.isEmpty else { continue }
                var server = m.server.trimmingCharacters(in: .whitespaces)
                if !server.hasSuffix("/") { server += "/" }
                people[i].versions.append(Recitation(
                    id: "mq-\(entry.en.id)-\(m.id)",
                    provider: "mp3quran",
                    label: tidy(m.name),
                    labelAr: tidy(arMoshafs[m.id] ?? ""),
                    sourceName: tidy(entry.en.name),
                    urlTemplate: server + "{sss}.mp3",
                    surahList: list.sorted()
                ))
            }
        }

        for q in quranicAudio {
            guard (q.file_formats ?? "").contains("mp3") else { continue }
            var path = (q.relative_path ?? "").trimmingCharacters(in: .whitespaces)
            guard !path.isEmpty else { continue }
            if !path.hasSuffix("/") { path += "/" }
            let i = index(name: tidy(q.name), nameAr: tidy(q.arabic_name ?? ""))
            people[i].versions.append(Recitation(
                id: "qa-\(q.id)",
                provider: "quranicaudio",
                label: "Mushaf complet (QuranicAudio)",
                labelAr: "المصحف كامل",
                sourceName: tidy(q.name),
                urlTemplate: "https://download.quranicaudio.com/quran/\(path){sss}.mp3",
                surahList: Array(1...114)
            ))
        }

        // Identifiants stables, versions les plus complètes en tête.
        var out: [Reciter] = []
        for (n, var p) in people.enumerated() where !p.versions.isEmpty {
            p.id = "r\(n + 1)"
            p.versions.sort {
                $0.surahList.count != $1.surahList.count
                    ? $0.surahList.count > $1.surahList.count
                    : $0.label < $1.label
            }
            out.append(p)
        }
        out.sort { $0.name.lowercased() < $1.name.lowercased() }
        return out
    }

    /// Regroupe aussi les doublons déjà présents dans le JSON embarqué ou le
    /// cache. Ainsi la correction est visible immédiatement, sans attendre une
    /// nouvelle synchronisation réseau.
    private static func groupExistingReciters(_ input: [Reciter]) -> [Reciter] {
        var grouped: [Reciter] = []
        var indexes: [String: Int] = [:]

        for original in input {
            let name = tidy(original.name)
            let keys = identityKeys(name: name, nameAr: original.nameAr)
            let index = keys.compactMap { indexes[$0] }.first ?? {
                var copy = original
                copy.name = cleanDisplayName(name)
                copy.letter = String(copy.name.prefix(1)).uppercased()
                copy.nameVariants = uniqueNames(original.nameVariants + [name])
                copy.versions = []
                grouped.append(copy)
                return grouped.count - 1
            }()

            for key in keys where indexes[key] == nil { indexes[key] = index }
            merge(original, into: &grouped[index])
        }

        for idx in grouped.indices {
            grouped[idx].versions = uniqueVersions(grouped[idx].versions)
            grouped[idx].versions.sort {
                $0.surahList.count != $1.surahList.count
                    ? $0.surahList.count > $1.surahList.count
                    : $0.label < $1.label
            }
            grouped[idx].nameVariants = uniqueNames(grouped[idx].nameVariants)
        }
        return grouped.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func identityKeys(name: String, nameAr: String) -> [String] {
        var keys = ["latin:\(latinIdentity(name))"]
        let arabic = arabicIdentity(nameAr)
        if !arabic.isEmpty { keys.append("arabic:\(arabic)") }
        return keys
    }

    private static func merge(_ source: Reciter, into target: inout Reciter) {
        target.nameVariants = uniqueNames(target.nameVariants + [source.name])
        if target.nameAr.isEmpty, !source.nameAr.isEmpty { target.nameAr = source.nameAr }
        target.versions.append(contentsOf: source.versions.map { version in
            if version.sourceName.isEmpty {
                return Recitation(id: version.id, provider: version.provider,
                                  label: version.label, labelAr: version.labelAr,
                                  sourceName: source.name, urlTemplate: version.urlTemplate,
                                  surahList: version.surahList)
            }
            return version
        })
    }

    private static func uniqueVersions(_ versions: [Recitation]) -> [Recitation] {
        var seen = Set<String>()
        return versions.filter { seen.insert($0.id).inserted }
    }

    private static func uniqueNames(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names
            .map { cleanDisplayName(tidy($0)) }
            .filter { !$0.isEmpty && seen.insert(latinIdentity($0)).inserted }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func cleanDisplayName(_ name: String) -> String {
        let withoutQualifier = name.replacingOccurrences(
            of: #"\s*(\[[^]]+\]|\([^)]*\))\s*$"#,
            with: "",
            options: .regularExpression
        )
        return tidy(withoutQualifier).isEmpty ? name : tidy(withoutQualifier)
    }

    private static func tidy(_ s: String) -> String {
        s.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func normalizeArabic(_ s: String) -> String {
        guard !s.isEmpty else { return "" }
        var out = s.folding(options: [.diacriticInsensitive], locale: nil)
        let unify: [Character: Character] = [
            "أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا",
            "ى": "ي", "ئ": "ي", "ة": "ه", "ؤ": "و",
        ]
        out = String(out.map { unify[$0] ?? $0 })
        for honorific in ["الشيخ", "القارئ", "الدكتور", "الحاج"] {
            out = out.replacingOccurrences(of: honorific, with: "")
        }
        // Ne garde que le bloc arabe de base, tatweel exclu.
        return String(out.unicodeScalars.filter { (0x0621...0x063A).contains($0.value)
                                              || (0x0641...0x064A).contains($0.value) }
                         .map(Character.init))
    }

    private static func arabicIdentity(_ s: String) -> String {
        var value = s
        value = value.replacingOccurrences(
            of: #"\s*[-–—].*$"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\s*(\[[^]]+\]|\([^)]*\)).*$"#,
            with: "",
            options: .regularExpression
        )
        return normalizeArabic(value)
    }

    private static func normalizeLatin(_ s: String) -> String {
        let stop: Set<String> = ["al", "el", "as", "ash", "ad", "abu", "abd",
                                 "ibn", "bin", "sheikh", "shaikh", "dr", ""]
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.lowercased() }
            .filter { !stop.contains($0) }
            .joined()
            .filter { $0.isLetter }
    }

    /// Clé de personne : ignore les qualificatifs de version (Taraweeh,
    /// Warsh, traductions…) et les petites différences de translittération.
    /// Les noms contenant « with » restent volontairement distincts : ils
    /// désignent une récitation avec traduction, pas un nouveau réciteur.
    private static func latinIdentity(_ s: String) -> String {
        var value = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        value = value.replacingOccurrences(
            of: #"\s*(\[[^]]+\]|\([^)]*\))"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(of: "dr.", with: "")
        value = value.replacingOccurrences(of: "shaik ", with: "")
        value = value.replacingOccurrences(of: "sheikh ", with: "")
        value = value.replacingOccurrences(of: "abu ", with: "")
        value = value.replacingOccurrences(of: "abd ", with: "")
        value = value.replacingOccurrences(of: "al-", with: "")
        value = value.replacingOccurrences(of: "el-", with: "")
        value = value.replacingOccurrences(of: "al ", with: "")
        value = value.replacingOccurrences(of: "el ", with: "")
        value = value.replacingOccurrences(of: "ou", with: "u")
        value = value.replacingOccurrences(of: "oo", with: "u")
        value = value.replacingOccurrences(of: "ee", with: "i")
        value = value.replacingOccurrences(of: "ei", with: "i")
        value = value.replacingOccurrences(of: "aa", with: "a")
        value = value.replacingOccurrences(of: "th", with: "t")
        value = value.replacingOccurrences(of: "dh", with: "d")
        value = value.replacingOccurrences(of: "kh", with: "h")
        value = value.replacingOccurrences(of: "gh", with: "g")
        return value
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}
