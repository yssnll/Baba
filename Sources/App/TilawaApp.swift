import SwiftUI
import UIKit

@main
struct TilawaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var catalog = CatalogStore.shared
    @StateObject private var downloads = DownloadManager.shared
    @StateObject private var player = PlayerService.shared
    @StateObject private var appearance = AppearanceSettings.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(catalog)
                .environmentObject(downloads)
                .environmentObject(player)
                .environmentObject(appearance)
                .preferredColorScheme(appearance.isLight ? .light : .dark)
                .tint(appearance.accent)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        DownloadManager.shared.bootstrap()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        PlayerService.shared.persistCurrentPosition()
    }

    /// iOS relance le processus pour signaler la fin de transferts d'arrière-plan.
    /// Le gestionnaire conserve le handler et l'appelle une fois l'inventaire à jour.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        DownloadManager.shared.backgroundCompletion = completionHandler
    }
}
