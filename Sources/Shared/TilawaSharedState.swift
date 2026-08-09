import Foundation
import WidgetKit

/// État minimal partagé entre l'app et l'extension WidgetKit.
/// Le catalogue et les fichiers audio ne quittent jamais le conteneur de l'app.
enum TilawaSharedState {
    static let appGroup = "group.app.tilawa"
    static let widgetSnapshot = "widget.snapshot"
    static let widgetCommand = "widget.command"
    static let widgetKind = "TilawaWidget"
    private static let snapshotFilename = "widget-snapshot.json"

    // Palette recopiée dans l'App Group pour que l'extension WidgetKit
    // reflète l'apparence choisie dans l'application.
    static let appearanceBackground = "appearance.background"
    static let appearanceSurface = "appearance.surface"
    static let appearanceAccent = "appearance.accent"
    static let appearanceGold = "appearance.gold"
    static let appearanceText = "appearance.text"
    static let appearanceMuted = "appearance.muted"
    static let appearanceSuccess = "appearance.success"

    /// Retourne le conteneur partagé uniquement si l'entitlement App Group est
    /// réellement présent dans le binaire signé. Cette vérification permet de
    /// distinguer un problème de code d'un problème de re-signature eSign.
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup
        )
    }

    static var sharedDefaults: UserDefaults? {
        // `suiteName` peut parfois créer une instance même quand l'entitlement
        // manque dans une IPA re-signée. Le conteneur est le vrai test.
        guard sharedContainerURL != nil else { return nil }
        return UserDefaults(suiteName: appGroup)
    }

    static var isAppGroupAvailable: Bool {
        sharedContainerURL != nil && sharedDefaults != nil
    }

    static var availabilityMessage: String {
        if isAppGroupAvailable {
            return "App Group active · \(appGroup)"
        }
        return "App Group absente · l'IPA doit être re-signée avec \(appGroup)"
    }

    static var snapshotURL: URL? {
        sharedContainerURL?.appendingPathComponent(snapshotFilename)
    }

    /// Écrit d'abord un fichier atomique dans le conteneur partagé. UserDefaults
    /// reste un repli pour les installations plus anciennes et pour éviter
    /// qu'un widget déjà en cache ne perde son état pendant la migration.
    @discardableResult
    static func writeSnapshot(_ snapshot: TilawaWidgetSnapshot) -> Bool {
        guard let data = try? JSONEncoder().encode(snapshot) else { return false }

        var didWrite = false
        if let url = snapshotURL {
            do {
                try data.write(to: url, options: [.atomic])
                didWrite = true
            } catch {
                didWrite = false
            }
        }

        if let defaults = sharedDefaults {
            defaults.set(data, forKey: widgetSnapshot)
            defaults.synchronize()
            didWrite = true
        }
        return didWrite
    }

    static func readSnapshot() -> TilawaWidgetSnapshot? {
        if let url = snapshotURL,
           let data = try? Data(contentsOf: url),
           let snapshot = try? JSONDecoder().decode(
               TilawaWidgetSnapshot.self, from: data
           ) {
            return snapshot
        }

        guard let data = sharedDefaults?.data(forKey: widgetSnapshot) else {
            return nil
        }
        return try? JSONDecoder().decode(TilawaWidgetSnapshot.self, from: data)
    }
}

/// Snapshot atomique lu par l'extension WidgetKit.
/// Un seul objet évite qu'un widget lise le titre d'une piste avec l'état
/// lecture/pause de la piste précédente pendant une mise à jour.
struct TilawaWidgetSnapshot: Codable {
    let title: String?
    let subtitle: String?
    let hasTrack: Bool
    let isPlaying: Bool
    let position: Double
    let duration: Double
    let updatedAt: TimeInterval
}

enum TilawaWidgetCommandAction: String, Codable {
    case toggle
    case next
    case previous
}

struct TilawaWidgetCommand: Codable {
    let id: String
    let action: TilawaWidgetCommandAction
    let createdAt: TimeInterval

    init(action: TilawaWidgetCommandAction) {
        id = UUID().uuidString
        self.action = action
        createdAt = Date().timeIntervalSince1970
    }
}

enum TilawaWidgetCommandStore {
    static func send(_ action: TilawaWidgetCommandAction) {
        guard let defaults = TilawaSharedState.sharedDefaults,
              let data = try? JSONEncoder().encode(TilawaWidgetCommand(action: action))
        else { return }

        defaults.set(data, forKey: TilawaSharedState.widgetCommand)
        defaults.synchronize()
        WidgetCenter.shared.reloadTimelines(ofKind: TilawaSharedState.widgetKind)
    }
}