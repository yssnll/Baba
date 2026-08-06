import SwiftUI

/// Ce qui est disponible sans réseau, regroupé par version de récitation.
struct LibraryView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var player: PlayerService

    @State private var confirmWipe = false

    /// Reconstitue, à partir des dossiers présents sur le disque, le couple
    /// (récitateur, version) correspondant. Le dossier porte le slug de l'identifiant.
    private struct OfflineGroup: Identifiable {
        let reciter: Reciter
        let version: Recitation
        let surahs: [Surah]
        var id: String { version.id }
    }

    private var groups: [OfflineGroup] {
        var out: [OfflineGroup] = []
        for reciter in catalog.allReciters {
            for version in reciter.versions {
                guard let numbers = downloads.inventory[Storage.slug(version.id)], !numbers.isEmpty
                else { continue }
                let surahs = catalog.surahs.filter { numbers.contains($0.number) }
                out.append(OfflineGroup(reciter: reciter, version: version, surahs: surahs))
            }
        }
        return out.sorted { $0.reciter.name.lowercased() < $1.reciter.name.lowercased() }
    }

    private var activeTracks: [(key: String, state: DownloadState)] {
        downloads.states
            .filter { $0.value.isActive }
            .map { (key: $0.key, state: $0.value) }
            .sorted { $0.key < $1.key }
    }

    private var totalFiles: Int {
        downloads.inventory.values.reduce(0) { $0 + $1.count }
    }

    private var totalAvailableSurahs: Int {
        catalog.surahs.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                header

                if !activeTracks.isEmpty { activeSection }

                if groups.isEmpty && activeTracks.isEmpty {
                    EmptyStateView(
                        icon: "arrow.down.circle",
                        title: "Rien hors ligne",
                        message: "Choisis une sourate, touche « Télécharger », puis retrouve-la ici pour l'écouter sans réseau."
                    )
                } else {
                    ForEach(groups) { group in
                        LibraryGroupCard(reciter: group.reciter,
                                         version: group.version,
                                         surahs: group.surahs)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .refreshable { downloads.rebuildInventory() }
        .confirmationDialog("Supprimer tout l'audio téléchargé ?",
                            isPresented: $confirmWipe, titleVisibility: .visible) {
            Button("Tout supprimer (\(Fmt.bytes(downloads.totalBytes)))", role: .destructive) {
                downloads.removeEverything()
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hors ligne")
                        .font(Theme.display(26, .bold))
                        .foregroundStyle(Theme.goldSheen)
                    Text("\(totalFiles) sourate\(totalFiles > 1 ? "s" : "") · \(Fmt.bytes(downloads.totalBytes))")
                        .font(Theme.ui(11.5, .regular))
                        .foregroundStyle(Theme.faint)
                }
                Spacer()
                if downloads.totalBytes > 0 {
                    Button {
                        confirmWipe = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.danger)
                            .frame(width: 38, height: 38)
                            .glass(radius: 12, elevation: 0.5)
                    }
                    .buttonStyle(PressScale())
                }
            }
            .padding(.top, 8)

            if totalFiles > 0 {
                HStack(spacing: 8) {
                    ProgressView(value: Double(totalFiles),
                                 total: Double(max(totalAvailableSurahs, 1)))
                        .tint(Theme.emerald)
                    Text("\(totalFiles)/\(totalAvailableSurahs) sourates disponibles")
                        .font(Theme.ui(10.5, .medium))
                        .foregroundStyle(Theme.faint)
                    Spacer(minLength: 0)
                }
            }

            OrnamentDivider()
        }
    }

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionHeader(title: "En cours",
                              subtitle: "Continue même app fermée")
                Spacer()
                Button("Tout arrêter") { downloads.cancelAll() }
                    .font(Theme.ui(11.5, .semibold))
                    .foregroundStyle(Theme.danger)
                    .buttonStyle(.plain)
            }

            ForEach(activeTracks, id: \.key) { entry in
                HStack(spacing: 10) {
                    ProgressRing(fraction: entry.state.fraction, side: 22)
                    Text(label(for: entry.key))
                        .font(Theme.ui(12.5, .medium))
                        .foregroundStyle(Theme.ivory)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.state.isActive && entry.state.fraction > 0
                         ? "\(Int(entry.state.fraction * 100)) %" : "…")
                        .font(Theme.mono(11, .medium))
                        .foregroundStyle(Theme.faint)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .glass(radius: 15, elevation: 0.5)
            }
        }
        .padding(.bottom, 4)
    }

    /// « mq-12-1#036 » → « 36. Ya-Sin — Nom du récitateur »
    private func label(for key: String) -> String {
        guard let hash = key.lastIndex(of: "#"),
              let number = Int(key[key.index(after: hash)...])
        else { return key }
        let versionId = String(key[key.startIndex..<hash])
        let name = catalog.surah(number)?.nameFr ?? "Sourate \(number)"

        for reciter in catalog.allReciters where reciter.versions.contains(where: { $0.id == versionId }) {
            return "\(number). \(name) — \(reciter.name)"
        }
        return "\(number). \(name)"
    }
}

// MARK: - Carte de groupe

struct LibraryGroupCard: View {
    let reciter: Reciter
    let version: Recitation
    let surahs: [Surah]

    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var player: PlayerService
    @State private var expanded = false
    @State private var confirmDelete = false

    private var bytes: Int64 {
        surahs.reduce(Int64(0)) {
            $0 + Storage.size(of: Storage.file(recitationId: version.id, surah: $1.number))
        }
    }

    private var queue: [Track] {
        surahs.map {
            Track(reciterId: reciter.id, reciterName: reciter.name,
                  reciterNameAr: reciter.nameAr, recitation: version, surah: $0)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Monogram(reciter: reciter, side: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(reciter.name)
                        .font(Theme.ui(14.5, .semibold))
                        .foregroundStyle(Theme.ivory)
                        .lineLimit(1)
                    Text("\(version.shortLabel) · \(surahs.count) sourates · \(Fmt.bytes(bytes))")
                        .font(Theme.ui(10.5, .regular))
                        .foregroundStyle(Theme.faint)
                        .lineLimit(1)
                }

                Spacer(minLength: 2)

                Button {
                    guard let first = queue.first else { return }
                    player.play(first, in: queue)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ivory)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.accent))
                }
                .buttonStyle(PressScale())
                .accessibilityLabel("Écouter \(reciter.name)")

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { expanded.toggle() }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.faint)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .frame(width: 26, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)

            if expanded {
                VStack(spacing: 0) {
                    OrnamentDivider().padding(.horizontal, 12)

                    ForEach(surahs) { surah in
                        let track = Track(reciterId: reciter.id, reciterName: reciter.name,
                                          reciterNameAr: reciter.nameAr,
                                          recitation: version, surah: surah)
                        HStack(spacing: 10) {
                            Button {
                                player.toggle(track, in: queue)
                            } label: {
                                HStack(spacing: 10) {
                                    SurahMedallion(number: surah.number,
                                                   active: player.current?.id == track.id, side: 30)
                                    Text(surah.nameFr)
                                        .font(Theme.ui(13, .medium))
                                        .foregroundStyle(player.current?.id == track.id
                                                         ? Theme.emerald : Theme.ivory)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(surah.nameAr)
                                        .font(Theme.arabic(14))
                                        .foregroundStyle(Theme.gold.opacity(0.75))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                downloads.remove(recitationId: version.id, surah: surah.number)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.faint)
                                    .frame(width: 26, height: 26)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }

                    Button {
                        confirmDelete = true
                    } label: {
                        Text("Supprimer cette version")
                            .font(Theme.ui(12, .semibold))
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glass(radius: Theme.radiusCard, elevation: 0.7)
        .confirmationDialog("Supprimer les \(surahs.count) sourates de cette version ?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                downloads.removeAll(recitationId: version.id)
            }
            Button("Annuler", role: .cancel) {}
        }
    }
}
