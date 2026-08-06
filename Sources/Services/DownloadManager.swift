import Foundation

/// Téléchargements hors ligne.
///
/// Repose sur une `URLSession` de type *background* : les transferts continuent
/// quand l'app passe en arrière-plan ou est fermée par le système, et reprennent
/// au relancement. Le nombre de connexions simultanées est délibérément bas —
/// les serveurs de récitation sont financés par des dons, on ne les martèle pas.
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    /// État par piste, clé identique à `Track.id` (« <version>#<sss> »).
    @Published private(set) var states: [String: DownloadState] = [:]
    /// Sourates présentes sur le disque, indexées par dossier de version.
    @Published private(set) var inventory: [String: Set<Int>] = [:]
    @Published private(set) var totalBytes: Int64 = 0

    /// Nombre de transferts en cours ou en attente.
    var activeCount: Int { states.values.filter(\.isActive).count }

    /// Renseigné par le délégué d'app quand iOS réveille le processus.
    var backgroundCompletion: (() -> Void)?

    @Published var wifiOnly: Bool = UserDefaults.standard.bool(forKey: "tilawa.wifiOnly") {
        didSet { UserDefaults.standard.set(wifiOnly, forKey: "tilawa.wifiOnly") }
    }

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.background(withIdentifier: "app.tilawa.downloads")
        cfg.sessionSendsLaunchEvents = true
        cfg.isDiscretionary = false
        cfg.httpMaximumConnectionsPerHost = 2
        cfg.timeoutIntervalForResource = 60 * 60
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    private override init() { super.init() }

    // MARK: - Cycle de vie

    /// À appeler une fois au lancement : reconstruit l'inventaire et réadopte
    /// les transferts survivants d'une session précédente.
    func bootstrap() {
        Storage.excludeAudioFromBackup()
        rebuildInventory()
        session.getAllTasks { [weak self] tasks in
            guard let self else { return }
            let revived: [String: DownloadState] = tasks.reduce(into: [:]) { acc, task in
                guard let key = task.taskDescription else { return }
                acc[key] = .downloading(progress: task.progress.fractionCompleted)
            }
            guard !revived.isEmpty else { return }
            DispatchQueue.main.async { self.states.merge(revived) { _, new in new } }
        }
    }

    func rebuildInventory() {
        let inv = Storage.inventory()
        let size = Storage.totalAudioBytes()
        DispatchQueue.main.async {
            self.inventory = inv
            self.totalBytes = size
            // Purge les états « terminé » dont le fichier a disparu.
            for (key, state) in self.states where state == .done {
                if let p = Self.parse(key), !Storage.exists(recitationId: p.recitationId, surah: p.surah) {
                    self.states[key] = DownloadState.idle
                }
            }
        }
    }

    // MARK: - Lecture d'état

    func isDownloaded(recitationId: String, surah: Int) -> Bool {
        inventory[Storage.slug(recitationId)]?.contains(surah) ?? false
    }

    func state(for track: Track) -> DownloadState {
        if isDownloaded(recitationId: track.recitation.id, surah: track.surah.number) { return .done }
        return states[track.id] ?? .idle
    }

    func downloadedCount(recitationId: String) -> Int {
        inventory[Storage.slug(recitationId)]?.count ?? 0
    }

    /// Fichier local si présent, sinon l'URL distante — c'est ce qui rend
    /// l'écoute hors ligne transparente pour le lecteur.
    func playbackURL(for track: Track) -> URL? {
        if isDownloaded(recitationId: track.recitation.id, surah: track.surah.number) {
            return Storage.file(recitationId: track.recitation.id, surah: track.surah.number)
        }
        return track.remoteURL
    }

    // MARK: - Mise en file

    func enqueue(_ track: Track) {
        let key = track.id
        if isDownloaded(recitationId: track.recitation.id, surah: track.surah.number) {
            setState(key, .done); return
        }
        if states[key]?.isActive == true { return }
        guard let url = track.remoteURL else {
            setState(key, .failed("Adresse invalide")); return
        }

        var req = URLRequest(url: url)
        req.allowsCellularAccess = !wifiOnly
        req.timeoutInterval = 60

        let task = session.downloadTask(with: req)
        task.taskDescription = key
        task.priority = URLSessionTask.defaultPriority
        setState(key, .waiting)
        task.resume()
    }

    /// Télécharge une version entière. Les sourates déjà présentes sont ignorées.
    func enqueueAll(reciter: Reciter, recitation: Recitation, surahs: [Surah]) {
        let available = recitation.availableSet
        for surah in surahs where available.contains(surah.number) {
            let track = Track(reciterId: reciter.id, reciterName: reciter.name,
                              reciterNameAr: reciter.nameAr,
                              recitation: recitation, surah: surah)
            enqueue(track)
        }
    }

    func cancel(_ track: Track) {
        let key = track.id
        session.getAllTasks { tasks in
            for t in tasks where t.taskDescription == key { t.cancel() }
        }
        setState(key, DownloadState.idle)
    }

    func cancelAll() {
        session.getAllTasks { tasks in
            for t in tasks { t.cancel() }
        }
        DispatchQueue.main.async {
            for (key, state) in self.states where state.isActive {
                self.states[key] = DownloadState.idle
            }
        }
    }

    // MARK: - Suppression

    func remove(recitationId: String, surah: Int) {
        Storage.delete(recitationId: recitationId, surah: surah)
        setState("\(recitationId)#\(String(format: "%03d", surah))", DownloadState.idle)
        rebuildInventory()
    }

    func removeAll(recitationId: String) {
        Storage.deleteAll(recitationId: recitationId)
        DispatchQueue.main.async {
            for key in self.states.keys where key.hasPrefix(recitationId + "#") {
                self.states[key] = DownloadState.idle
            }
        }
        rebuildInventory()
    }

    func removeEverything() {
        cancelAll()
        Storage.deleteEverything()
        DispatchQueue.main.async { self.states = [:] }
        rebuildInventory()
    }

    // MARK: - Interne

    private func setState(_ key: String, _ state: DownloadState) {
        DispatchQueue.main.async { self.states[key] = state }
    }

    private struct Parsed { let recitationId: String; let surah: Int }

    private static func parse(_ key: String) -> Parsed? {
        guard let hash = key.lastIndex(of: "#") else { return nil }
        let id = String(key[key.startIndex..<hash])
        let num = Int(key[key.index(after: hash)...])
        guard let num, (1...114).contains(num), !id.isEmpty else { return nil }
        return Parsed(recitationId: id, surah: num)
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let key = downloadTask.taskDescription else { return }
        let fraction = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        setState(key, .downloading(progress: min(max(fraction, 0), 1)))
    }

    /// Le fichier temporaire n'existe que le temps de cet appel : il faut le
    /// déplacer ici, de façon synchrone.
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let key = downloadTask.taskDescription, let p = Self.parse(key) else { return }

        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            setState(key, .failed(status == 404 ? "Fichier absent du serveur" : "Erreur HTTP \(status)"))
            return
        }

        Storage.ensureFolder(for: p.recitationId)
        let destination = Storage.file(recitationId: p.recitationId, surah: p.surah)
        try? FileManager.default.removeItem(at: destination)

        do {
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            setState(key, .failed("Écriture impossible"))
            return
        }

        let added = Storage.size(of: destination)
        DispatchQueue.main.async {
            self.states[key] = .done
            self.inventory[Storage.slug(p.recitationId), default: []].insert(p.surah)
            self.totalBytes += added
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let key = task.taskDescription else { return }
        guard let error else { return }   // succès : déjà traité ci-dessus

        let ns = error as NSError
        if ns.code == NSURLErrorCancelled {
            setState(key, DownloadState.idle)
            return
        }
        let message: String
        switch ns.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            message = "Hors connexion"
        case NSURLErrorTimedOut:
            message = "Délai dépassé"
        default:
            message = "Échec du téléchargement"
        }
        setState(key, .failed(message))
    }

    /// iOS a réveillé l'app pour signaler la fin des transferts d'arrière-plan.
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.rebuildInventory()
            self.backgroundCompletion?()
            self.backgroundCompletion = nil
        }
    }
}
