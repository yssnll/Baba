import SwiftUI

struct RootView: View {
    @EnvironmentObject private var player: PlayerService
    @ObservedObject private var appearance = AppearanceSettings.shared
    @State private var tab: MainTab = .reciters

    var body: some View {
        let appearanceKey = "\(appearance.preset.rawValue)-\(appearance.backgroundHex)-\(appearance.accentHex)-\(appearance.goldHex)"

        ZStack {
            LiquidBackdrop()

            Group {
                switch tab {
                case .reciters: RecitersView()
                case .library:  LibraryView()
                case .settings: SettingsView()
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
            .animation(.easeInOut(duration: 0.22), value: tab)
        }
        .id(appearanceKey)
        // En inset de safe area : les listes gagnent automatiquement la marge
        // nécessaire et rien ne se retrouve caché sous le mini-lecteur.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 9) {
                if player.current != nil {
                    MiniPlayerView()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                TabBar(selection: $tab)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
            .animation(.spring(response: 0.38, dampingFraction: 0.82), value: player.current?.id)
        }
        // `fullScreenCover` et non `sheet` : une sheet laisse une marge en haut
        // et des coins arrondis, à travers lesquels la liste et la barre
        // d'onglets restaient visibles.
        .fullScreenCover(isPresented: $player.isPresentingFullPlayer) {
            NowPlayingView()
        }
    }
}

enum MainTab: Int, CaseIterable, Identifiable {
    case reciters, library, settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .reciters: return "Récitateurs"
        case .library:  return "Hors ligne"
        case .settings: return "Réglages"
        }
    }
    var icon: String {
        switch self {
        case .reciters: return "person.wave.2"
        case .library:  return "arrow.down.circle"
        case .settings: return "slider.horizontal.3"
        }
    }
}

// MARK: - Barre d'onglets

struct TabBar: View {
    @Binding var selection: MainTab
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    guard selection != tab else { return }
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.title)
                            .font(Theme.ui(9.5, .semibold))
                    }
                    .foregroundStyle(selection == tab ? Theme.ivory : Theme.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Theme.gold.opacity(0.30), lineWidth: 0.8)
                                )
                                .matchedGeometryEffect(id: "tab", in: indicator)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .glass(radius: 20, elevation: 0.9)
    }
}

// MARK: - Mini-lecteur

struct MiniPlayerView: View {
    @EnvironmentObject private var player: PlayerService

    var body: some View {
        if let track = player.current {
            HStack(spacing: 11) {
                SurahMedallion(number: track.surah.number, active: player.isPlaying, side: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.surah.nameFr)
                        .font(Theme.ui(13.5, .semibold))
                        .foregroundStyle(Theme.ivory)
                        .lineLimit(1)
                    Text(player.isBuffering ? "Chargement de la récitation…" : track.reciterName)
                        .font(Theme.ui(11, .regular))
                        .foregroundStyle(Theme.faint)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if player.isBuffering {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(Theme.emerald)
                        .frame(width: 30)
                } else {
                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.ivory)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScale())
                }

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 28, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScale())
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(alignment: .bottom) {
                // Liseré de progression collé au bas de la pilule.
                GeometryReader { geo in
                    let ratio = player.duration > 0 ? player.position / player.duration : 0
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * max(0, min(ratio, 1)), height: 2)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .glass(radius: 18, elevation: 0.9)
            .contentShape(Rectangle())
            .onTapGesture {
                player.isPresentingFullPlayer = true
            }
        }
    }
}
