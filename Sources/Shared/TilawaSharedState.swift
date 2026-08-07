import Foundation

/// État minimal partagé entre l'app et l'extension WidgetKit.
/// Le catalogue et les fichiers audio ne quittent jamais le conteneur de l'app.
enum TilawaSharedState {
    static let appGroup = "group.app.tilawa"
    static let widgetTitle = "widget.title"
    static let widgetSubtitle = "widget.subtitle"
    static let widgetReciterID = "widget.reciter-id"
    static let widgetSurahNumber = "widget.surah-number"
    static let widgetIsPlaying = "widget.is-playing"
    static let widgetPosition = "widget.position"
    static let widgetDuration = "widget.duration"
}