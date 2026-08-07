import SwiftUI

/// Lecteur plein écran.
///
/// Présenté en `fullScreenCover` : couvre réellement tout l'écran, encoche et
/// indicateur d'accueil compris. Toutes les dimensions sont dérivées de la
/// hauteur disponible, pour tenir de l'iPhone SE au Pro Max sans débordement.
struct NowPlayingView: View {
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var downloads: DownloadManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var halo = false
    @GestureState private var interactiveDragOffset: CGFloat = 0

    private var track: Track? { player.current }

    var body: some View {
        ZStack {
            // Le fond est posé au niveau de la couverture entière. Cela évite
            // les bandes noires dans les zones d'encoche et autour du contenu.
            PlayerBackdrop()
                .ignoresSafeArea()

            if let track {
                GeometryReader { geo in
                    let safe = geo.safeAreaInsets
                    let contentWidth = max(0, geo.size.width - safe.leading - safe.trailing)
                    let contentHeight = max(0, geo.size.height - safe.top - safe.bottom)

                    content(
                        track,
                        in: CGSize(width: contentWidth, height: contentHeight),
                        safeTop: safe.top
                    )
                        .frame(width: contentWidth, height: contentHeight, alignment: .top)
                        .padding(.top, safe.top)
                        .padding(.bottom, safe.bottom)
                        .padding(.leading, safe.leading)
                        .padding(.trailing, safe.trailing)
                }
                .ignoresSafeArea()
                // Un seul geste pour toute la surface du lecteur. La partie
                // interactive est portée par @GestureState : elle revient
                // naturellement à zéro entre deux mouvements et évite les
                // oscillations provoquées par plusieurs gestes imbriqués.
                .simultaneousGesture(dismissDrag)
                .offset(y: interactiveDragOffset)
            } else {
                VStack {
                    closeBar()
                    Spacer()
                    EmptyStateView(icon: "music.note", title: "Rien en lecture",
                                   message: "Choisis un récitateur puis une sourate.")
                    Spacer()
                }
            }
        }
        .statusBarHidden(false)
        .presentationBackground(.clear)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                halo = true
            }
        }
    }

    // MARK: - Mise en page

    /// Répartit l'espace selon la hauteur utile. `tight` déclenche la variante
    /// compacte (petits écrans) : ornement réduit, marges resserrées.
    @ViewBuilder
    private func content(_ track: Track, in size: CGSize, safeTop: CGFloat) -> some View {
        let h = size.height
        let tight = h < 620
        let compact = h < 700
        let closeBarTop = adaptiveCloseBarTop(for: h, safeTop: safeTop)
        // La scène centrale garde une taille généreuse, mais ne peut plus
        // consommer l'espace réservé aux contrôles sur un petit iPhone.
        let art = min(
            max(104, size.width * 0.60),
            compact ? max(h * 0.18, 112) : h * 0.23
        )
        let gap: CGFloat = tight ? 5 : compact ? 9 : 14

        VStack(spacing: 0) {
            closeBar(topPadding: closeBarTop)

            Spacer(minLength: tight ? 0 : compact ? 2 : 6)

            artworkStage(for: track, side: art)

            Spacer(minLength: gap)

            titles(for: track, tight: tight)
                .padding(.horizontal, 26)

            Spacer(minLength: gap)

            VStack(spacing: tight ? 8 : compact ? 11 : 15) {
                scrubber(tight: tight)
                transport(tight: tight)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, tight ? 8 : compact ? 11 : 14)
            .background(Theme.night.opacity(0.56))
            .glass(radius: 26, elevation: 0.8)
            .padding(.horizontal, 14)

            Spacer(minLength: tight ? 5 : compact ? 9 : 16)

            secondaryBar(for: track)
                .padding(.horizontal, 14)

            if let message = player.errorMessage {
                errorBanner(message)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
            }

            Spacer(minLength: tight ? 2 : compact ? 4 : 9)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Barre supérieure : fermeture explicite à gauche, poignée au centre.
    private func closeBar(topPadding: CGFloat = 32) -> some View {
        ZStack {
            Capsule()
                .fill(Theme.ivory.opacity(0.26))
                .frame(width: 38, height: 4.5)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ivory.opacity(0.9))
                        .frame(width: 36, height: 36)
                        .background(Theme.night.opacity(0.64))
                        .glass(radius: 12, material: .regularMaterial, elevation: 0.5)
                }
                .buttonStyle(PressScale())

                Spacer()

                Text("En lecture")
                    .font(Theme.ui(11, .semibold))
                    .foregroundStyle(Theme.faint)
                    .opacity(0)   // réserve la symétrie sans surcharger le titre
            }
        }
        .padding(.horizontal, 16)
        // Laisser une vraie marge sous l'heure système : sur les appareils
        // avec encoche, la flèche ne doit jamais se retrouver sous la barre
        // d'état. Cette marge abaisse aussi légèrement tout le lecteur.
        .padding(.top, topPadding)
        .padding(.bottom, 7)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .zIndex(2)
    }

    /// Adapte la position de la barre aux dimensions réelles de l'appareil.
    /// On utilise la géométrie et la safe area plutôt qu'un modèle d'iPhone
    /// codé en dur : cela couvre aussi les futurs appareils et l'orientation.
    private func adaptiveCloseBarTop(for height: CGFloat, safeTop: CGFloat) -> CGFloat {
        let screenFactor = min(max(height / 760, 0.88), 1.12)
        let notchExtra: CGFloat = safeTop > 20 ? 4 : 0
        return min(48, max(38, 40 * screenFactor + notchExtra))
    }

    /// Surface de présentation qui donne à la rosette une vraie place dans le
    /// lecteur au lieu de la laisser flotter au milieu d'un fond vide.
    private func artworkStage(for track: Track, side: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Theme.emerald.opacity(0.16),
                            Theme.nightSoft.opacity(0.48),
                            Theme.gold.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            IslamicPattern(tile: 66, lineWidth: 0.65,
                           color: Theme.gold, opacity: 0.065)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            ornament(for: track, side: side)
        }
        .frame(maxWidth: .infinity)
        .frame(height: side * 1.36)
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Theme.gold.opacity(0.34), .white.opacity(0.08), Theme.emerald.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Theme.emerald.opacity(0.12), radius: 28, y: 12)
        .padding(.horizontal, 14)
    }

    /// Glisser vers le bas pour fermer. Rattaché au haut de l'écran seulement,
    /// afin de ne pas voler ses gestes à la tête de lecture.
    private var dismissDrag: some Gesture {
        DragGesture()
            .updating($interactiveDragOffset) { value, state, _ in
                let vertical = value.translation.height
                let horizontal = abs(value.translation.width)
                guard vertical > 0, vertical > horizontal else {
                    state = 0
                    return
                }
                state = vertical
            }
            .onEnded { value in
                if value.translation.height > 110 {
                    dismiss()
                }
            }
    }

    // MARK: - Éléments

    /// Rosette centrale : elle respire au rythme de la lecture et se fige à la pause.
    private func ornament(for track: Track, side: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [Theme.emerald.opacity(0.34), .clear],
                                   center: .center, startRadius: side * 0.04, endRadius: side * 0.66)
                )
                .frame(width: side * 1.32, height: side * 1.32)
                .scaleEffect(halo && player.isPlaying ? 1.07 : 0.94)
                .blur(radius: side * 0.055)

            IslamicPattern(tile: side * 0.25, lineWidth: 0.9,
                           color: Theme.gold, opacity: 0.20)
                .frame(width: side, height: side)
                .clipShape(Circle())
                .rotationEffect(.degrees(halo && player.isPlaying ? 12 : -12))

            Circle()
                .stroke(Theme.goldSheen.opacity(0.55), lineWidth: 1)
                .frame(width: side, height: side)

            Octagon()
                .stroke(Theme.gold.opacity(0.45), lineWidth: 1)
                .frame(width: side * 0.78, height: side * 0.78)
                .rotationEffect(.degrees(halo && player.isPlaying ? -8 : 8))

            VStack(spacing: side * 0.035) {
                Text(track.surah.nameAr)
                    .font(Theme.arabic(side * 0.17, .semibold))
                    .foregroundStyle(Theme.ivory)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, side * 0.1)

                Text("\(track.surah.verses) versets · \(track.surah.revelation)")
                    .font(Theme.ui(max(9, side * 0.042), .medium))
                    .foregroundStyle(Theme.gold.opacity(0.8))
                    .lineLimit(1)
            }

            if player.isBuffering {
                ProgressView()
                    .tint(Theme.emerald)
                    .scaleEffect(1.1)
                    .offset(y: side * 0.34)
            }
        }
        .frame(width: side * 1.32, height: side * 1.32)
    }

    private func titles(for track: Track, tight: Bool) -> some View {
        VStack(spacing: tight ? 3 : 6) {
            Text("\(track.surah.number). \(track.surah.nameFr)")
                .font(Theme.display(tight ? 19 : 23, .bold))
                .foregroundStyle(Theme.ivory)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .lineLimit(2)

            Text(track.reciterName)
                .font(Theme.ui(tight ? 12.5 : 14, .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)

            HStack(spacing: 6) {
                Chip(text: track.recitation.shortLabel, icon: "book.closed")
                Chip(text: playbackStatusTitle,
                     icon: playbackStatusIcon,
                     tint: playbackStatusTint)
            }
            .padding(.top, 2)
        }
    }

    private var playbackStatusTitle: String {
        if player.isBuffering { return "Chargement…" }
        return player.isPlayingLocal ? "Disponible hors connexion" : "Lecture en streaming"
    }

    private var playbackStatusIcon: String {
        if player.isBuffering { return "hourglass" }
        return player.isPlayingLocal ? "arrow.down.circle.fill" : "wifi"
    }

    private var playbackStatusTint: Color {
        if player.isBuffering { return Theme.gold }
        return player.isPlayingLocal ? Theme.emerald : Theme.teal
    }

    private func scrubber(tight: Bool) -> some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { min(player.position, max(player.duration, 0.01)) },
                    set: { player.position = $0 }
                ),
                in: 0...max(player.duration, 0.01),
                onEditingChanged: { editing in
                    player.isScrubbing = editing
                    if !editing { player.seek(to: player.position) }
                }
            )
            .tint(Theme.emerald)
            .disabled(player.duration <= 0)

            HStack {
                Text(Fmt.time(player.position))
                Spacer()
                Text(player.duration > 0 ? "-" + Fmt.time(player.duration - player.position) : "--:--")
            }
            .font(Theme.mono(tight ? 10 : 11, .medium))
            .foregroundStyle(Theme.faint)
        }
    }

    private func transport(tight: Bool) -> some View {
        let small: CGFloat = tight ? 40 : 46
        let big: CGFloat = tight ? 64 : 74
        return HStack(spacing: tight ? 11 : 16) {
            CircleGlassButton(icon: "backward.fill", side: small) { player.previous() }
            CircleGlassButton(icon: "gobackward.15", side: small, iconScale: 0.36) { player.skip(by: -15) }

            CircleGlassButton(
                icon: player.isPlaying ? "pause.fill" : "play.fill",
                side: big, iconScale: 0.36, prominent: true,
                disabled: player.isBuffering || player.errorMessage != nil
            ) {
                player.togglePlayPause()
            }

            CircleGlassButton(icon: "goforward.15", side: small, iconScale: 0.36) { player.skip(by: 15) }
            CircleGlassButton(icon: "forward.fill", side: small) { player.next() }
        }
    }

    private func secondaryBar(for track: Track) -> some View {
        HStack(spacing: 0) {
            Button {
                player.cycleRepeat()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: player.repeatMode.icon)
                        .font(.system(size: 16, weight: .semibold))
                    Text(player.repeatMode == .off ? "Répéter" :
                            (player.repeatMode == .one ? "Sourate" : "Série"))
                        .font(Theme.ui(9.5, .medium))
                }
                .foregroundStyle(player.repeatMode == .off ? Theme.faint : Theme.gold)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            let state = downloads.state(for: track)
            Button {
                switch state {
                case .idle, .failed: downloads.enqueue(track)
                case .waiting, .downloading: downloads.cancel(track)
                case .done: downloads.remove(recitationId: track.recitation.id,
                                             surah: track.surah.number)
                }
            } label: {
                VStack(spacing: 3) {
                    DownloadButton(state: state, side: 22) {}
                        .allowsHitTesting(false)
                    Text(state == .done ? "Téléchargé" :
                            (state.isActive ? "\(Int(state.fraction * 100)) %" : "Télécharger"))
                        .font(Theme.ui(9.5, .medium))
                        .foregroundStyle(state == .done ? Theme.emerald : Theme.faint)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                player.stop()
                dismiss()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Arrêter").font(Theme.ui(9.5, .medium))
                }
                .foregroundStyle(Theme.faint)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 6)
        .background(Theme.night.opacity(0.58))
        .glass(radius: 20, material: .regularMaterial, elevation: 0.7)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.danger)

            Text(message)
                .font(Theme.ui(11.5, .medium))
                .foregroundStyle(Theme.ivory.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button {
                player.retry()
            } label: {
                Text("Réessayer")
                    .font(Theme.ui(11, .bold))
                    .foregroundStyle(Theme.ivory)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.danger.opacity(0.32)))
            }
            .buttonStyle(PressScale(scale: 0.96))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.danger.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Theme.danger.opacity(0.32), lineWidth: 0.8)
        )
    }
}

/// Fond propre au lecteur : suffisamment coloré pour supprimer les bords noirs,
/// mais assez doux pour garder le texte et la récitation au premier plan.
private struct PlayerBackdrop: View {
    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                Theme.canvas

                Circle()
                    .fill(Theme.emerald.opacity(0.22))
                    .frame(width: w * 1.12, height: w * 1.12)
                    .blur(radius: w * 0.24)
                    .offset(
                        x: drift ? -w * 0.28 : w * 0.18,
                        y: drift ? -h * 0.16 : h * 0.05
                    )

                Circle()
                    .fill(Theme.indigo.opacity(0.24))
                    .frame(width: w * 0.94, height: w * 0.94)
                    .blur(radius: w * 0.22)
                    .offset(
                        x: drift ? w * 0.28 : -w * 0.20,
                        y: drift ? h * 0.28 : h * 0.56
                    )

                Circle()
                    .fill(Theme.gold.opacity(0.11))
                    .frame(width: w * 0.72, height: w * 0.72)
                    .blur(radius: w * 0.20)
                    .offset(
                        x: drift ? -w * 0.16 : w * 0.22,
                        y: drift ? h * 0.57 : h * 0.30
                    )

                IslamicPattern(tile: 92, opacity: 0.045)

                RadialGradient(
                    colors: [.clear, Theme.night.opacity(0.62)],
                    center: .center,
                    startRadius: w * 0.28,
                    endRadius: max(w, h) * 0.78
                )
                .blendMode(.multiply)
            }
            .frame(width: w, height: h)
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 19).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
        }
        .ignoresSafeArea()
    }
}
