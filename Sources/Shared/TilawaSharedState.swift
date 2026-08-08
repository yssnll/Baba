import Foundation

/// État minimal partagé entre l'app et l'extension WidgetKit.
/// Le catalogue et les fichiers audio ne quittent jamais le conteneur de l'app.
enum TilawaSharedState {
    static let appGroup = "group.app.tilawa"
    static let widgetSnapshot = "widget.snapshot"

    // Palette recopiée dans l'App Group pour que l'extension WidgetKit
    // reflète l'apparence choisie dans l'application.
    static let appearanceBackground = "appearance.background"
    static let appearanceSurface = "appearance.surface"
    static let appearanceAccent = "appearance.accent"
    static let appearanceGold = "appearance.gold"
    static let appearanceText = "appearance.text"
    static let appearanceMuted = "appearance.muted"
    static let appearanceSuccess = "appearance.success"
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