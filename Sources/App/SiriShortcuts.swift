import AppIntents
/// Point d'entrée commun aux commandes Siri et aux liens provenant des widgets.
enum TilawaPlaybackRouter {
    @discardableResult
    static func play(surahNumber: Int, reciterID: String? = nil,
                    reciterName: String? = nil) async -> Track? {
        await CatalogStore.shared.waitUntilReady()
        guard let tracks = CatalogStore.shared.playbackTracks(
            surahNumber: surahNumber, reciterId: reciterID, reciterQuery: reciterName
        ), let first = tracks.first else {
            return nil
        }

        await MainActor.run {
            PlayerService.shared.play(first, in: tracks)
        }
        return first
    }

    static func handle(url: URL) async {
        switch url.host?.lowercased() {
        case "play":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let surah = Int(components?.queryItems?.first(where: { $0.name == "surah" })?.value ?? "")
            let reciterID = components?.queryItems?.first(where: { $0.name == "reciter" })?.value
            if let surah { _ = await play(surahNumber: surah, reciterID: reciterID) }
        case "resume":
            await MainActor.run {
                let player = PlayerService.shared
                if player.current != nil {
                    player.play()
                } else {
                    player.resumeSavedTrack()
                }
            }
        case "toggle":
            await MainActor.run { PlayerService.shared.togglePlayPause() }
        case "next":
            await MainActor.run { PlayerService.shared.next() }
        case "previous":
            await MainActor.run { PlayerService.shared.previous() }
        default:
            break
        }
    }
}

struct TilawaSurahEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sourate")
    static let defaultQuery = TilawaSurahQuery()

    let id: String
    let number: Int
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(number). \(name)")
    }
}

struct TilawaSurahQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [TilawaSurahEntity.ID]) async -> [TilawaSurahEntity] {
        await CatalogStore.shared.waitUntilReady()
        let wanted = Set(identifiers.compactMap(Int.init))
        return CatalogStore.shared.surahs
            .filter { wanted.contains($0.number) }
            .map { TilawaSurahEntity(id: String($0.number), number: $0.number, name: $0.nameTranslit) }
    }

    func suggestedEntities() async -> [TilawaSurahEntity] {
        await CatalogStore.shared.waitUntilReady()
        return CatalogStore.shared.surahs.map {
            TilawaSurahEntity(id: String($0.number), number: $0.number, name: $0.nameTranslit)
        }
    }

    func entities(matching string: String) async throws -> [TilawaSurahEntity] {
        await CatalogStore.shared.waitUntilReady()
        guard let surah = CatalogStore.shared.surah(matching: string) else {
            return []
        }
        return [
            TilawaSurahEntity(
                id: String(surah.number),
                number: surah.number,
                name: surah.nameTranslit
            )
        ]
    }
}

struct TilawaReciterEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Récitateur")
    static let defaultQuery = TilawaReciterQuery()

    let id: String
    let name: String
    let nameAr: String

    var displayRepresentation: DisplayRepresentation {
        if nameAr.isEmpty {
            return DisplayRepresentation(title: "\(name)")
        }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(nameAr)")
    }
}

struct TilawaReciterQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [TilawaReciterEntity.ID]) async -> [TilawaReciterEntity] {
        await CatalogStore.shared.waitUntilReady()
        let wanted = Set(identifiers)
        return CatalogStore.shared.allReciters
            .filter { wanted.contains($0.id) }
            .map { TilawaReciterEntity(id: $0.id, name: $0.name, nameAr: $0.nameAr) }
    }

    func suggestedEntities() async -> [TilawaReciterEntity] {
        await CatalogStore.shared.waitUntilReady()
        return CatalogStore.shared.allReciters.map {
            TilawaReciterEntity(id: $0.id, name: $0.name, nameAr: $0.nameAr)
        }
    }

    /// Permet à Siri de résoudre une transcription approximative comme
    /// « Muaqly » vers « Maher al-Muaiqly » sans demander une sélection
    /// manuelle dans la liste complète.
    func entities(matching string: String) async throws -> [TilawaReciterEntity] {
        await CatalogStore.shared.waitUntilReady()
        guard let reciter = CatalogStore.shared.reciter(matching: string) else {
            return []
        }
        return [
            TilawaReciterEntity(id: reciter.id, name: reciter.name, nameAr: reciter.nameAr)
        ]
    }
}

struct PlayTilawaSurahIntent: AppIntent {
    static let title: LocalizedStringResource = "Lire une sourate"
    static let description = IntentDescription("Lance une sourate avec le récitateur choisi.")
    static let openAppWhenRun = true

    @Parameter(title: "Sourate")
    var surah: TilawaSurahEntity

    @Parameter(title: "Récitateur")
    var reciter: TilawaReciterEntity

    func perform() async throws -> some IntentResult {
        _ = await TilawaPlaybackRouter.play(
            surahNumber: surah.number, reciterID: reciter.id
        )
        return .result()
    }
}

struct PlayTilawaReciterIntent: AppIntent {
    static let title: LocalizedStringResource = "Lire avec un récitateur"
    static let description = IntentDescription("Lance la Fatiha avec le récitateur choisi.")
    static let openAppWhenRun = true

    @Parameter(title: "Récitateur")
    var reciter: TilawaReciterEntity

    func perform() async throws -> some IntentResult {
        _ = await TilawaPlaybackRouter.play(surahNumber: 1, reciterID: reciter.id)
        return .result()
    }
}

struct TilawaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayTilawaSurahIntent(),
            phrases: [
                "Lis \(\.$surah) avec \(\.$reciter) dans \(.applicationName)",
                "Lis la sourate \(\.$surah) avec \(\.$reciter)",
                "Lis la sourate \(\.$surah) avec \(\.$reciter) dans \(.applicationName)",
                "Mets \(\.$surah) avec \(\.$reciter) dans \(.applicationName)",
                "Mets la sourate \(\.$surah) avec \(\.$reciter)",
                "Mets la sourate \(\.$surah) avec \(\.$reciter) dans \(.applicationName)",
                "Lance la sourate \(\.$surah) avec \(\.$reciter) dans \(.applicationName)",
                "Joue \(\.$surah) avec \(\.$reciter) dans \(.applicationName)"
            ],
            shortTitle: "Lire une sourate",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: PlayTilawaReciterIntent(),
            phrases: [
                "Lis avec \(\.$reciter) dans \(.applicationName)",
                "Lis avec \(\.$reciter)",
                "Mets \(\.$reciter) dans \(.applicationName)",
                "Mets \(\.$reciter)",
                "Lance la récitation avec \(\.$reciter) dans \(.applicationName)",
                "Joue avec \(\.$reciter) dans \(.applicationName)"
            ],
            shortTitle: "Lire avec un récitateur",
            systemImageName: "person.wave.2.fill"
        )
    }
}