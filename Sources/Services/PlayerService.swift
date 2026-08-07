import AVFoundation
import Combine
import MediaPlayer
import SwiftUI

enum RepeatMode: Int, CaseIterable {
    case off, all, one

    var icon: String {
        switch self {
        case .off, .all: return "repeat"
        case .one:       return "repeat.1"
        }
    }
    var label: String {
        switch self {
        case .off: return "Aucune répétition"
        case .all: return "Répéter la sélection"
        case .one: return "Répéter la sourate"
        }
    }
    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

/// Lecture audio : file d'attente, transport, session audio, écran verrouillé.
///
/// Joue le fichier local quand la sourate est téléchargée, sinon diffuse depuis
/// le serveur — la bascule est invisible pour l'interface.
final class PlayerService: NSObject, ObservableObject {
    static let shared = PlayerService()

    struct ResumeInfo: Identifiable {
        let track: Track
        let position: Double
        var id: String { track.id }
    }

    @Published private(set) var current: Track?
    @Published private(set) var queue: [Track] = []
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var duration: Double = 0
    @Published var position: Double = 0
    @Published var repeatMode: RepeatMode = .off
    @Published private(set) var errorMessage: String?
    @Published var isPresentingFullPlayer = false
    @Published private(set) var pendingResume: ResumeInfo?

    /// Vrai pendant que l'utilisateur fait glisser la tête de lecture :
    /// on gèle alors les mises à jour de position pour éviter le tremblement.
    var isScrubbing = false

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var itemObservation: NSKeyValueObservation?
    private var artworkCache: [String: MPMediaItemArtwork] = [:]
    private let resumeKey = "tilawa.playback.resume"
    private var lastPersistedPosition = -1.0

    var hasQueue: Bool { !queue.isEmpty }
    var currentIndex: Int? { current.flatMap { c in queue.firstIndex(where: { $0.id == c.id }) } }
    var isPlayingLocal: Bool {
        guard let c = current else { return false }
        return DownloadManager.shared.isDownloaded(recitationId: c.recitation.id, surah: c.surah.number)
    }

    private override init() {
        super.init()
        configureSession()
        configureRemoteCommands()
        observeInterruptions()
        loadResume()
    }

    // MARK: - Session audio

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // `.playback` : le son continue écran verrouillé et ignore le mode silencieux,
            // comportement attendu pour de la récitation.
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            errorMessage = "Session audio indisponible."
        }
    }

    private func observeInterruptions() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleInterruption(_:)),
                           name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(handleRouteChange(_:)),
                           name: AVAudioSession.routeChangeNotification, object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            pause()
        case .ended:
            let opts = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt).map {
                AVAudioSession.InterruptionOptions(rawValue: $0)
            }
            if opts?.contains(.shouldResume) == true { play() }
        @unknown default:
            break
        }
    }

    /// Casque débranché → on met en pause, comme toute app audio bien élevée.
    @objc private func handleRouteChange(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable
        else { return }
        DispatchQueue.main.async { self.pause() }
    }

    // MARK: - Transport

    func play(_ track: Track, in newQueue: [Track]) {
        queue = newQueue.isEmpty ? [track] : newQueue
        pendingResume = nil
        start(track)
    }

    func toggle(_ track: Track, in newQueue: [Track]) {
        if current?.id == track.id {
            isPlaying ? pause() : play()
        } else {
            play(track, in: newQueue)
        }
    }

    private func start(_ track: Track, at initialPosition: Double = 0) {
        guard let url = DownloadManager.shared.playbackURL(for: track) else {
            errorMessage = "Adresse de lecture introuvable."
            return
        }

        teardownObservers()
        errorMessage = nil
        current = track
        position = max(0, initialPosition)
        duration = 0
        isBuffering = true
        persistResume(track: track, position: position)

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        player = newPlayer
        if initialPosition > 0 {
            newPlayer.seek(to: CMTime(seconds: initialPosition, preferredTimescale: 600))
        }

        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isBuffering = false
                    if item.duration.isNumeric { self.duration = item.duration.seconds }
                    self.refreshNowPlaying()
                case .failed:
                    self.isBuffering = false
                    self.isPlaying = false
                    self.errorMessage = DownloadManager.shared.isDownloaded(
                        recitationId: track.recitation.id, surah: track.surah.number)
                        ? "Fichier local illisible. Supprime-le et retélécharge-le."
                        : "Lecture impossible hors connexion. Télécharge cette sourate."
                default:
                    break
                }
            }
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(itemDidFinish(_:)),
            name: .AVPlayerItemDidPlayToEndTime, object: item)

        installTimeObserver()
        newPlayer.play()
        isPlaying = true
        refreshNowPlaying()
    }

    func play() {
        guard let player else {
            if let c = current { start(c) }
            return
        }
        player.play()
        isPlaying = true
        refreshNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        persistCurrentPosition()
        refreshNowPlaying()
    }

    func togglePlayPause() { isPlaying ? pause() : play() }

    /// Relance la piste courante après une erreur réseau ou un fichier local
    /// devenu illisible. L'écran de lecture peut ainsi proposer une action
    /// concrète au lieu de laisser l'utilisateur bloqué sur un message.
    func retry() {
        guard let current else { return }
        start(current)
    }

    func stop() {
        teardownObservers()
        player?.pause()
        player = nil
        current = nil
        queue = []
        isPlaying = false
        position = 0
        duration = 0
        clearResume()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func resumeSavedTrack() {
        guard let pending = pendingResume else { return }
        pendingResume = nil
        start(pending.track, at: pending.position)
        queue = [pending.track]
    }

    func dismissSavedResume() {
        pendingResume = nil
        clearResume()
    }

    func persistCurrentPosition() {
        guard let current else { return }
        persistResume(track: current, position: position)
    }

    func next() {
        guard let i = currentIndex else { return }
        let target = i + 1
        if target < queue.count {
            start(queue[target])
        } else if repeatMode == .all, let first = queue.first {
            start(first)
        } else {
            clearResume()
            pause()
        }
    }

    func previous() {
        // Sous trois secondes on revient à la piste précédente, sinon on rembobine.
        if position > 3 {
            seek(to: 0); return
        }
        guard let i = currentIndex else { return }
        if i - 1 >= 0 {
            start(queue[i - 1])
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: Double) {
        guard let player, duration > 0 else { return }
        let clamped = min(max(seconds, 0), duration)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                self?.position = clamped
                self?.refreshNowPlaying()
            }
        }
    }

    func skip(by delta: Double) { seek(to: position + delta) }

    func cycleRepeat() { repeatMode = repeatMode.next }

    @objc private func itemDidFinish(_ note: Notification) {
        DispatchQueue.main.async {
            guard let c = self.current else { return }
            if self.repeatMode == .one {
                self.seek(to: 0)
                self.play()
            } else if self.currentIndex == nil {
                _ = c
                self.pause()
            } else {
                self.next()
            }
        }
    }

    // MARK: - Observation du temps

    private func installTimeObserver() {
        guard let player else { return }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main
        ) { [weak self] time in
            guard let self else { return }
            if !self.isScrubbing { self.position = time.seconds }
            if !self.isScrubbing,
               self.position - self.lastPersistedPosition >= 5 {
                self.persistCurrentPosition()
            }
            if let d = self.player?.currentItem?.duration, d.isNumeric, d.seconds > 0 {
                self.duration = d.seconds
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo?[
                MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.position
        }
    }

    private func teardownObservers() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        itemObservation?.invalidate()
        itemObservation = nil
        NotificationCenter.default.removeObserver(
            self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    private func loadResume() {
        guard let data = UserDefaults.standard.data(forKey: resumeKey),
              let saved = try? JSONDecoder().decode(ResumeSnapshot.self, from: data),
              saved.position > 2 else { return }
        pendingResume = ResumeInfo(track: saved.track, position: saved.position)
    }

    private func persistResume(track: Track, position: Double) {
        guard position >= 0,
              let data = try? JSONEncoder().encode(ResumeSnapshot(track: track, position: position))
        else { return }
        UserDefaults.standard.set(data, forKey: resumeKey)
        lastPersistedPosition = position
    }

    private func clearResume() {
        pendingResume = nil
        lastPersistedPosition = -1
        UserDefaults.standard.removeObject(forKey: resumeKey)
    }

    private struct ResumeSnapshot: Codable {
        let track: Track
        let position: Double
    }

    // MARK: - Écran verrouillé

    private func configureRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()

        c.playCommand.addTarget { [weak self] _ in
            self?.play(); return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            self?.pause(); return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause(); return .success
        }
        c.nextTrackCommand.addTarget { [weak self] _ in
            self?.next(); return .success
        }
        c.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous(); return .success
        }
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: e.positionTime)
            return .success
        }
        c.skipForwardCommand.preferredIntervals = [15]
        c.skipBackwardCommand.preferredIntervals = [15]
        c.skipForwardCommand.addTarget { [weak self] _ in
            self?.skip(by: 15); return .success
        }
        c.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skip(by: -15); return .success
        }
    }

    private func refreshNowPlaying() {
        guard let t = current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "\(t.surah.number). \(t.surah.nameTranslit)",
            MPMediaItemPropertyArtist: t.reciterName,
            MPMediaItemPropertyAlbumTitle: t.recitation.shortLabel,
            MPMediaItemPropertyAlbumTrackNumber: t.surah.number,
            MPMediaItemPropertyAlbumTrackCount: 114,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyIsLiveStream: false,
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if let art = artwork(for: t) { info[MPMediaItemPropertyArtwork] = art }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Vignette dessinée à la volée pour l'écran verrouillé : dégradé, rosette, numéro.
    ///
    /// `ImageRenderer` est contraint au thread principal. Tous les appelants de
    /// `refreshNowPlaying()` sont déjà sur la boucle principale, d'où
    /// `assumeIsolated` : l'isolation est vérifiée à l'exécution et le code
    /// compile sans dépendre du mode de concurrence retenu.
    private func artwork(for track: Track) -> MPMediaItemArtwork? {
        let key = track.surah.padded
        if let cached = artworkCache[key] { return cached }
        guard Thread.isMainThread else { return nil }

        let art = MainActor.assumeIsolated { () -> MPMediaItemArtwork? in
            let side: CGFloat = 600
            let renderer = ImageRenderer(
                content: LockScreenArtwork(surah: track.surah).frame(width: side, height: side)
            )
            renderer.scale = 1
            guard let image = renderer.uiImage else { return nil }
            return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        if let art { artworkCache[key] = art }
        return art
    }
}

/// Vignette de l'écran verrouillé. Vue autonome pour pouvoir passer par `ImageRenderer`.
private struct LockScreenArtwork: View {
    let surah: Surah

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.deep, Theme.night], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Theme.emerald.opacity(0.45), .clear],
                           center: .center, startRadius: 20, endRadius: 320)
            IslamicPattern(tile: 110, lineWidth: 1.4, color: Theme.gold, opacity: 0.16)

            VStack(spacing: 26) {
                ZStack {
                    Octagon()
                        .stroke(Theme.goldSheen, lineWidth: 2.5)
                        .frame(width: 150, height: 150)
                    Text("\(surah.number)")
                        .font(Theme.display(62, .bold))
                        .foregroundStyle(Theme.goldSheen)
                }
                VStack(spacing: 10) {
                    Text(surah.nameAr)
                        .font(Theme.arabic(66, .semibold))
                        .foregroundStyle(Theme.ivory)
                    Text(surah.nameTranslit)
                        .font(Theme.display(32, .medium))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
        .frame(width: 600, height: 600)
    }
}
